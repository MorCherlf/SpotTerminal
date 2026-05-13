// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

final class PersistentShellSession {
    private struct Markers {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var start: String { "__SPOT_\(token)_COMMAND_START__" }
        var endPrefix: String { "__SPOT_\(token)_COMMAND_END:" }
        var endSuffix: String { "__" }
        var ready: String { "__SPOT_\(token)_READY__" }
        var interactiveReady: String { "__SPOT_\(token)_INTERACTIVE_READY__" }
    }

    private let markers = Markers()
    private var childPID: pid_t = 0
    private var masterFD: Int32 = -1
    private var outputHandle: FileHandle?
    private let lock = NSLock()
    private var buffer = ""
    private var isCapturingCommand = false
    private var isBootstrapping = false
    private var didStart = false
    private var commandGeneration = 0
    private var pendingInterruptGeneration: Int?
    private var isSuppressingTerminalBroadcast = false
    private var interactivePreparationCompletions: [() -> Void] = []
    private var terminalConsumers: [UUID: (ArraySlice<UInt8>) -> Void] = [:]
    private var renderedOutputConsumers: [UUID: (String) -> Void] = [:]
    private var renderedOutputHistory = ""

    var onCommandOutput: ((String) -> Void)?
    var onCommandFinished: ((Int32) -> Void)?
    var onWorkingDirectoryChanged: ((String) -> Void)?

    deinit {
        terminate()
    }

    func startIfNeeded() {
        lock.lock()
        let shouldStart = !didStart
        didStart = true
        lock.unlock()

        guard shouldStart else { return }

        let homePath = Self.homeDirectoryPath()
        let shellPath = Self.defaultShellPath()
        let execName = "-" + NSString(string: shellPath).lastPathComponent

        let pid = homePath.withCString { homePointer in
            shellPath.withCString { shellPointer in
                execName.withCString { execNamePointer in
                    var windowSize = winsize(ws_row: 28, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
                    var argv: [UnsafeMutablePointer<CChar>?] = [
                        UnsafeMutablePointer(mutating: execNamePointer),
                        nil
                    ]

                    return argv.withUnsafeMutableBufferPointer { argvBuffer in
                        let pid = forkpty(&masterFD, nil, nil, &windowSize)

                        if pid == 0 {
                            setpgid(0, 0)
                            setenv("TERM", "xterm-256color", 1)
                            setenv("COLORTERM", "truecolor", 1)
                            chdir(homePointer)
                            execv(shellPointer, argvBuffer.baseAddress)
                            _exit(127)
                        }

                        return pid
                    }
                }
            }
        }

        guard pid > 0 else { return }

        childPID = pid
        isBootstrapping = true
        let handle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        outputHandle = handle
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            self?.broadcast(data)
            self?.process(text: String(decoding: data, as: UTF8.self))
        }

        let startPrint = Self.shellPrintfCommand(marker: markers.start)
        let endPrefixPrint = Self.shellPrintfCommand(marker: markers.endPrefix, terminator: "")
        let readyPrint = Self.shellPrintfCommand(marker: markers.ready)

        sendRaw("""
        unsetopt zle 2>/dev/null
        PROMPT=''
        RPROMPT=''
        stty -echo 2>/dev/null
        export CLICOLOR=0
        export LSCOLORS=""
        unalias ls 2>/dev/null
        unalias grep 2>/dev/null
        __spot_run() {
          printf '\\n'
          \(startPrint)
          eval "$1"
          __spot_terminal_exit_code=$?
          printf '\\n'
          \(endPrefixPrint)
          printf '%d:%s%s\\n' $__spot_terminal_exit_code "$(printf '%s' "$PWD" | /usr/bin/base64)" '\(markers.endSuffix)'
        }
        \(readyPrint)

        """)
    }

    func submit(_ command: String) {
        startIfNeeded()
        let generation = nextCommandGeneration()
        emitRenderedOutput("$ \(command)\r\n")
        sendRaw("__spot_run \(Self.shellQuoted(command))\n")
        markCommandSubmitted(generation)
    }

