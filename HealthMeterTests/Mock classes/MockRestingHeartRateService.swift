//
//  MockRestingHeartRateService.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 17.2.2022.
//

import Foundation
@testable import HealthMeter

class MockRestingHeartRateService: RestingHeartRateService {
    var mockAverageRHRResult: Result<Double, Error>?
    var mockLatestRHRResult: Result<RestingHeartRateUpdate, Error>?
    var mockLatestHighRHRNotificationPostDate: Date?
    var handledDebugUpdate: RestingHeartRateUpdate?

    override func queryAverageRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        if let result = mockAverageRHRResult {
            averageRHRCallback(result)
        }
    }

    override func queryLatestRestingHeartRate(completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        if let result = mockLatestRHRResult {
            completionHandler(result)
        }
    }

    override var latestHighRHRNotificationPostDate: Date? {
        get {
            return mockLatestHighRHRNotificationPostDate
        } set {
            mockLatestHighRHRNotificationPostDate = newValue
        }
    }
}
