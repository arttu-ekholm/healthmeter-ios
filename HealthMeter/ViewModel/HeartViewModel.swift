//
//  HeartViewModel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 22.2.2022.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

struct AllMeasurementsDisplay {
    let string: String
    let color: Color
    let imageName: String
}

extension HeartView {
    class ViewModel: ObservableObject {
        @Published private var restingHeartRateService: RestingHeartRateService
        private let calendar: Calendar
        private let notificationCenter = UNUserNotificationCenter.current()
        private let decisionEngine: DecisionEngine

        var shouldReloadContents: Bool
        @Published var notificationsDenied = false

        @Published var rhr: Result<GenericUpdate, Error>?
        @Published var avg: Double?
        @Published var avgWrist: Double?
        @Published var wristTemperature: Result<GenericUpdate, Error>?
        @Published var hrv: Result<GenericUpdate, Error>?
        @Published var avgHrv: Double?

        @Published private (set) var missingMeasurementsIsDismissed: Bool = false
        @Published private (set) var disabledNotificationsAlertIsDismissed: Bool = false

        private var hrvLevel: HeartRateLevel? {
            guard let avg = avgHrv, avg != 0, case .success(let update) = hrv else { return nil }
            let multiplier = avg / update.value

            return hrvMultiplier(multiplier: multiplier)
        }

        private var rhrLevel: HeartRateLevel? {
            guard let avg = avg, avg != 0, case .success(let update) = rhr else { return nil }
            let multiplier = update.value / avg

            return heartRateLevelForMultiplier(multiplier: multiplier)
        }

        private var wtLevel: HeartRateLevel? {
            guard let avg = avgWrist, avg != 0, case .success(let update) = wristTemperature else { return nil }
            let multiplier = update.value / avg

            return heartRateLevelForMultiplier(multiplier: multiplier)
        }

        var allMeasurementsDisplay: AllMeasurementsDisplay? {
            var measurementsCount = 0
            var sum = 0
            if let hrv = hrvLevel {
                measurementsCount += 1
                sum += hrv.numericValue
            }
            if let rhr = rhrLevel {
                measurementsCount += 1
                sum += rhr.numericValue
            }
            if let wTemp = wtLevel {
                measurementsCount += 1
                sum += wTemp.numericValue
            }

            guard measurementsCount > 0 else {
                return AllMeasurementsDisplay(string: " ", color: .black, imageName: "") // to occupy the vertical space
            }

            let avg = ceil(Double(sum) / Double(measurementsCount)) // round up the result
            let level: HeartRateLevel
            switch avg {
            case 0: level = .normal
            case 1: level = .slightlyElevated
            case 2: level = .noticeablyElevated
            default: level = .wayAboveElevated
            }

            let text = (level == .belowAverage || level == .normal) ? "You're all fine" : "Elevated measurements"
            let imageName = (level == .belowAverage || level == .normal) ? "hand.thumbsup" : "exclamationmark.triangle"
            return AllMeasurementsDisplay(string: text, color: colorForLevel(level), imageName: imageName)
        }

        var shouldShowMissingMeasurements: Bool {
            if missingMeasurementsIsDismissed { return false }
            if case .failure = rhr { return true }
            if case .failure = wristTemperature { return true }
            if case .failure = hrv { return true }
            return false
        }

        func markMissingMeasurementsAsShown(_ state: Bool = true) {
            missingMeasurementsIsDismissed = state
        }

        var shouldShowDisabledNotificationsAlert: Bool {
            if disabledNotificationsAlertIsDismissed { return false }
            return notificationsDenied
        }

        func markDisabledNotificationsAlertAsShown(_ state: Bool = true) {
            disabledNotificationsAlertIsDismissed = state
        }

        var rhrColor: Color? {
            guard let rhrLevel else { return nil }

            return colorForLevel(rhrLevel)
        }

        var wristTemperatureColor: Color? {
            guard let wtLevel else { return nil }

            return colorForLevel(wtLevel)
        }

        var hrvColor: Color? {
            guard let hrvLevel else { return nil }

            return colorForLevel(hrvLevel)
        }

        var rhrDisabled: Bool {
            if case .failure = rhr {
                return true
            } else {
                return false
            }
        }

        var wristTemperatureDisabled: Bool {
            if case .failure = wristTemperature {
                return true
            } else {
                return false
            }
        }

        var hrvDisabled: Bool {
            if case .failure = hrv {
                return true
            } else {
                return false
            }
        }

        var wristTemperatureStatusDisplayText: String {
            switch wristTemperature {
            case .success(let update):
                guard let avgWrist else { return "" }
                let diff = update.value - avgWrist
                switch diff {
                case 0.5...1.0: return "elevated"
                case _ where diff > 1.0: return "high"
                default: return "normal"
                }
            case .failure: return ""
            case nil: return ""
            }
        }

        var hrvStatusDisplayText: String {
            guard let avgHrv = avgHrv, avgHrv != 0, case .success(let update) = hrv else { return "" }
            let multiplier = avgHrv / update.value
            let level = hrvMultiplier(multiplier: multiplier)
            return adjectiveForLevel(level: level, type: .hrv)
        }

        var wristTemperatureCurrentDisplayText: String {
            if case .success(let update) = wristTemperature {
                return String(format: "%.1f", update.value)
            } else {
                return "–"
            }
        }

        var hrvCurrentDisplayText: String {
            if case .success(let update) = hrv {
                return String(format: "%.0f", update.value)
            } else {
                return "–"
            }
        }

        var wtAverageDisplayText: String {
            switch wristTemperature {
            case .success(let update):
                guard let avgWrist else { return "–" }
                let diff = abs(update.value - avgWrist)
                return String(format: "%.1f", diff)
            case .failure: return "–"
            case nil: return "–"
            }
        }

