//
//  OutputFileCoordinator.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct OutputFileSession {
    let finalURL: URL
    let temporaryURL: URL
}

struct OutputFileCoordinator {
    private let fileManager = FileManager.default

    func makeSession(for finalURL: URL) throws -> OutputFileSession {
        let replacementDirectory = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: finalURL,
            create: true
        )

        let temporaryURL = replacementDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(finalURL.pathExtension)

        return OutputFileSession(finalURL: finalURL, temporaryURL: temporaryURL)
    }

    func promoteTemporaryFile(for session: OutputFileSession) throws {
        if fileManager.fileExists(atPath: session.finalURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: session.finalURL)
        }

        try fileManager.moveItem(at: session.temporaryURL, to: session.finalURL)
        try cleanupParentDirectoryIfNeeded(for: session.temporaryURL)
    }

    func cleanupTemporaryFile(for session: OutputFileSession) {
        if fileManager.fileExists(atPath: session.temporaryURL.path(percentEncoded: false)) {
            try? fileManager.removeItem(at: session.temporaryURL)
        }

        try? cleanupParentDirectoryIfNeeded(for: session.temporaryURL)
    }

    private func cleanupParentDirectoryIfNeeded(for temporaryURL: URL) throws {
        let directoryURL = temporaryURL.deletingLastPathComponent()
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)

        if contents.isEmpty {
            try fileManager.removeItem(at: directoryURL)
        }
    }
}
