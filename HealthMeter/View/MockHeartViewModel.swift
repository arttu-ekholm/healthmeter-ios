//
//  MockHeartViewModel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 16.2.2022.
//

import Foundation

class MockHeartRateService: RestingHeartRateService {
    var average: Double?
    override var averageHeartRate: Double? {
        get { return average }
        set { average = newValue }
    }

    override func queryAverageRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        averageRHRCallback(.success(56.0))
    }

    override func queryLatestRestingHeartRate(completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        completionHandler(.success(RestingHeartRateUpdate(date: .now, value: 61.0)))
    }
}
