//
//  ConversionFailureSummarizer.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct ConversionFailureSummarizer {
    func summarize(status: Int32?, output: String, error: Error?) -> String {
        if let error {
            return error.localizedDescription
        }

        let lines = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let line = lines.last(where: { candidate in
            let lowercased = candidate.lowercased()
            return lowercased.contains("error") || lowercased.contains("invalid") || lowercased.contains("failed")
        }) {
            return line
        }

        if let status {
            return "FFmpeg exited with status \(status)."
        }

        return "The conversion failed."
    }
}
