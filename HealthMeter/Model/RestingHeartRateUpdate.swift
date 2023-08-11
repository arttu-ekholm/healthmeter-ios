//
//  RestingHeartRateUpdate.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 1.2.2022.
//

import Foundation
import HealthKit

enum UpdateType: Int, Codable {
    case wristTemperature
    case restingHeartRate
}

struct GenericUpdate: Codable {
    let date: Date
    let value: Double
    let type: UpdateType

    init(sample: HKQuantitySample, type: UpdateType, locale: Locale = Locale.current) {
        self.date = sample.endDate
        switch type {
        case .restingHeartRate:
            self.value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .wristTemperature:
            if locale.measurementSystem == .us {
                self.value = sample.quantity.doubleValue(for: HKUnit.degreeFahrenheit())
            } else {
                self.value = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
            }

        }
        self.type = type
    }

    init(date: Date, value: Double, type: UpdateType) {
        self.date = date
        self.value = value
        self.type = type
    }

}
