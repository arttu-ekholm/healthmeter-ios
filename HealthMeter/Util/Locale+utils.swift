//
//  Locale+utils.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 10.8.2023.
//

import Foundation

extension Locale {
    var temperatureSymbol: String {
        switch self.measurementSystem {
        case .us: return "F"
        default: return "C"
        }
    }
}
