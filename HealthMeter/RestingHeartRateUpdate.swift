//
//  RestingHeartRateUpdate.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 1.2.2022.
//

import Foundation
import HealthKit

/**
 Wraps the relevant fields of `HKQuantitySample` object
 */
struct RestingHeartRateUpdate: Codable {
    let date: Date
    let value: Double
    let isRealUpdate: Bool

    init(sample: HKQuantitySample) {
        self.date = sample.endDate
        self.value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        self.isRealUpdate = true
    }

    init(date: Date, value: Double, isRealUpdate: Bool = true) {
        self.date = date
        self.value = value
        self.isRealUpdate = isRealUpdate
    }
}
