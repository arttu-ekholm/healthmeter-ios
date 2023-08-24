//
//  DecisionEngine.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 24.8.2023.
//

import Foundation

/**
    Collection of logical functions that can be shared between the notification decisions and the view model logic. Generally, the fine-tuning of the app should happen by changing the internals of the `DecisionEngine` implementation.
 */
protocol DecisionEngine {
    func wristTemperatureIsAboveAverage(update: GenericUpdate, average: Double) -> Bool
    func heartRateIsAboveAverage(update: GenericUpdate, average: Double) -> Bool
    func hrvIsBelowAverage(update: GenericUpdate, average: Double) -> Bool
}

class DecisionEngineImplementation: DecisionEngine {
    let locale: Locale

    init (locale: Locale = .current) {
        self.locale = locale
    }

    func wristTemperatureIsAboveAverage(update: GenericUpdate, average: Double) -> Bool {
        guard update.type == .wristTemperature else { return false }

        if locale.measurementSystem == .us {
            return update.value - average > 1.8
        } else {
            return update.value - average > 1.0
        }
    }

    /**
     - returns true if the heart rate is above the average
     */
    func heartRateIsAboveAverage(update: GenericUpdate, average: Double) -> Bool {
        guard update.type == .restingHeartRate else { return false }

        return update.value / average > threshold
    }

    func hrvIsBelowAverage(update: GenericUpdate, average: Double) -> Bool {
        guard update.type == .hrv else { return false }

        return update.value / average < 0.8
    }

    // If the latest update is this much above the avg. RHR, the notification will be triggered.
    var threshold: Double {
        return 1 + thresholdMultiplier
    }

    /**
     RHR values above x times `thresholdMultiplier`are considered above average.
     */
    var thresholdMultiplier: Double {
        return 0.05
    }
}
