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
    var mockLatestRHRResult: Result<GenericUpdate, Error>?
    var mockAverageWTResult: Result<Double, Error>?
    var mockLatestWTResult: Result<GenericUpdate, Error>?
    var mockLatestHighRHRNotificationPostDate: Date?
    var handledDebugUpdate: GenericUpdate?

    override func queryAverageRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        if let result = mockAverageRHRResult {
            averageRHRCallback(result)
        }
    }

    override func queryAverageWristTemperature(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        if let result = mockAverageWTResult {
            averageRHRCallback(result)
        }
    }

    override func queryLatestMeasurement(type: UpdateType, completionHandler: @escaping (Result<GenericUpdate, Error>) -> Void) {
        let result: Result<GenericUpdate, Error>?
        switch type {
        case .restingHeartRate: result = mockLatestRHRResult
        case .wristTemperature: result = mockLatestWTResult
        }

        if let result = result {
            completionHandler(result)
        }
    }
}
