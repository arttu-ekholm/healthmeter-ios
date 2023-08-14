//
//  DecisionEngineTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 14.8.2023.
//

import XCTest
@testable import HealthMeter

class DecisionEngineTests: XCTestCase {
    func testWristTemperatureIsAboveAverage() {
        let dengMetric = DecisionEngineImplementation(locale: Locale(identifier: "fi_FI"))
        let dengImperial = DecisionEngineImplementation(locale: Locale(identifier: "en_US"))
        let update = GenericUpdate(date: Date(), value: 38.01, type: .wristTemperature)
        let update2 = GenericUpdate(date: Date(), value: 37.04, type: .wristTemperature)
        XCTAssertTrue(dengMetric.wristTemperatureIsAboveAverage(update: update, average: 37.0))
        XCTAssertFalse(dengMetric.wristTemperatureIsAboveAverage(update: update2, average: 37.0))
        XCTAssertFalse(dengMetric.wristTemperatureIsAboveAverage(update: GenericUpdate(date: Date(), value: 39.0, type: .restingHeartRate), average: 37.0))

        let updateImperial = GenericUpdate(date: Date(), value: 101.9, type: .wristTemperature)
        let updateImperial2 = GenericUpdate(date: Date(), value: 100.2, type: .wristTemperature)
        XCTAssertTrue(dengImperial.wristTemperatureIsAboveAverage(update: updateImperial, average: 100.0))
        XCTAssertFalse(dengImperial.wristTemperatureIsAboveAverage(update: updateImperial2, average: 100.0))
        XCTAssertFalse(dengImperial.wristTemperatureIsAboveAverage(update: GenericUpdate(date: Date(), value: 103.0, type: .restingHeartRate), average: 100.0))

    }

    func testAboveAverage() {
        let deng = DecisionEngineImplementation()

        XCTAssertTrue(deng.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 70.0,
                type: .restingHeartRate),
            average: 55.0), "Should be significant difference")
        XCTAssertFalse(deng.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 55.0,
                type: .restingHeartRate),
            average: 55.0), "Should be significant difference")
        XCTAssertFalse(deng.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 53.0,
                type: .restingHeartRate),
            average: 55.0), "Below average should return false")
        XCTAssertFalse(deng.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 10.0,
                type: .restingHeartRate),
            average: 55.0), "Below average should return false")
    }

    func testNotificationTitleContainsColorEmoji() {
        let service = DecisionManager(decisionEngine: DecisionEngineImplementation())
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .lowering, heartRate: 30, averageHeartRate: 50).contains("🟩"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 50, averageHeartRate: 50).contains("🟩"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 53, averageHeartRate: 50).contains("🟨"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 56, averageHeartRate: 50).contains("🟧"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 70, averageHeartRate: 50).contains("🟥"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 100, averageHeartRate: 50).contains("🟥"))
    }
}
