//
//  NotificationCenterTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 15.2.2022.
//

import XCTest
@testable import HealthMeter

class NotificationCenterTests: XCTestCase {

    // MARK: - Posting on different application states

    func testPostingNotification_activeApp() {
        let mockApplicationProxy = MockApplicationProxy()
        let mockNotificationServiceProxy = MockNotificationServiceProxy()
        let service = NotificationService(
            applicationProxy: mockApplicationProxy,
            notificationCenterProxy: mockNotificationServiceProxy)

        let expectation = expectation(description: "Posting notification when the app is active will result in an error.")

        service.postNotification(title: "Test", body: "Test") { result in
            switch result {
            case .failure:
                expectation.fulfill()
            default:
                XCTFail("Posting a notification should result in an error.")
            }
        }
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testPostingNotification_backgroundApp() {
        let mockApplicationProxy = MockApplicationProxy()
        let mockNotificationServiceProxy = MockNotificationServiceProxy()
        let service = NotificationService(
            applicationProxy: mockApplicationProxy,
            notificationCenterProxy: mockNotificationServiceProxy)
        mockApplicationProxy.mockApplicationState = .background

        let expectation = expectation(description: "Posting notification when the app is in the backround should be successful.")

        service.postNotification(title: "Test", body: "Test") { result in
            switch result {
            case .success:
                expectation.fulfill()
            default:
                XCTFail("Posting a notification should be succcessful")
            }
        }
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testPostingNotification_inactiveApp() {
        let mockApplicationProxy = MockApplicationProxy()
        let mockNotificationServiceProxy = MockNotificationServiceProxy()
        let service = NotificationService(
            applicationProxy: mockApplicationProxy,
            notificationCenterProxy: mockNotificationServiceProxy)
        mockApplicationProxy.mockApplicationState = .inactive

        let expectation = expectation(description: "Posting notification when the app is inactive should be successful.")

        service.postNotification(title: "Test", body: "Test") { result in
            switch result {
            case .success:
                expectation.fulfill()
            default:
                XCTFail("Posting a notification should be succcessful")
            }
        }
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testPosting_failedNotification() {
        let mockApplicationProxy = MockApplicationProxy()
        let mockNotificationServiceProxy = MockNotificationServiceProxy()
        let service = NotificationService(
            applicationProxy: mockApplicationProxy,
            notificationCenterProxy: mockNotificationServiceProxy)
        mockApplicationProxy.mockApplicationState = .inactive
        mockNotificationServiceProxy.mockerror = NotificationServiceTestsError.testError

        let expectation = expectation(description: "Posting notification when the app is inactive should be successful.")

        service.postNotification(title: "Test", body: "Test") { result in
            switch result {
            case .success:
                XCTFail("Posting a notification should fail NotificationServiceTestsError.testError")
            case .failure(let error):
                if error is NotificationServiceTestsError {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 2.0, handler: .none)
    }
}

// MARK: - Mock classes

private class MockApplicationProxy: ApplicationProxy {
    var mockApplicationState: UIApplication.State = .active
    override var applicationState: UIApplication.State {
        return mockApplicationState
    }
}

private class MockNotificationServiceProxy: NotificationCenterProxy {
    var mockerror: Error?

    override func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        completionHandler?(mockerror)
    }
}

enum NotificationServiceTestsError: Error {
    case testError
}
