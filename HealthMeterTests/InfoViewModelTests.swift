//
//  InfoViewModelTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 17.2.2022.
//

import XCTest
@testable import HealthMeter

class InfoViewModelTests: XCTestCase {
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

    func testInitialValues() {
        let mockHeartRateService = MockRestingHeartRateService(userDefaults: userDefaults)
        let viewModel = InfoView.ViewModel(heartRateService: mockHeartRateService)

        XCTAssertNil(viewModel.averageHeartRate)
        XCTAssertNil(viewModel.latestHighRHRNotificationPostDate)
        XCTAssertFalse(viewModel.highRHRIsPostedToday)
    }

    func testNotificationPostDate() {
        let mockHeartRateService = MockRestingHeartRateService()
        let viewModel = InfoView.ViewModel(heartRateService: mockHeartRateService)
        let now = Date()

        mockHeartRateService.mockLatestHighRHRNotificationPostDate = now

        XCTAssertEqual(viewModel.latestHighRHRNotificationPostDate, now)
    }

    func testIsPostedToday() {
        let mockHeartRateService = MockRestingHeartRateService()
        let viewModel = InfoView.ViewModel(heartRateService: mockHeartRateService)

        mockHeartRateService.latestHighRHRNotificationPostDate = Date()

        XCTAssertTrue(viewModel.highRHRIsPostedToday)
    }
}
