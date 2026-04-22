//
//  OutputConflictResolver.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import AppKit
import Foundation

struct OutputConflictResolution: Sendable {
    let outputURL: URL
    let note: String?
}

struct OutputConflictResolver {
    private let fileManager = FileManager.default

    @MainActor
    func resolveOutputURL(_ outputURL: URL) -> OutputConflictResolution? {
        guard fileManager.fileExists(atPath: outputURL.path(percentEncoded: false)) else {
            return OutputConflictResolution(outputURL: outputURL, note: nil)
        }

        let alert = NSAlert()
        alert.messageText = "Output file already exists"
        alert.informativeText = "Choose whether to replace it, keep both files, or cancel the conversion."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return OutputConflictResolution(outputURL: outputURL, note: "Existing file will be replaced.")
        case .alertSecondButtonReturn:
            let renamedURL = nextAvailableURL(basedOn: outputURL)
            return OutputConflictResolution(outputURL: renamedURL, note: "Output renamed to avoid overwriting the existing file.")
        default:
            return nil
        }
    }

    private func nextAvailableURL(basedOn outputURL: URL) -> URL {
        let directory = outputURL.deletingLastPathComponent()
        let baseName = outputURL.deletingPathExtension().lastPathComponent
        let fileExtension = outputURL.pathExtension

        for index in 2...10_000 {
            let candidate = directory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(fileExtension)

            if !fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }

        return directory
            .appendingPathComponent("\(baseName) \(UUID().uuidString.prefix(4))")
            .appendingPathExtension(fileExtension)
    }
}
