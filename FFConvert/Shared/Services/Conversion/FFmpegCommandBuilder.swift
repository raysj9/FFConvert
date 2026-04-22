//
//  FFmpegCommandBuilder.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct FFmpegCommandBuilder {
    func arguments(
        for preset: ConversionPreset,
        inputURL: URL,
        outputURL: URL
    ) -> [String] {
        switch preset {
        case .mp4H264:
            return [
                "-y",
                "-i", inputURL.path(percentEncoded: false),
                "-c:v", "libx264",
                "-c:a", "aac",
                "-movflags", "+faststart",
                outputURL.path(percentEncoded: false)
            ]
        case .hevc:
            return [
                "-y",
                "-i", inputURL.path(percentEncoded: false),
                "-c:v", "libx265",
                "-tag:v", "hvc1",
                "-c:a", "aac",
                "-movflags", "+faststart",
                outputURL.path(percentEncoded: false)
            ]
        case .audioMP3:
            return [
                "-y",
                "-i", inputURL.path(percentEncoded: false),
                "-vn",
                "-c:a", "libmp3lame",
                "-q:a", "2",
                outputURL.path(percentEncoded: false)
            ]
        case .audioAAC:
            return [
                "-y",
                "-i", inputURL.path(percentEncoded: false),
                "-vn",
                "-c:a", "aac",
                "-b:a", "192k",
                outputURL.path(percentEncoded: false)
            ]
        case .gif:
            return [
                "-y",
                "-i", inputURL.path(percentEncoded: false),
                "-vf", "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                outputURL.path(percentEncoded: false)
            ]
        }
    }
}
