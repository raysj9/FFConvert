//
//  ConversionHistoryItem.swift
//  FFConvert
//
//  Created by Samuel Ray.
//

import Foundation

struct ConversionHistoryItem: Identifiable, Equatable {
    enum Result: String {
        case succeeded
        case failed
        case cancelled
        case incompatible

        var title: String {
            rawValue.capitalized
        }
    }

    let id: UUID
    let inputURL: URL
    let outputURL: URL?
    let preset: ConversionPreset
    let result: Result
    let summary: String
    let completedAt: Date
}
