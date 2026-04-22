//
//  FFprobeService.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct FFprobeService {
    let ffprobePath: String

    func inspectMedia(at url: URL) async throws -> MediaInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = [
            "-v", "error",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url.path(percentEncoded: false)
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "FFprobeService",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage?.isEmpty == false ? errorMessage! : "ffprobe failed with status \(process.terminationStatus)."
                ]
            )
        }

        let payload = try JSONDecoder().decode(FFprobePayload.self, from: outputData)
        return MediaInfo(
            duration: TimeInterval(payload.format?.duration ?? ""),
            videoStreams: payload.streams.compactMap { stream in
                guard stream.codecType == "video" else { return nil }
                return MediaInfo.VideoStream(
                    codecName: stream.codecName,
                    width: stream.width,
                    height: stream.height,
                    frameRate: Self.frameRate(from: stream.rFrameRate)
                )
            },
            audioStreams: payload.streams.compactMap { stream in
                guard stream.codecType == "audio" else { return nil }
                return MediaInfo.AudioStream(
                    codecName: stream.codecName,
                    channelCount: stream.channels,
                    sampleRate: Int(stream.sampleRate ?? "")
                )
            }
        )
    }

    private static func frameRate(from value: String?) -> Double? {
        guard let value, !value.isEmpty else { return nil }
        let components = value.split(separator: "/")

        guard components.count == 2,
              let numerator = Double(components[0]),
              let denominator = Double(components[1]),
              denominator != 0 else {
            return Double(value)
        }

        return numerator / denominator
    }
}

private struct FFprobePayload: Decodable {
    let streams: [FFprobeStream]
    let format: FFprobeFormat?
}

private struct FFprobeStream: Decodable {
    let codecType: String?
    let codecName: String?
    let width: Int?
    let height: Int?
    let rFrameRate: String?
    let channels: Int?
    let sampleRate: String?

    enum CodingKeys: String, CodingKey {
        case codecType = "codec_type"
        case codecName = "codec_name"
        case width
        case height
        case rFrameRate = "r_frame_rate"
        case channels
        case sampleRate = "sample_rate"
    }
}

private struct FFprobeFormat: Decodable {
    let duration: String?
}
