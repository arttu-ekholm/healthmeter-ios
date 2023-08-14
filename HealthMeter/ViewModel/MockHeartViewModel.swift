//
//  MockHeartViewModel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 16.2.2022.
//

import SwiftUI
import HealthKit

class DummyHeartRateService: RestingHeartRateService {
    var average: Double?
    override var averageHeartRate: Double? {
        get { return average }
        set { average = newValue }
    }

    override init(userDefaults: UserDefaults = UserDefaults.standard, calendar: Calendar = Calendar.current, healthStore: HKHealthStore = HKHealthStore(), queryProvider: QueryProvider = QueryProvider(), queryParser: QueryParser = QueryParser(), decisionManager: DecisionManager = DecisionManager(decisionEngine: DecisionEngineImplementation())) {
        super.init(userDefaults: userDefaults, calendar: calendar, healthStore: healthStore, queryProvider: queryProvider, queryParser: queryParser)

        averageHeartRate = 57.0
    }

    override func queryAverageRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        averageRHRCallback(.success(57.0))
    }

    /*
    override func queryLatestRestingHeartRate(completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        completionHandler(.success(RestingHeartRateUpdate(date: .now.addingTimeInterval(-60*60), value: 58.0)))
    }*/

    /*
    override func queryLatestMeasurement(type: UpdateType, completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        completionHandler(.success(RestingHeartRateUpdate(date: .now.addingTimeInterval(-60*60), value: 58.0)))
    }*/
    override func queryLatestMeasurement(type: UpdateType, completionHandler: @escaping (Result<GenericUpdate, Error>) -> Void) {
        completionHandler(.success(GenericUpdate(date: .now.addingTimeInterval(-60*60), value: 58.0, type: .restingHeartRate)))
    }

    override func fetchRestingHeartRateHistory(startDate: Date, completion: @escaping (Result<RestingHeartRateHistory, Error>) -> Void) {
        let history = RestingHeartRateHistory(histogramItems: [
            RestingHeartRateHistogramItem(item: 50, count: 1),
            RestingHeartRateHistogramItem(item: 51, count: 0),
            RestingHeartRateHistogramItem(item: 52, count: 3),
            RestingHeartRateHistogramItem(item: 53, count: 2),
            RestingHeartRateHistogramItem(item: 54, count: 4),
            RestingHeartRateHistogramItem(item: 55, count: 6),
            RestingHeartRateHistogramItem(item: 56, count: 8),
            RestingHeartRateHistogramItem(item: 57, count: 12),
            RestingHeartRateHistogramItem(item: 58, count: 5),
            RestingHeartRateHistogramItem(item: 59, count: 4),
            RestingHeartRateHistogramItem(item: 60, count: 3),
            RestingHeartRateHistogramItem(item: 61, count: 1),
            RestingHeartRateHistogramItem(item: 62, count: 0),
            RestingHeartRateHistogramItem(item: 63, count: 1),
            RestingHeartRateHistogramItem(item: 64, count: 3),
            RestingHeartRateHistogramItem(item: 65, count: 1)

        ])
        completion(.success(history))
    }
}
