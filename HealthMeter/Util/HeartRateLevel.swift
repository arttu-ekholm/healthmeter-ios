//
//  HeartRateLevel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 26.8.2023.
//

import Foundation

enum HeartRateLevel {
    case belowAverage
    case normal
    case slightlyElevated
    case noticeablyElevated
    case wayAboveElevated

    var numericValue: Int {
        switch self {
        case .belowAverage, .normal: return 0
        case .slightlyElevated: return 1
        case .noticeablyElevated: return 2
        case .wayAboveElevated: return 3
        }
    }

    static func hrvMultiplier(multiplier: Double) -> HeartRateLevel {
        if multiplier > 1.2 {
            if multiplier > 2.0 {
                return .wayAboveElevated
            } else if multiplier > 1.5 {
                return .noticeablyElevated
            } else {
                return .slightlyElevated
            }
        } else if multiplier < 0.95 {
            return .belowAverage
        } else {
            return .normal
        }
    }

    static func heartRateLevelForMultiplier(multiplier: Double) -> HeartRateLevel {
        if multiplier > 1.05 {
            if multiplier > 1.2 {
                return .wayAboveElevated
            } else if multiplier > 1.1 {
                return .noticeablyElevated
            } else {
                return .slightlyElevated
            }
        } else if multiplier < 0.95 {
            return .belowAverage
        } else {
            return .normal
        }
    }
}

