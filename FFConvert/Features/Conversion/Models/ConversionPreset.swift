//
//  ConversionPreset.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

enum ConversionPreset: String, CaseIterable, Identifiable {
    case mp4H264
    case hevc
    case audioMP3
    case audioAAC
    case gif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mp4H264:
            return "MP4 H.264"
        case .hevc:
            return "HEVC"
        case .audioMP3:
            return "Audio MP3"
        case .audioAAC:
            return "Audio AAC"
        case .gif:
            return "GIF"
        }
    }

    var subtitle: String {
        switch self {
        case .mp4H264:
            return "Most compatible video"
        case .hevc:
            return "Smaller high-efficiency video"
        case .audioMP3:
            return "Extract audio as MP3"
        case .audioAAC:
            return "Extract audio as AAC"
        case .gif:
            return "Animated image"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4H264, .hevc:
            return "mp4"
        case .audioMP3:
            return "mp3"
        case .audioAAC:
            return "m4a"
        case .gif:
            return "gif"
        }
    }

    var symbolName: String {
        switch self {
        case .mp4H264:
            return "play.rectangle"
        case .hevc:
            return "sparkles.tv"
        case .audioMP3, .audioAAC:
            return "waveform"
        case .gif:
            return "photo.on.rectangle.angled"
        }
    }

}
