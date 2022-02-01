//
//  RestingHeartRateServiceTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 26.1.2022.
//

import XCTest
@testable import HealthMeter

class RestingHeartRateServiceTests: XCTestCase {
    func testAboveAverage() {
        let service = RestingHeartRateService()

        XCTAssertTrue(service.heartRateIsAboveAverage(update: RestingHeartRateUpdate(date: Date(), value: 70.0), average: 55.0), "Should be significant difference")
        XCTAssertFalse(service.heartRateIsAboveAverage(update: RestingHeartRateUpdate(date: Date(), value: 55.0), average: 55.0), "Should be significant difference")
    }
}

