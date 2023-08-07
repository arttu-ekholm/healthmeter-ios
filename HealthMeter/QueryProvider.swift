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
    private let calendar: Calendar

    init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /*
    func getLatestRestingHeartRateQuery(resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) -> HKSampleQuery {
        let sampleType = sampleTypeForRestingHeartRate
        let sortDescriptor = sortDescriptor
        let sampleQuery = HKSampleQuery(sampleType: sampleType,
                                        predicate: nil,
                                        limit: 1,
                                        sortDescriptors: [sortDescriptor],
                                        resultsHandler: resultsHandler)
        return sampleQuery
    }
     */

    func getLatestWristTemperature(resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) -> HKSampleQuery {
        let sampleType = sampleTypeForWristTemperature
        let sortDescriptor = sortDescriptor
        let sampleQuery = HKSampleQuery(sampleType: sampleType,
                                        predicate: nil,
                                        limit: 1,
                                        sortDescriptors: [sortDescriptor],
                                        resultsHandler: resultsHandler)
        return sampleQuery
    }

    func getLatestMeasurement(for type: UpdateType, resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) -> HKSampleQuery {
        let sampleType = sampleTypeFor(type)
        let sortDescriptor = sortDescriptor
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

    func getAverageRestingHeartRateQuery(queryStartDate: Date) -> HKStatisticsCollectionQuery {
        let quantityType = sampleTypeForRestingHeartRate

        let interval = NSDateComponents()
        interval.month = 6

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: queryStartDate,
            intervalComponents: interval as DateComponents
        )

        return query
    }

    func getAverageWristTemperatureQuery(queryStartDate: Date) -> HKStatisticsCollectionQuery {
        let quantityType = sampleTypeForWristTemperature

        let interval = NSDateComponents()
        interval.month = 6

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: queryStartDate,
            intervalComponents: interval as DateComponents
        )

        return query
    }

    func getRestingHeartRateHistogramQuery() -> HKStatisticsCollectionQuery {
        let quantityType = sampleTypeForRestingHeartRate

        let interval = NSDateComponents()
        interval.day = 1

        let anchorDate = calendar.date(bySettingHour: 0, minute: 0, second: 1, of: Date())

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: anchorDate!,
            intervalComponents: interval as DateComponents
        )

        return query
    }

    var sampleTypeForRestingHeartRate: HKQuantityType {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!
    }

    var sortDescriptor: NSSortDescriptor {
        return NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    }

    var sampleTypeForWristTemperature: HKQuantityType {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.appleSleepingWristTemperature)!
    }

    func sampleTypeFor(_ type: UpdateType) -> HKQuantityType {
        switch type {
        case .wristTemperature: return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.appleSleepingWristTemperature)!
        case .restingHeartRate: return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!
        }
    }
}
