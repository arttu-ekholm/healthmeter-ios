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
/*
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
 */

enum UpdateType: Int, Codable {
    case wristTemperature
    case restingHeartRate
}

struct GenericUpdate: Codable {
    let date: Date
    let value: Double
    let type: UpdateType

    init(sample: HKQuantitySample, type: UpdateType) {
        self.date = sample.endDate
        switch type {
        case .restingHeartRate:
            self.value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        case .wristTemperature:
            self.value = sample.quantity.doubleValue(for: HKUnit(from: "degC"))
        }
        self.type = type

        //self.value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
    }

    init(date: Date, value: Double, type: UpdateType) {
        self.date = date
        self.value = value
        self.type = type
    }

}
