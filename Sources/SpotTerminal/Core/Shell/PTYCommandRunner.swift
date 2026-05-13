// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

final class PTYCommandRunner {
    static let exitMarkerPrefix = "__FLOAT_TERMINAL_EXIT:"
    static let exitMarkerSuffix = "__"

    private let command: String
    private let workingDirectory: String
    private var childPID: pid_t = 0
    private var masterFD: Int32 = -1
    private var outputHandle: FileHandle?
    private let lock = NSLock()
    private var didFinish = false
    private var pendingOutput = ""

    init(command: String, workingDirectory: String) {
        self.command = command
        self.workingDirectory = workingDirectory
    }

    func start(onOutput: @escaping (String) -> Void, onFinish: @escaping (Int32) -> Void) {
        var windowSize = winsize(ws_row: 28, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
        let pid = forkpty(&masterFD, nil, nil, &windowSize)

        if pid == 0 {
            setpgid(0, 0)
            setenv("TERM", "xterm-256color", 1)
            setenv("COLORTERM", "truecolor", 1)
            chdir(workingDirectory)
            execShell(command)
            _exit(127)
        }

        guard pid > 0 else {
            onFinish(127)
            return
        }

        childPID = pid
        let handle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        outputHandle = handle

        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            self.processOutput(text, onOutput: onOutput, onFinish: onFinish)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var status: Int32 = 0
            let waited = waitpid(pid, &status, 0)
            let exitCode = waited > 0 ? Self.exitCode(fromWaitStatus: status) : 127
            let pending = self.drainPendingOutput()
            if !pending.isEmpty {
                onOutput(pending)
            }
            self.finishOnce(exitCode: exitCode, onFinish: onFinish)
        }
    }

    func interrupt() {
        send(SIGINT)
    }

    func forceKill() {
        send(SIGKILL)
    }

    private func send(_ signal: Int32) {
        guard childPID > 0 else { return }
        kill(-childPID, signal)
    }

    private func closeOutput() {
        outputHandle?.readabilityHandler = nil
        outputHandle?.closeFile()
        outputHandle = nil
    }

    private func processOutput(_ text: String, onOutput: @escaping (String) -> Void, onFinish: @escaping (Int32) -> Void) {
        lock.lock()
        pendingOutput += text

        guard let markerRange = pendingOutput.range(of: Self.exitMarkerPrefix) else {
            let retained = pendingOutput.trailingPrefixFragment(of: Self.exitMarkerPrefix)
            let emitEnd = pendingOutput.index(pendingOutput.endIndex, offsetBy: -retained.count)
            let emit = String(pendingOutput[..<emitEnd])
            pendingOutput = retained
            lock.unlock()
            if !emit.isEmpty {
                onOutput(emit)
            }
            return
        }

        let beforeMarker = String(pendingOutput[..<markerRange.lowerBound])
        let codeStart = markerRange.upperBound
        guard let suffixRange = pendingOutput[codeStart...].range(of: Self.exitMarkerSuffix) else {
            lock.unlock()
            return
        }

        let codeText = pendingOutput[codeStart..<suffixRange.lowerBound]
        let exitCode = Int32(codeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 127
        pendingOutput.removeAll(keepingCapacity: true)
        lock.unlock()

        if !beforeMarker.isEmpty {
            onOutput(beforeMarker.trimmingTrailingControlWhitespace())
        }
        finishOnce(exitCode: exitCode, onFinish: onFinish)
    }

    private func finishOnce(exitCode: Int32, onFinish: @escaping (Int32) -> Void) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        closeOutput()
        onFinish(exitCode)
    }

    private func drainPendingOutput() -> String {
        lock.lock()
        defer { lock.unlock() }
        let output = pendingOutput
        pendingOutput.removeAll(keepingCapacity: true)
        return output
    }

    private static func exitCode(fromWaitStatus status: Int32) -> Int32 {
        if status & 0x7f == 0 {
            return (status >> 8) & 0xff
        }
        return 128 + (status & 0x7f)
    }
}

private func execShell(_ command: String) {
    let shell = "/bin/zsh"
    let wrappedCommand = """
    {
    \(command)
    }
    __float_terminal_exit_code=$?
    printf '\\n\(PTYCommandRunner.exitMarkerPrefix)%d\(PTYCommandRunner.exitMarkerSuffix)\\n' $__float_terminal_exit_code
    exit $__float_terminal_exit_code
    """
    let argv = [shell, "-lc", wrappedCommand]

    _ = argv.withCStringArray { pointer in
        execv(shell, pointer)
    }
}

private extension String {
    func trimmingTrailingControlWhitespace() -> String {
        var result = self
        while result.hasSuffix("\n") || result.hasSuffix("\r") {
            result.removeLast()
        }
        return result.isEmpty ? self : result
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
