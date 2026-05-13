// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

@Suite("ProcessCommandRunner")
struct ProcessCommandRunnerTests {
    @Test func commandEmitsOutputAndExitCode() async {
        let result = await run("printf hello; sleep 0.1")

        #expect(result.output == "hello")
        #expect(result.exitCode == 0)
    }

    @Test func commandReportsNonZeroExitCode() async {
        let result = await run("exit 7")

        #expect(result.exitCode == 7)
    }

    @Test func interruptStopsLongRunningCommand() async {
        let result = await run("sleep 5", interruptAfter: 0.2, timeout: 2.0)

        #expect(result.exitCode != 0)
    }

    private func run(
        _ command: String,
        interruptAfter: TimeInterval? = nil,
        timeout: TimeInterval = 3.0
    ) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            let box = RunnerBox()
            box.runner = ProcessCommandRunner(
                command: command,
                workingDirectory: FileManager.default.temporaryDirectory
            )
            box.runner?.start(
                onOutput: { output in
                    box.lock.lock()
                    box.output += output
                    box.lock.unlock()
                },
                onFinish: { exitCode in
                    box.finish(exitCode: exitCode, continuation: continuation)
                }
            )

            if let interruptAfter {
                DispatchQueue.global().asyncAfter(deadline: .now() + interruptAfter) {
                    box.runner?.interrupt()
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                box.runner?.forceKill()
                box.finish(exitCode: 124, continuation: continuation)
            }
        }
    }
}

private final class RunnerBox: @unchecked Sendable {
    let lock = NSLock()
    var output = ""
    var runner: ProcessCommandRunner?
    private var didFinish = false

    func finish(
        exitCode: Int32,
        continuation: CheckedContinuation<(output: String, exitCode: Int32), Never>
    ) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let result = (output, exitCode)
        runner = nil
        lock.unlock()

        continuation.resume(returning: result)
    }
}
