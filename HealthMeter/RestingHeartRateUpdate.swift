//
//  RestingHeartRateUpdate.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 1.2.2022.
//

import Foundation
import HealthKit

struct RestingHeartRateUpdate: Codable {
    let date: Date
    let value: Double

    init(sample: HKQuantitySample) {
        self.date = sample.endDate
        self.value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
    }

    init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

