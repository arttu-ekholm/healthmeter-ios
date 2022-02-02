//
//  RestingHeartRateCalculator.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import Foundation
import HealthKit

class RestingHeartRateCalculator {
    func averageRestingHeartRate(fromStatsCollection statsCollection: HKStatisticsCollection, startDate: Date, endDate: Date) -> Double {
        var avgValues = [Double]()
        statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
            if let quantity = statistics.averageQuantity() {
                let value = quantity.doubleValue(for: HKUnit(from: "count/min"))
                avgValues.append(value)
            }
        }

        guard !avgValues.isEmpty else { return 0.0 }

        let avgRestingValue = avgValues.reduce(0.0, { partialResult, next in
            return partialResult + next
        }) / Double(avgValues.count)
        return avgRestingValue
    }
}
