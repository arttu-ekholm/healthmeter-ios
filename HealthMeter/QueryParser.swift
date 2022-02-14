//
//  QueryParser.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import Foundation
import HealthKit

/**
 Parses HKQuery results to non-HK data
 */
class QueryParser {
    enum QueryParserError: LocalizedError {
        case noLatestRestingHeartRateFound
        case noRestingHeartRateStatisticsFound

        var errorDescription: String? {
            switch self {
            case .noLatestRestingHeartRateFound:
                return "No latest resting heart rate found."
            case .noRestingHeartRateStatisticsFound:
                return "No resting heart rate statistics found."
            }
        }

        var recoverySuggestion: String? { "Get a heart rate." }
        var failureReason: String? { "You don't have a heart or a heart rate." }
    }

    let averageRestingHeartRateCalculator: RestingHeartRateCalculator

    init(averageRestingHeartRateCalculator: RestingHeartRateCalculator = RestingHeartRateCalculator()) {
        self.averageRestingHeartRateCalculator = averageRestingHeartRateCalculator
    }

    func parseLatestRestingHeartRateQueryResults(query: HKSampleQuery,
                                                 results: [HKSample]?,
                                                 error: Error?,
                                                 completion: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let sample = results?.last as? HKQuantitySample else {
            completion(.failure(QueryParserError.noLatestRestingHeartRateFound))
            return
        }

        let heartRateUpdate = RestingHeartRateUpdate(sample: sample)
        completion(.success(heartRateUpdate))
    }

    func parseAverageRestingHeartRateQueryResults(startDate: Date,
                                                  endDate: Date,
                                                  query: HKStatisticsCollectionQuery,
                                                  result: HKStatisticsCollection?,
                                                  error: Error?,
                                                  callback: (Result<Double, Error>) -> Void) {
        if let error = error {
            callback(.failure(error))
            return
        }

        guard let statsCollection = result else {
            callback(.failure(QueryParserError.noRestingHeartRateStatisticsFound))
            return
        }

        do {
            let avgRestingValue = try averageRestingHeartRateCalculator.averageRestingHeartRate(
                fromStatsCollection: statsCollection,
                startDate: startDate,
                endDate: endDate)

            callback(.success(avgRestingValue))
        } catch {
            callback(.failure(error))
        }
    }
}
