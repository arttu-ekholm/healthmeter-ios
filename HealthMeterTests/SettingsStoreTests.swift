//
//  SettingsStoreTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 17.2.2022.
//

import XCTest
@testable import HealthMeter

class HealthMeterTests: XCTestCase {
    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        userDefaults = UserDefaults(suiteName: #file)
        userDefaults?.removePersistentDomain(forName: #file)
    }

    override func tearDown() {
        super.tearDown()

        userDefaults.removePersistentDomain(forName: #file)
    }

    func testTutorialShownKey() {
        let settingsStore = SettingsStore(userDefaults: userDefaults)
        XCTAssertFalse(settingsStore.tutorialShown)
        settingsStore.tutorialShown = true
        XCTAssertTrue(settingsStore.tutorialShown)
    }
}
