//
//  QueryProvider.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import Foundation
import HealthKit

/**
 Provides `HKQuery` objects
 */
class QueryProvider {
    func getLatestRestingHeartRateQuery(resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) -> HKSampleQuery {
        let sampleType = sampleTypeForRestingHeartRate
        let sortDescriptor = sortDescriptorForLatestRestingHeartRate
        let sampleQuery = HKSampleQuery(sampleType: sampleType,
                                        predicate: nil,
                                        limit: 1,
                                        sortDescriptors: [sortDescriptor],
                                        resultsHandler: resultsHandler)
        return sampleQuery
    }

    func getObserverQuery(updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) -> HKObserverQuery {
        let observerQuery = HKObserverQuery(sampleType: sampleTypeForRestingHeartRate, predicate: nil) { query, observerQueryHandler, error in
            updateHandler(query, observerQueryHandler, error)
        }
        return observerQuery
    }

    var sampleTypeForRestingHeartRate: HKQuantityType {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!
    }

    var sortDescriptorForLatestRestingHeartRate: NSSortDescriptor {
        return NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    }
}