        var hrvAverageDisplayText: String {
            switch hrv {
            case .success(let update):
                guard let avgHrv else { return "–" }
                let diff = abs(update.value - avgHrv)
                return String(format: "%.0f", diff)
            case .failure: return "–"
            case nil: return "–"
            }

        }

        var wristTemperatureDiffDisplayText: String {
            switch wristTemperature {
            case .success(let update):
                guard let avgWrist else { return "" }
                let aboveBelow = update.value > avgWrist ? "above" : "below"
                return "\(aboveBelow) average"
            case .failure: return "–"
            case nil: return "–"
            }
        }

        var hrvDiffDisplayText: String {
            switch hrv {
            case .success(let update):
                guard let avgHrv else { return "" }
                let aboveBelow = update.value > avgHrv ? "above" : "below"
                return "\(aboveBelow) average"
            case .failure: return "–"
            case nil: return "–"
            }
        }

        var rhrStatusDisplayText: String {
            guard let avg = avg, avg != 0, case .success(let update) = rhr else { return "" }
            let multiplier = update.value / avg
            let level = heartRateLevelForMultiplier(multiplier: multiplier)
            return adjectiveForLevel(level: level, type: .restingHeartRate)
        }

        private func adjectiveForLevel(level: HeartRateLevel, type: UpdateType) -> String {
            switch type {
            case .restingHeartRate, .wristTemperature:
                switch level {
                case .belowAverage, .normal: return "normal"
                case .slightlyElevated, .noticeablyElevated: return "elevated"
                case .wayAboveElevated: return "high"
                }
            case .hrv:
                switch level {
                case .belowAverage: return "great"
                case .normal: return "normal"
                case .slightlyElevated, .noticeablyElevated: return "lower"
                case .wayAboveElevated: return "low"
                }
            }
        }

        var rhrAverageDisplayText: String {
            guard let avg = avg else { return "–" }
            return String(format: "%.0f", avg)
        }

        var rhrUnits: String {
            "bpm"
        }
        var wtUnits: String {
            "°\(Locale.current.temperatureSymbol)"
        }

        var hrvUnits: String {
            return "ms"
        }

        var restingHeartRateDisplayText: String {
            switch rhr {
            case .success(let update):
                guard avg != nil else { return "" }
                return String(format: "%.0f", update.value)
            case .failure: return ""
            case nil: return ""
            }
        }

        private var cancellables = Set<AnyCancellable>()

        init(
            heartRateService: RestingHeartRateService = RestingHeartRateService.shared,
            calendar: Calendar = Calendar.current,
            shouldReloadContents: Bool = true,
            decisionEngine: DecisionEngine = DecisionEngineImplementation()) {
                self.restingHeartRateService = heartRateService
                self.calendar = calendar
                self.shouldReloadContents = shouldReloadContents
                self.decisionEngine = decisionEngine

                restingHeartRateService.$averageWristTemperaturePublished
                    .sink { [weak self] update in
                        DispatchQueue.main.async {
                            self?.avgWrist = update
                        }
                    }
                    .store(in: &cancellables)

                restingHeartRateService.$latestWristTemperatureUpdate
                    .sink(receiveValue: { [weak self] newValue in
                        DispatchQueue.main.async {
                            self?.wristTemperature = newValue
                        }
                    })
                    .store(in: &cancellables)

                restingHeartRateService.$latestRestingHeartRateUpdate
                    .sink(receiveValue: { [weak self] newValue in
                        DispatchQueue.main.async {
                            self?.rhr = newValue
                        }
                    })
                    .store(in: &cancellables)

                restingHeartRateService.$averageHeartRatePublished
                    .sink { [weak self] update in
                        DispatchQueue.main.async {
                            self?.avg = update
                        }
                    }
                    .store(in: &cancellables)

                restingHeartRateService.$latestHRVUpdate
                    .sink(receiveValue: { [weak self] newValue in
                        DispatchQueue.main.async {
                            self?.hrv = newValue
                        }
                    })
                    .store(in: &cancellables)

                restingHeartRateService.$averageHRVPublished
                    .sink { [weak self] update in
                        DispatchQueue.main.async {
                            self?.avgHrv = update
                        }
                    }
                    .store(in: &cancellables)
            }

        func averageDisplayTextForType(_ type: UpdateType) -> String {
            let res: Double?
            switch type {
            case .wristTemperature: res = avgWrist
            case .restingHeartRate: res = avg
            case .hrv: res = avgHrv
            }

            return res != nil ? "2 month average" : ""

        }

        func requestLatestMeasurementsOfType(type: UpdateType) {
            restingHeartRateService.queryAverageOfType(type, callback: { _ in
                self.restingHeartRateService.queryLatestMeasurement(type: type) { _ in }
            })
        }

        func requestLatestMeasurementsOfAllTypes() {
            for type in UpdateType.allCases {
                restingHeartRateService.queryAverageOfType(type, callback: { _ in
                    self.restingHeartRateService.queryLatestMeasurement(type: type) { _ in }
                })
            }
        }

        func checkNotificationStatus() async {
            let settings = await notificationCenter.notificationSettings()
            DispatchQueue.main.async {
                if case .denied = settings.authorizationStatus {
                    self.notificationsDenied = true
                } else {
                    self.notificationsDenied = false
                }
            }
        }

        // MARK: - URLs
        var healthAppURL: URL {
            return URL(string: "x-apple-health://")!
        }

        var settingsAppURL: URL {
            return URL(string: UIApplication.openSettingsURLString)!
        }
    }
}
