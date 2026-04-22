//
//  MediaInfo.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct MediaInfo: Sendable {
    struct VideoStream: Sendable {
        let codecName: String?
        let width: Int?
        let height: Int?
        let frameRate: Double?
    }

    struct AudioStream: Sendable {
        let codecName: String?
        let channelCount: Int?
        let sampleRate: Int?
    }

    let duration: TimeInterval?
    let videoStreams: [VideoStream]
    let audioStreams: [AudioStream]

    var hasVideo: Bool {
        !videoStreams.isEmpty
    }

    var hasAudio: Bool {
        !audioStreams.isEmpty
    }

    var primaryVideo: VideoStream? {
        videoStreams.first
    }

    var primaryAudio: AudioStream? {
        audioStreams.first
    }

    var formattedDuration: String {
        guard let duration,
              let value = Self.durationFormatter.string(from: duration) else {
            return "Unknown"
        }

        return value
    }

    var videoSummary: String {
        guard let primaryVideo else { return "No video stream" }

        let codec = primaryVideo.codecName?.uppercased() ?? "Unknown codec"
        let dimensions: String

        if let width = primaryVideo.width, let height = primaryVideo.height {
            dimensions = "\(width)×\(height)"
        } else {
            dimensions = "Unknown size"
        }

        if let frameRate = primaryVideo.frameRate, frameRate > 0 {
            return "\(codec) • \(dimensions) • \(frameRate.formatted(.number.precision(.fractionLength(0...2)))) fps"
        }

        return "\(codec) • \(dimensions)"
    }

    var audioSummary: String {
        guard let primaryAudio else { return "No audio stream" }

        let codec = primaryAudio.codecName?.uppercased() ?? "Unknown codec"
        let channels: String

        if let channelCount = primaryAudio.channelCount {
            channels = "\(channelCount)ch"
        } else {
            channels = "Unknown channels"
        }

        if let sampleRate = primaryAudio.sampleRate {
            return "\(codec) • \(channels) • \(sampleRate / 1000) kHz"
        }

        return "\(codec) • \(channels)"
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
