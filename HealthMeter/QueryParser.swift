//
//  QueryParser.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import Foundation
import HealthKit

enum QueryParserError: Error {
    case noResults
}

/**
 Parses HKQuery results to non-HK data
 */
class QueryParser {
    func parseLatestRestingHeartRateQueryResults(query: HKSampleQuery, results: [HKSample]?, error: Error?, completion: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let sample = results?.last as? HKQuantitySample else {
            completion(.failure(QueryParserError.noResults))
            return
        }

        let heartRateUpdate = RestingHeartRateUpdate(sample: sample)
        completion(.success(heartRateUpdate))
    }
}
