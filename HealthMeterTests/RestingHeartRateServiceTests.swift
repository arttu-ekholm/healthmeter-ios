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
        userDefaults?.removePersistentDomain(forName: #file)
        userDefaults = UserDefaults(suiteName: #file)
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
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: mockNotificationService)
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
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate)
        let loweringUpdate = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate)

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
        XCTAssertTrue(service.postedAboutLoweredNotificationToday)
    }

    /**
     Handling and update that == qvg RHR doesn't cause any notifications being posted
     */
    func testPosting_averageRHR() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        service.postDebugNotifications = false
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertFalse(service.postedAboutRisingNotificationToday)
        XCTAssertFalse(service.postedAboutLoweredNotificationToday)
    }

    /**
     Service gets high, average, high average resting rate. The app should post notification about one about rising HRH, and one about lowered RHR.
     */
    func testPosted_multiple() throws {
        let notificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: notificationService)
        service.postDebugNotifications = false
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate1 = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60*3), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate1)
        let loweringUpdate1 = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60*2), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate1)
        let risingUpdate2 = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate2)
        let loweringUpdate2 = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate2)
        XCTAssertEqual(notificationService.postNotificationCalledCount, 2, "Only two notifications should be sent - one for high RHR and and another for lowered RRH")

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
        XCTAssertTrue(service.postedAboutLoweredNotificationToday)
    }
}

private class MockNotificationService: NotificationService {
    var postNotificationCalledCount = 0
    var postNotificationCalled: Bool {
        return postNotificationCalledCount > 0
    }
    override func postNotification(message: String) {
        postNotificationCalledCount += 1
    }
}
