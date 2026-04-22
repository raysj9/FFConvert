//
//  ConversionQueueItem.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct ConversionQueueItem: Identifiable {
    enum Status: String {
        case inspecting
        case ready
        case converting
        case cancelling
        case cancelled
        case succeeded
        case failed
        case incompatible

        var title: String {
            rawValue.capitalized
        }
    }

    let id: UUID
    let inputURL: URL
    var outputURL: URL
    var preset: ConversionPreset
    var mediaInfo: MediaInfo?
    var compatibilityResult: PresetCompatibilityResult?
    var progressFraction: Double?
    var progressText: String
    var status: Status
    var errorSummary: String?
    var diagnosticsOutput: String
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        inputURL: URL,
        outputURL: URL,
        preset: ConversionPreset
    ) {
        self.id = id
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.preset = preset
        self.mediaInfo = nil
        self.compatibilityResult = nil
        self.progressFraction = nil
        self.progressText = "Queued"
        self.status = .inspecting
        self.errorSummary = nil
        self.diagnosticsOutput = ""
        self.completedAt = nil
    }
}
