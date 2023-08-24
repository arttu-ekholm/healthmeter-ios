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
    var mockAverageHRVResult: Result<Double, Error>?
    var mockLatestWTResult: Result<GenericUpdate, Error>?
    var mockLatestHRVResult: Result<GenericUpdate, Error>?
    var mockLatestHighRHRNotificationPostDate: Date?
    var handledDebugUpdate: GenericUpdate?

    override func queryAverageOfType(_ type: UpdateType, callback: @escaping (Result<Double, Error>) -> Void) {
        let res: Result<Double, Error>?
        switch type {
        case .wristTemperature: res = mockAverageWTResult
        case .restingHeartRate: res = mockAverageRHRResult
        case .hrv: res = mockAverageHRVResult
        }
        if let res {
            callback(res)
        }
    }

    override func queryLatestMeasurement(type: UpdateType, completionHandler: @escaping (Result<GenericUpdate, Error>) -> Void) {
        let result: Result<GenericUpdate, Error>?
        switch type {
        case .restingHeartRate: result = mockLatestRHRResult
        case .wristTemperature: result = mockLatestWTResult
        case .hrv: result = mockLatestHRVResult
        }

        if let result = result {
            completionHandler(result)
        }
    }
}
