//
//  RestingHeartRateCalculator.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import Foundation
import HealthKit

/**
 Calcluates average RHR from a collection of HKStatistics
 */
class RestingHeartRateCalculator {
    enum RestingHeartRateCalculatorError: Error {
        case emptyCollection
    }

    func averageRestingHeartRate(fromStatsCollection statsCollection: HKStatisticsCollection, startDate: Date, endDate: Date) throws -> Double {
        var avgValues = [Double]()
        let unit = HKUnit(from: "count/min")
        statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let quantity = statistics.averageQuantity() {
                let value = quantity.doubleValue(for: unit)
                avgValues.append(value)
            }
        }

        guard !avgValues.isEmpty else { throw RestingHeartRateCalculatorError.emptyCollection }

        let avgRestingValue = avgValues.reduce(0.0, { partialResult, next in
            return partialResult + next
        }) / Double(avgValues.count)
        return avgRestingValue
    }

    func averageWristTemperature(fromStatsCollection statsCollection: HKStatisticsCollection, startDate: Date, endDate: Date) throws -> Double {
        var avgValues = [Double]()
        let unit = HKUnit(from: "degC")
        statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let quantity = statistics.averageQuantity() {
                let value = quantity.doubleValue(for: unit)
                avgValues.append(value)
            }
        }

        guard !avgValues.isEmpty else { throw RestingHeartRateCalculatorError.emptyCollection } // TODO:

        let avgRestingValue = avgValues.reduce(0.0, { partialResult, next in
            return partialResult + next
        }) / Double(avgValues.count)
        return avgRestingValue
    }
}
