//
//  Color+level.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 24.2.2022.
//

import SwiftUI

func colorForLevel(_ level: HeartRateLevel?) -> Color {
    switch level {
    case .belowAverage: return .blue
    case .normal: return .green
    case .slightlyElevated: return .yellow
    case .noticeablyElevated: return .orange
    case .wayAboveElevated: return .red
    case nil: return .gray
    }
}
