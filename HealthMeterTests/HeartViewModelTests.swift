//
//  HeartViewModelTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 14.8.2023.
//

import XCTest
@testable import HealthMeter

class HeartViewModelTests: XCTestCase {
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
}
