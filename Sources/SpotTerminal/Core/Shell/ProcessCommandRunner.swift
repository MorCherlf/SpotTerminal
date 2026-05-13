// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Darwin
import Foundation

final class ProcessCommandRunner {
    private let command: String
    private let workingDirectory: URL
    private var childPID: pid_t = 0
    private var readFD: Int32 = -1
    private var readHandle: FileHandle?
    private let lock = NSLock()
    private var didFinish = false

    init(command: String, workingDirectory: URL) {
        self.command = command
        self.workingDirectory = workingDirectory
    }

    func start(onOutput: @escaping (String) -> Void, onFinish: @escaping (Int32) -> Void) {
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            onOutput("Failed to create output pipe.\n")
            onFinish(127)
            return
        }

        var pid: pid_t = 0
        let spawnResult = spawnChild(pid: &pid, readFD: fds[0], writeFD: fds[1])
        guard spawnResult == 0, pid > 0 else {
            close(fds[0])
            close(fds[1])
            onOutput("Failed to launch command: \(String(cString: strerror(spawnResult))).\n")
            onFinish(127)
            return
        }

        childPID = pid
        readFD = fds[0]
        close(fds[1])

        let handle = FileHandle(fileDescriptor: readFD, closeOnDealloc: true)
        readHandle = handle
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            onOutput(String(decoding: data, as: UTF8.self))
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var status: Int32 = 0
            let waited = waitpid(pid, &status, 0)
            let exitCode = waited > 0 ? Self.exitCode(fromWaitStatus: status) : 127
            self.finishOnce(exitCode: exitCode, onOutput: onOutput, onFinish: onFinish)
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
        let result = kill(-childPID, signal)
        if result != 0 {
            kill(childPID, signal)
        }
    }

    private func finishOnce(exitCode: Int32, onOutput: @escaping (String) -> Void, onFinish: @escaping (Int32) -> Void) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let handle = readHandle
        readHandle = nil
        lock.unlock()

        handle?.readabilityHandler = nil
        if let remaining = try? handle?.readToEnd(), !remaining.isEmpty {
            // The readability handler can miss the final short chunk if waitpid wins the race.
            onOutput(String(decoding: remaining, as: UTF8.self))
        }
        handle?.closeFile()
        onFinish(exitCode)
    }

    private static func exitCode(fromWaitStatus status: Int32) -> Int32 {
        if status & 0x7f == 0 {
            return (status >> 8) & 0xff
        }
        return 128 + (status & 0x7f)
    }

    private func spawnChild(pid: inout pid_t, readFD: Int32, writeFD: Int32) -> Int32 {
        let shell = "/bin/zsh"
        let wrappedCommand = "cd \(Self.shellQuoted(workingDirectory.path)); TERM=xterm-256color COLORTERM=truecolor \(command)"
        let argv = [shell, "-lc", wrappedCommand]

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer {
            posix_spawn_file_actions_destroy(&actions)
        }

        posix_spawn_file_actions_adddup2(&actions, writeFD, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, writeFD, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, readFD)
        posix_spawn_file_actions_addclose(&actions, writeFD)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawnattr_destroy(&attributes)
        }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)

        return argv.withCStringArray { pointer in
            posix_spawn(&pid, shell, &actions, &attributes, pointer, environ)
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
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
