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

    func average(type: UpdateType, fromStatsCollection statsCollection: HKStatisticsCollection, startDate: Date, endDate: Date) throws -> Double {
        var avgValues = [Double]()

        let unit: HKUnit
        switch type {
        case .restingHeartRate: unit = HKUnit(from: "count/min")
        case .hrv: unit = HKUnit.secondUnit(with: .milli)
        case .wristTemperature:
            if Locale.current.measurementSystem == .us {
                unit = HKUnit.degreeFahrenheit()
            } else {
                unit = HKUnit.degreeCelsius()
            }
        }

        statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let quantity = statistics.averageQuantity() {
                let value = quantity.doubleValue(for: unit)
                avgValues.append(value)
            }
        }

        guard !avgValues.isEmpty else { throw RestingHeartRateCalculatorError.emptyCollection }

        let avg = avgValues.reduce(0.0, { partialResult, next in
            return partialResult + next
        }) / Double(avgValues.count)
        return avg
    }

    func averageWristTemperature(fromStatsCollection statsCollection: HKStatisticsCollection, startDate: Date, endDate: Date, locale: Locale = .current) throws -> Double {
        var avgValues = [Double]()
        let unit: HKUnit
        if locale.measurementSystem == .us {
            unit = HKUnit.degreeFahrenheit()
        } else {
            unit = HKUnit.degreeCelsius()
        }
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
}
