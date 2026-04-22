//
//  FFmpegRunner.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

actor FFmpegRunner {
    let ffmpegPath: String
    private var currentProcess: Process?

    init(ffmpegPath: String) {
        self.ffmpegPath = ffmpegPath
    }

    func run(
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe
        currentProcess = process

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                onOutput(text)
            }
        }

        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            if let text = String(data: data, encoding: .utf8) {
                onOutput(text)
            }
        }

        try process.run()

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                Task {
                    await self.clearCurrentProcess(ifMatching: process)
                }

                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil

                let remainingOutput = outputHandle.readDataToEndOfFile()
                if !remainingOutput.isEmpty,
                   let text = String(data: remainingOutput, encoding: .utf8) {
                    onOutput(text)
                }

                let remainingError = errorHandle.readDataToEndOfFile()
                if !remainingError.isEmpty,
                   let text = String(data: remainingError, encoding: .utf8) {
                    onOutput(text)
                }

                continuation.resume(returning: process.terminationStatus)
            }
        }
    }

    func cancelCurrentRun() {
        guard let currentProcess, currentProcess.isRunning else { return }
        currentProcess.terminate()
    }

    private func clearCurrentProcess(ifMatching process: Process) {
        guard currentProcess === process else { return }
        currentProcess = nil
    }
}
