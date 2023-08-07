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
                                                 type: UpdateType,
                                                 completion: @escaping (Result<GenericUpdate, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let sample = results?.last as? HKQuantitySample else {
            completion(.failure(QueryParserError.noLatestRestingHeartRateFound))
            return
        }

        let heartRateUpdate = GenericUpdate(sample: sample, type: type)
        completion(.success(heartRateUpdate))
    }

    func parseLatestWristTemperatureResults(query: HKSampleQuery,
                                            results: [HKSample]?,
                                            error: Error?,
                                            completion: @escaping (Result<GenericUpdate, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let sample = results?.last as? HKQuantitySample else {
            completion(.failure(QueryParserError.noLatestRestingHeartRateFound)) // TODO: other errors
            return
        }

        let update = GenericUpdate(sample: sample, type: .wristTemperature)
        completion(.success(update))
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

    func parseAverageWristTemperatureQueryResults(startDate: Date,
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
            callback(.failure(QueryParserError.noRestingHeartRateStatisticsFound)) // TODO:
            return
        }

        do {
            let avgRestingValue = try averageRestingHeartRateCalculator.averageWristTemperature(
                fromStatsCollection: statsCollection,
                startDate: startDate,
                endDate: endDate)

            callback(.success(avgRestingValue))
        } catch {
            callback(.failure(error))
        }
    }

    func parseRestingHeartRateHistogram(startDate: Date,
                                        endDate: Date,
                                        query: HKStatisticsCollectionQuery,
                                        result: HKStatisticsCollection?,
                                        error: Error?,
                                        callback: (Result<RestingHeartRateHistory, Error>) -> Void) {

        if let error = error {
            callback(.failure(error))
            return
        }

        guard let statsCollection = result else {
            callback(.failure(QueryParserError.noRestingHeartRateStatisticsFound))
            return
        }

        var results: [Int: Int] = [:]

        let unit = HKUnit(from: "count/min")

        statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let quantity = statistics.averageQuantity() {
                let value = Int(quantity.doubleValue(for: unit))

                if results[value] == nil {
                    results[value] = 1
                } else {
                    results[value] = results[value]! + 1
                }
            }
        }
        let lowestKey = results.keys.min()!
        let highestKey = results.keys.max()!

        // Add the missing numbers in between
        for key in lowestKey...highestKey where results[key] == nil {
            results[key] = 0
        }

        let histogramItems = results.map({ (key: Int, value: Int) in
            RestingHeartRateHistogramItem(item: key, count: value)
        }).sorted(by: { $0.item < $1.item })

        let histogram = RestingHeartRateHistory(histogramItems: histogramItems)
        callback(.success(histogram))
    }
}
