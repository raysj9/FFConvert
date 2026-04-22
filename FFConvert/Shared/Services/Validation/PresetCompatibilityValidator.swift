//
//  PresetCompatibilityValidator.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct PresetCompatibilityResult: Sendable {
    let isCompatible: Bool
    let message: String
}

struct PresetCompatibilityValidator {
    func validate(preset: ConversionPreset, mediaInfo: MediaInfo) -> PresetCompatibilityResult {
        switch preset {
        case .mp4H264, .hevc:
            guard mediaInfo.hasVideo else {
                return PresetCompatibilityResult(
                    isCompatible: false,
                    message: "\(preset.title) requires a video stream."
                )
            }
        case .audioMP3, .audioAAC:
            guard mediaInfo.hasAudio else {
                return PresetCompatibilityResult(
                    isCompatible: false,
                    message: "\(preset.title) requires an audio stream."
                )
            }
        case .gif:
            guard mediaInfo.hasVideo else {
                return PresetCompatibilityResult(
                    isCompatible: false,
                    message: "GIF export requires a video stream."
                )
            }
        }

        return PresetCompatibilityResult(
            isCompatible: true,
            message: "\(preset.title) is compatible with this file."
        )
    }
}
