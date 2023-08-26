//
//  DecisionManagerTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 14.8.2023.
//

import XCTest
@testable import HealthMeter

class DecisionManagerTests: XCTestCase {
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

    func testUpdate_noNotificationIfAvgHRMissing() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: DecisionManager(notificationService: mockNotificationService))
        let update = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        XCTAssertFalse(mockNotificationService.postNotificationCalled, "Notification shouldn't be sent if there is no average heart rate")
    }

    func testUpdate_noNotificationIfAvgWTMissing() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: DecisionManager(notificationService: mockNotificationService))
        let update = GenericUpdate(date: Date(), value: 37.0, type: .wristTemperature)
        service.handleUpdate(update: update)

        XCTAssertFalse(mockNotificationService.postNotificationCalled, "Notification shouldn't be sent if there is no average wrist temperature")
    }

    func testPosted_rising() throws {
        let decisionManager = DecisionManager(userDefaults: userDefaults, decisionEngine: DecisionEngineImplementation())
        let service = RestingHeartRateService(
            userDefaults: userDefaults,
            decisionManager: decisionManager)
        userDefaults.set(50.0, forKey: "average_\(UpdateType.restingHeartRate)_key")

        let update = GenericUpdate(date: Date(), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        let predicate = NSPredicate { service, _ in
            guard let service = service as? DecisionManager else { return false }
            return service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }
        _ = expectation(for: predicate, evaluatedWith: decisionManager, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testPosted_risingToLowered() throws {
        let mockNotificationService = MockNotificationService()
        let decisionManager = DecisionManager(notificationService: mockNotificationService, userDefaults: userDefaults)
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: decisionManager)
        userDefaults.set(50.0, forKey: "average_\(UpdateType.restingHeartRate)_key")

        let risingUpdate = GenericUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: risingUpdate)
        let loweringUpdate = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: loweringUpdate)

        let risingNotificationCalled = NSPredicate { service, _ in
            guard let service = service as? DecisionManager else { return false }
            return service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }

        let loweredNotificationCalled = NSPredicate { service, _ in
            guard let service = service as? DecisionManager else { return false }
            return service.hasPostedAboutLoweredNotificationToday
        }
        _ = expectation(for: risingNotificationCalled, evaluatedWith: decisionManager, handler: .none)
        _ = expectation(for: loweredNotificationCalled, evaluatedWith: decisionManager, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    /**
     Handling and update that == qvg RHR doesn't cause any notifications being posted
     */
    func testPosting_averageRHR() throws {
        let decisionManager = DecisionManager(userDefaults: userDefaults)
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: decisionManager)
        userDefaults.set(50.0, forKey: "average_\(UpdateType.restingHeartRate)_key")

        let update = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        XCTAssertFalse(decisionManager.hasPostedAboutRisingNotificationToday(type: .restingHeartRate))
        XCTAssertFalse(decisionManager.hasPostedAboutLoweredNotificationToday)
    }

    func testPosting_averageWT() throws {
        let decisionManager = DecisionManager(userDefaults: userDefaults)
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: decisionManager)
        userDefaults.set(37.0, forKey: "AverageWristTemperature")

        let update = GenericUpdate(date: Date(), value: 37.0, type: .wristTemperature)
        service.handleUpdate(update: update)

        XCTAssertFalse(decisionManager.hasPostedAboutRisingNotificationToday(type: .wristTemperature))
        XCTAssertFalse(decisionManager.hasPostedAboutLoweredNotificationToday)
    }

    /**
     Service gets high, average, high average resting rate. The app should post notification about one about rising HRH, and one about lowered RHR.
     */
    func testPosted_multiple() throws {
        let notificationService = MockNotificationService()
        let decisionManager = DecisionManager(notificationService: notificationService, userDefaults: userDefaults)
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: decisionManager)
        userDefaults.set(50.0, forKey: "average_\(UpdateType.restingHeartRate)_key")

        let risingUpdate1 = GenericUpdate(date: Date().addingTimeInterval(-60*60*3), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: risingUpdate1)
        let loweringUpdate1 = GenericUpdate(date: Date().addingTimeInterval(-60*60*2), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: loweringUpdate1)
        let risingUpdate2 = GenericUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: risingUpdate2)
        let loweringUpdate2 = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: loweringUpdate2)
        XCTAssertEqual(notificationService.postNotificationCalledCount, 2, "Only two notifications should be sent - one for high RHR and and another for lowered RRH")

        XCTAssertTrue(decisionManager.hasPostedAboutRisingNotificationToday(type: .restingHeartRate))
        XCTAssertTrue(decisionManager.hasPostedAboutLoweredNotificationToday)
    }

    func testPosted_multiple_wt() throws {
        let notificationService = MockNotificationService()
        let decisionManager = DecisionManager(notificationService: notificationService, userDefaults: userDefaults)
        let service = RestingHeartRateService(userDefaults: userDefaults, decisionManager: decisionManager)
        userDefaults.set(37.0, forKey: "average_\(UpdateType.wristTemperature)_key")

        let risingUpdate1 = GenericUpdate(date: Date().addingTimeInterval(-60*60*3), value: 39.0, type: .wristTemperature)
        service.handleUpdate(update: risingUpdate1)
        let risingUpdate2 = GenericUpdate(date: Date().addingTimeInterval(-60*60*2), value: 40.0, type: .wristTemperature)
        service.handleUpdate(update: risingUpdate2)
        let risingUpdate3 = GenericUpdate(date: Date().addingTimeInterval(-60*60), value: 41.0, type: .wristTemperature)
        service.handleUpdate(update: risingUpdate3)
        let loweringUpdate1 = GenericUpdate(date: Date(), value: 36.0, type: .wristTemperature)
        service.handleUpdate(update: loweringUpdate1)
        XCTAssertEqual(notificationService.postNotificationCalledCount, 1, "Only one notification should be sent about the wrist temperature")

        XCTAssertTrue(decisionManager.hasPostedAboutRisingNotificationToday(type: .wristTemperature))
    }

    /**
     When the service has a latest saved date and a new update with **earlier** date is handled, the latest handled date should be returned instead
     */
    func testHandleHKUpdate_previousThanStored() throws {
        let now = Date()
        let latestUpdate = GenericUpdate(date: now, value: 50.0, type: .restingHeartRate)
        let data = try XCTUnwrap(JSONEncoder().encode(latestUpdate))
        userDefaults.set(data, forKey: "LatestRestingHeartRateUpdate")

        let decisionManager = DecisionManager(userDefaults: userDefaults)
        let service = RestingHeartRateService(
            userDefaults: userDefaults, decisionManager: decisionManager)
        userDefaults.set(50.0, forKey: "average_\(UpdateType.restingHeartRate)_key")

        // The update has _earlier_ date than the latest handled update.
        let update = GenericUpdate(date: Date().addingTimeInterval(-100), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        let predicate = NSPredicate { service, _ in
            guard let service = service as? DecisionManager else { return false }
            return !service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }
        _ = expectation(for: predicate, evaluatedWith: decisionManager, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    // MARK: - Static
    func testAnalysisText_normal() {
        let service = DecisionManager()
        let normalRestingHeartRateText = "Your resting heart rate is normal."
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 50, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 52, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 51, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 49, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 48, average: 50))
    }

    func testAnalysisText_slightlyAbove() {
        let service = DecisionManager()
        let text = "Your resting heart rate is slightly above your average."
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 60, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 61, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 62, average: 57))
    }

    func testAnalysisText_slightlyBelow() {
        let service = DecisionManager()
        let text = "Your resting heart rate is slightly below your average."
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 54, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 53, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 52, average: 57))
    }

    func testAnalysisText_noticeablyHigher() {
        let service = DecisionManager()
        let string = "Your resting heart rate is noticeably above your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 55, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 56, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 58, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 59, average: 50))
    }

    func testAnalysisText_noticeablyLower() {
        let service = DecisionManager()
        let string = "Your resting heart rate is noticeably below your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 45, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 44, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 43, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 42, average: 50))
    }

    func testAnalysisText_muchHigher() {
        let service = DecisionManager()
        let string = "Your resting heart rate is way above your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 65, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 70, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 90, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 100, average: 50))
    }

    func testAnalysisText_muchLower() {
        let service = DecisionManager()
        let string = "Your resting heart rate is way below your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 40, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 30, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 20, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 1, average: 50))
    }
}

// MARK: - Mock classes

private class MockNotificationService: NotificationService {
    var postNotificationCalledCount = 0
    var postNotificationCalled: Bool {
        return postNotificationCalledCount > 0
    }
    var delay: TimeInterval?

    override func postNotification(title: String, body: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        if let delay = delay {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.postNotificationCalledCount += 1
                completion?(.success(()))
            }
        } else {
            postNotificationCalledCount += 1
            completion?(.success(()))
        }
    }
}
