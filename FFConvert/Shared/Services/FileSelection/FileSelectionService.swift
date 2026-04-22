//
//  FileSelectionService.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import AppKit
import Foundation

struct FileSelectionService {
    @MainActor
    func selectOutputDirectory(initialDirectory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = initialDirectory
        panel.prompt = "Choose Folder"

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func suggestedOutputURL(for inputURL: URL, preset: ConversionPreset, outputDirectory: URL?) -> URL {
        let directory = outputDirectory ?? inputURL.deletingLastPathComponent()
        let baseName = inputURL.deletingPathExtension().lastPathComponent

        return directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(preset.fileExtension)
    }

    func updatedOutputURL(
        from currentOutputURL: URL?,
        inputURL: URL,
        preset: ConversionPreset,
        outputDirectory: URL?
    ) -> URL {
        guard let currentOutputURL else {
            return suggestedOutputURL(for: inputURL, preset: preset, outputDirectory: outputDirectory)
        }

        let directory = outputDirectory ?? currentOutputURL.deletingLastPathComponent()
        let baseName = currentOutputURL.deletingPathExtension().lastPathComponent

        return directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(preset.fileExtension)
    }
}
