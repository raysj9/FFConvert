//
//  FFmpegProgressParser.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct FFmpegProgressUpdate: Sendable {
    let fractionComplete: Double?
    let elapsedTimeDescription: String
}

actor FFmpegProgressParser {
    private var duration: TimeInterval?
    private var bufferedOutput = ""

    func consume(_ chunk: String) -> FFmpegProgressUpdate? {
        bufferedOutput += chunk.replacingOccurrences(of: "\r", with: "\n")

        let lines = bufferedOutput.components(separatedBy: "\n")
        bufferedOutput = lines.last ?? ""

        var latestUpdate: FFmpegProgressUpdate?

        for line in lines.dropLast() {
            if let parsedDuration = parseDuration(from: line) {
                duration = parsedDuration
            }

            if let elapsedTime = parseElapsedTime(from: line) {
                latestUpdate = FFmpegProgressUpdate(
                    fractionComplete: progressFraction(for: elapsedTime),
                    elapsedTimeDescription: Self.timeFormatter.string(from: elapsedTime) ?? "0:00"
                )
            }
        }

        return latestUpdate
    }

    private func progressFraction(for elapsedTime: TimeInterval) -> Double? {
        guard let duration, duration > 0 else { return nil }
        return min(max(elapsedTime / duration, 0), 1)
    }

    private func parseDuration(from line: String) -> TimeInterval? {
        guard let range = line.range(of: #"Duration:\s*([0-9:.]+)"#, options: .regularExpression) else {
            return nil
        }

        let match = String(line[range])
        let value = match.replacingOccurrences(of: "Duration:", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Self.timeInterval(from: value)
    }

    private func parseElapsedTime(from line: String) -> TimeInterval? {
        guard let range = line.range(of: #"time=([0-9:.]+)"#, options: .regularExpression) else {
            return nil
        }

        let match = String(line[range])
        let value = match.replacingOccurrences(of: "time=", with: "")
        return Self.timeInterval(from: value)
    }

    private static func timeInterval(from string: String) -> TimeInterval? {
        let components = string.split(separator: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }

        return (hours * 3600) + (minutes * 60) + seconds
    }

    private static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
