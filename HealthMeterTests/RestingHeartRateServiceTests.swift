//
//  RestingHeartRateServiceTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 26.1.2022.
//

import XCTest
@testable import HealthMeter
import HealthKit

class RestingHeartRateServiceTests: XCTestCase {
    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
    }

    override func tearDown() {
        super.tearDown()

        userDefaults.removePersistentDomain(forName: #file)
    }

    func testAboveAverage() {
        let service = RestingHeartRateService()

        XCTAssertTrue(service.heartRateIsAboveAverage(update: RestingHeartRateUpdate(date: Date(), value: 70.0), average: 55.0), "Should be significant difference")
        XCTAssertFalse(service.heartRateIsAboveAverage(update: RestingHeartRateUpdate(date: Date(), value: 55.0), average: 55.0), "Should be significant difference")
    }

    func testUpdate_noNotificationIfAvgHRMissing() throws {
        let testUserDefaults = try XCTUnwrap(UserDefaults(suiteName: "test"))
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: testUserDefaults, notificationService: mockNotificationService)
        service.postDebugNotifications = false
        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertFalse(mockNotificationService.postNotificationCalled, "Notification shouldn't be sent if there is no average heart rate")
    }

    func testDecodingAverageHeartRate_launch() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        XCTAssertNil(service.averageHeartRate, "AVG RHR should be nil.")
    }

    func testDecodingAverageHeartRate_notNil() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")
        let avgRHR = try XCTUnwrap(service.averageHeartRate)
        XCTAssertEqual(50.0, avgRHR, accuracy: 0.1, "AVG RHR should be 50.0")
    }

    func testPosted_rising() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 100.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
    }

    func testPosted_risingToLowered() throws {
        let testUserDefaults = try XCTUnwrap(UserDefaults(suiteName: "test"))
        let service = RestingHeartRateService(userDefaults: testUserDefaults)
        testUserDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate)
        let loweringUpdate = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate)

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
        XCTAssertTrue(service.postedAboutLoweredNotificationToday)
    }

    func testPosting_averageRHR() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        service.postDebugNotifications = false
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertFalse(service.postedAboutRisingNotificationToday)
        XCTAssertFalse(service.postedAboutLoweredNotificationToday)
    }
}

func randomString() -> String {
    return UUID().uuidString
}

private class MockNotificationService: NotificationService {
    var postNotificationCalled = false
    override func postNotification(message: String) {
        postNotificationCalled = true
    }
}