    func send(data: ArraySlice<UInt8>) {
        startIfNeeded()
        guard masterFD >= 0 else { return }
        data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            Darwin.write(masterFD, baseAddress, data.count)
        }
    }

    func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0 else { return }
        startIfNeeded()
        guard masterFD >= 0 else { return }
        var windowSize = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFD, TIOCSWINSZ, &windowSize)
    }

    func prepareForTerminalAttachment(completion: @escaping () -> Void) {
        startIfNeeded()
        lock.lock()
        isSuppressingTerminalBroadcast = true
        interactivePreparationCompletions.append(completion)
        lock.unlock()

        setEcho(enabled: false)
        let interactiveReadyPrint = Self.shellPrintfCommand(marker: markers.interactiveReady)
        sendRaw("""
        setopt zle 2>/dev/null
        bindkey -e 2>/dev/null
        PROMPT='%n@%m %1~ %# '
        RPROMPT=''
        export CLICOLOR=1
        stty sane echo 2>/dev/null
        printf '\\n'
        \(interactiveReadyPrint)

        """)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.finishInteractivePreparation()
        }
    }

    func showInteractivePrompt() {
        startIfNeeded()
        sendRaw("\n")
    }

    func interrupt() {
        let generation = currentCommandGeneration()
        sendControlC()
        signalForegroundProcessGroup(SIGINT)
        scheduleInterruptRecovery(for: generation)
    }

    func forceKill() {
        if !signalForegroundProcessGroup(SIGKILL), childPID > 0 {
            kill(childPID, SIGKILL)
        }
    }

    func terminate() {
        outputHandle?.readabilityHandler = nil
        outputHandle?.closeFile()
        outputHandle = nil
        if childPID > 0 {
            kill(-childPID, SIGTERM)
        }
        childPID = 0
        masterFD = -1
    }

    func addTerminalConsumer(_ consumer: @escaping (ArraySlice<UInt8>) -> Void) -> UUID {
        startIfNeeded()
        let id = UUID()
        lock.lock()
        terminalConsumers[id] = consumer
        lock.unlock()
        return id
    }

    func removeTerminalConsumer(id: UUID) {
        lock.lock()
        terminalConsumers.removeValue(forKey: id)
        lock.unlock()
    }

    func renderedOutputSnapshot() -> String {
        lock.lock()
        let snapshot = renderedOutputHistory
        lock.unlock()
        return snapshot
    }

    func addRenderedOutputConsumer(_ consumer: @escaping (String) -> Void) -> UUID {
        startIfNeeded()
        let id = UUID()
        lock.lock()
        renderedOutputConsumers[id] = consumer
        lock.unlock()
        return id
    }

    func removeRenderedOutputConsumer(id: UUID) {
        lock.lock()
        renderedOutputConsumers.removeValue(forKey: id)
        lock.unlock()
    }

    private func sendRaw(_ text: String) {
        let bytes = Array(text.utf8)
        send(data: bytes[...])
    }

    private func setEcho(enabled: Bool) {
        guard masterFD >= 0 else {
            return
        }

        var attributes = termios()
        guard tcgetattr(masterFD, &attributes) == 0 else {
            return
        }

        if enabled {
            attributes.c_lflag |= UInt(ECHO)
        } else {
            attributes.c_lflag &= ~UInt(ECHO)
        }
        _ = tcsetattr(masterFD, TCSANOW, &attributes)
    }

    private func broadcast(_ data: Data) {
        let bytes = Array(data)
        lock.lock()
        let isSuppressed = isSuppressingTerminalBroadcast
        let consumers = Array(terminalConsumers.values)
        lock.unlock()

        guard !isSuppressed else { return }
        for consumer in consumers {
            consumer(bytes[...])
        }
    }

    private func process(text: String) {
        buffer += text.normalizedTerminalOutput()

        if isBootstrapping {
            guard let readyRange = buffer.range(of: markers.ready) else {
                buffer = buffer.trailingPrefixFragment(of: markers.ready)
                return
            }
            buffer = String(buffer[readyRange.upperBound...])
            isBootstrapping = false
        }

        if let interactiveReadyRange = buffer.range(of: markers.interactiveReady) {
            buffer = String(buffer[interactiveReadyRange.upperBound...])
            finishInteractivePreparation()
        }

        while true {
            if !isCapturingCommand {
                guard let startRange = buffer.range(of: markers.start) else {
                    buffer = buffer.trailingPrefixFragment(of: markers.start)
                    return
                }
                buffer = String(buffer[startRange.upperBound...])
                isCapturingCommand = true
            }

            guard let endRange = buffer.range(of: markers.endPrefix) else {
                let retained = buffer.trailingPrefixFragment(of: markers.endPrefix)
                let emitEnd = buffer.index(buffer.endIndex, offsetBy: -retained.count)
                let emit = String(buffer[..<emitEnd])
                buffer = retained
                emitOutput(emit)
                return
            }

            let output = String(buffer[..<endRange.lowerBound])
            let codeStart = endRange.upperBound
            guard let suffixRange = buffer[codeStart...].range(of: markers.endSuffix) else {
                return
            }

            let markerPayload = String(buffer[codeStart..<suffixRange.lowerBound])
            let parsedMarker = parseEndMarkerPayload(markerPayload)
            let exitCode = parsedMarker.exitCode
            let remainingStart = suffixRange.upperBound
            buffer = String(buffer[remainingStart...])

            emitOutput(output.trimmingCommandControlWhitespace())
            isCapturingCommand = false
            clearPendingInterrupt(for: commandGeneration)
            if let workingDirectory = parsedMarker.workingDirectory {
                onWorkingDirectoryChanged?(workingDirectory)
            }
            onCommandFinished?(exitCode)
        }
    }

    private func parseEndMarkerPayload(_ payload: String) -> (exitCode: Int32, workingDirectory: String?) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.firstIndex(of: ":") else {
            return (Int32(trimmed) ?? 127, nil)
        }

        let codeText = trimmed[..<separator]
        let encodedDirectory = String(trimmed[trimmed.index(after: separator)...])
        let workingDirectory = Self.decodeBase64Path(encodedDirectory)
        return (Int32(codeText) ?? 127, workingDirectory)
    }

    private func nextCommandGeneration() -> Int {
        lock.lock()
        commandGeneration += 1
        let generation = commandGeneration
        pendingInterruptGeneration = nil
        lock.unlock()
        return generation
    }

    private func markCommandSubmitted(_ generation: Int) {
        lock.lock()
        if commandGeneration < generation {
            commandGeneration = generation
        }
        lock.unlock()
    }

    private func currentCommandGeneration() -> Int {
        lock.lock()
        let generation = commandGeneration
        pendingInterruptGeneration = generation
        lock.unlock()
        return generation
    }

    private func clearPendingInterrupt(for generation: Int) {
        lock.lock()
        if pendingInterruptGeneration == generation {
            pendingInterruptGeneration = nil
        }
        lock.unlock()
    }

    private func finishInteractivePreparation() {
        let completions: [() -> Void]
        lock.lock()
        guard isSuppressingTerminalBroadcast || !interactivePreparationCompletions.isEmpty else {
            lock.unlock()
            return
        }
        isSuppressingTerminalBroadcast = false
        completions = interactivePreparationCompletions
        interactivePreparationCompletions.removeAll()
        lock.unlock()

        completions.forEach { $0() }
    }

    private func scheduleInterruptRecovery(for generation: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for _ in 0..<30 {
                usleep(100_000)
                guard let self else { return }
                if self.isShellForeground() {
                    self.recoverInterruptedCommand(generation: generation)
                    return
                }
            }
        }
    }

    private func recoverInterruptedCommand(generation: Int) {
        lock.lock()
        guard pendingInterruptGeneration == generation else {
            lock.unlock()
            return
        }
        pendingInterruptGeneration = nil
        buffer = ""
        isCapturingCommand = false
        lock.unlock()

        onCommandFinished?(130)
    }

    private func emitOutput(_ text: String) {
        emitRenderedOutput(text)
        let cleaned = text.strippingANSIEscapeSequences()
        guard !cleaned.isEmpty else { return }
        onCommandOutput?(cleaned)
    }

    private func emitRenderedOutput(_ text: String) {
        guard !text.isEmpty else { return }
        let renderText = text.terminalFeedText()
        lock.lock()
        renderedOutputHistory += renderText
        renderedOutputHistory = renderedOutputHistory.cappedSuffix(maxCharacters: 1_000_000)
        let consumers = Array(renderedOutputConsumers.values)
        lock.unlock()

        for consumer in consumers {
            consumer(renderText)
        }
    }

    private func sendControlC() {
        startIfNeeded()
        guard masterFD >= 0 else { return }
        var byte: UInt8 = 0x03
        withUnsafeBytes(of: &byte) { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            Darwin.write(masterFD, baseAddress, 1)
        }
    }

    @discardableResult
    private func signalForegroundProcessGroup(_ signal: Int32) -> Bool {
        guard masterFD >= 0 else { return false }
        let processGroup = tcgetpgrp(masterFD)
        guard processGroup > 0 else { return false }
        return kill(-processGroup, signal) == 0
    }

    private func isShellForeground() -> Bool {
        guard masterFD >= 0, childPID > 0 else { return false }
        return tcgetpgrp(masterFD) == childPID
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func shellPrintfCommand(marker: String, terminator: String = "\\n") -> String {
        let midpoint = marker.index(marker.startIndex, offsetBy: marker.count / 2)
        let first = String(marker[..<midpoint])
        let second = String(marker[midpoint...])
        return "printf '%s%s\(terminator)' '\(first)' '\(second)'"
    }

    private static func decodeBase64Path(_ value: String) -> String? {
        guard let data = Data(base64Encoded: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let path = String(data: data, encoding: .utf8),
              path.hasPrefix("/"),
              path.count <= 4_096 else {
            return nil
        }
        return path
    }

    private static func defaultShellPath() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], isSupportedShell(shell) {
            return shell
        }

        let bufferSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufferSize > 0 else { return "/bin/zsh" }

        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        guard getpwuid_r(getuid(), &pwd, buffer, bufferSize, &result) == 0, let result else {
            return "/bin/zsh"
        }

        let loginShell = String(cString: result.pointee.pw_shell)
        return isSupportedShell(loginShell) ? loginShell : "/bin/zsh"
    }

    private static func isSupportedShell(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard url.path == path,
              url.path.hasPrefix("/"),
              ["zsh", "bash"].contains(url.lastPathComponent),
              FileManager.default.isExecutableFile(atPath: path) else {
            return false
        }
        return true
    }

    private static func homeDirectoryPath() -> String {
        let bufferSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufferSize > 0 else {
            return NSHomeDirectory()
        }

        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        guard getpwuid_r(getuid(), &pwd, buffer, bufferSize, &result) == 0, let result else {
            return NSHomeDirectory()
        }

        return String(cString: result.pointee.pw_dir)
    }
}

