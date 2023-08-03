//
//  Color+level.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 24.2.2022.
//

import SwiftUI

func colorForLevel(_ level: HeartRateLevel?) -> Color {
    switch level {
    case .belowAverage, .normal: return .green
    case .slightlyElevated: return .yellow
    case .noticeablyElevated: return .orange
    case .wayAboveElevated: return .red
    case nil: return .gray
    }
}

func colorEmojiForLevel(_ level: HeartRateLevel) -> String {
    switch level {
    case .belowAverage, .normal: return "🟩"
    case .slightlyElevated: return "🟨"
    case .noticeablyElevated: return "🟧"
    case .wayAboveElevated: return "🟥"
    }
}
