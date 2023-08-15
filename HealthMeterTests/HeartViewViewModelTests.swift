//
//  HeartViewViewModelTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 15.2.2022.
//

import XCTest
@testable import HealthMeter

class HeartViewViewModelTests: XCTestCase {
}

private enum HeartViewViewModelTestsError: Error {
    case testError
}

private func model(_ latest: Double, _ average: Double, _ date: Date = Date()) -> HeartView.ViewModel {
    let mockService = MockRestingHeartRateService()
    return HeartView.ViewModel(heartRateService: mockService, shouldReloadContents: false, viewState: .success(GenericUpdate(date: date, value: latest, type: .restingHeartRate), average))
}