private extension String {
    func normalizedTerminalOutput() -> String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    func terminalFeedText() -> String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")
    }

    func trimmingCommandControlWhitespace() -> String {
        var result = self
        while result.hasPrefix("\n") || result.hasPrefix("\r") {
            result.removeFirst()
        }
        while result.hasSuffix("\n") || result.hasSuffix("\r") {
            result.removeLast()
        }
        return result
    }

    func trailingPrefixFragment(of marker: String) -> String {
        guard !isEmpty, !marker.isEmpty else { return "" }
        let maxLength = min(count, marker.count - 1)
        guard maxLength > 0 else { return "" }

        for length in stride(from: maxLength, through: 1, by: -1) {
            let suffix = String(suffix(length))
            if marker.hasPrefix(suffix) {
                return suffix
            }
        }
        return ""
    }

    func strippingANSIEscapeSequences() -> String {
        var result = ""
        var iterator = makeIterator()

        while let character = iterator.next() {
            guard character == "\u{001B}" else {
                result.append(character)
                continue
            }

            guard let next = iterator.next() else { break }
            switch next {
            case "[":
                consumeCSI(from: &iterator)
            case "]":
                consumeOSC(from: &iterator)
            case "(", ")", "*", "+", "-", ".", "/":
                _ = iterator.next()
            default:
                continue
            }
        }

        return result
    }

    func cappedSuffix(maxCharacters: Int) -> String {
        guard count > maxCharacters else { return self }
        return String(suffix(maxCharacters))
    }

    private func consumeCSI(from iterator: inout String.Iterator) {
        while let character = iterator.next() {
            if character.unicodeScalars.allSatisfy({ scalar in
                scalar.value >= 0x40 && scalar.value <= 0x7E
            }) {
                return
            }
        }
    }

    private func consumeOSC(from iterator: inout String.Iterator) {
        var previousWasEscape = false
        while let character = iterator.next() {
            if character == "\u{0007}" {
                return
            }
            if previousWasEscape, character == "\\" {
                return
            }
            previousWasEscape = character == "\u{001B}"
        }
    }
}

private extension Array where Element == String {
    func withCStringArray<Result>(_ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Result) -> Result {
        let cStrings = map { strdup($0) }
        defer {
            cStrings.forEach { free($0) }
        }

        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: count + 1)
        defer {
            argv.deallocate()
        }

        for index in indices {
            argv[index] = cStrings[index]
        }
        argv[count] = nil
        return body(argv)
    }
}
