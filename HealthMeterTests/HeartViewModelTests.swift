//
//  HeartViewModelTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 17.2.2022.
//

import XCTest
@testable import HealthMeter

class HeartViewModelTests: XCTestCase {
    func testColors() {
        XCTAssertEqual(model(50.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(49.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(40.0, 50.0).heartColor, .blue)
        XCTAssertEqual(model(51.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(53.0, 50.0).heartColor, .yellow)
        XCTAssertEqual(model(55.0, 50.0).heartColor, .orange)
        XCTAssertEqual(model(60.0, 50.0).heartColor, .orange)
        XCTAssertEqual(model(65.0, 50.0).heartColor, .red)
        XCTAssertEqual(model(100.0, 50.0).heartColor, .red)
    }

    func model(_ latest: Double, _ average: Double) -> HeartView.ViewModel {
        let mockService = MockRestingHeartRateService()
        return HeartView.ViewModel(heartRateService: mockService, shouldReloadContents: false, viewState: .success(RestingHeartRateUpdate(date: Date(), value: latest), average))
    }
}
