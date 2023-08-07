//
//  RestingHeartRateUpdateTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import Foundation
@testable import HealthMeter
import HealthKit
import XCTest

class RestingHeartRateUpdateTests: XCTestCase {
    func testInitFromHKQuantitySample() throws {
        let value = 50.0
        let type = try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: .restingHeartRate))
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let now = Date()
        let sample = HKQuantitySample(type: type, quantity: quantity, start: now.addingTimeInterval(-1), end: now)

        let update = GenericUpdate(sample: sample, type: .restingHeartRate)

        XCTAssertEqual(now, update.date)
        XCTAssertEqual(value, update.value, accuracy: 0.001)

    }

    func testInitFromDoubleAndDate() {
        let date = Date()
        let value = 50.0

        let update = GenericUpdate(date: date, value: value, type: .restingHeartRate)

        XCTAssertEqual(date, update.date)
        XCTAssertEqual(value, update.value, accuracy: 0.001)
    }
}
