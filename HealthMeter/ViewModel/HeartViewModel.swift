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

        @Published private (set) var missingMeasurementsIsDismissed: Bool = false
        @Published private (set) var disabledNotificationsAlertIsDismissed: Bool = false

        var allMeasurementsDisplay: AllMeasurementsDisplay? {
            var elevatedRHR: Bool?
            var elevatedWristTemperature: Bool?
            var level: HeartRateLevel?
            let text: String
            let imageName: String
            if let avg = avg, avg != 0, case .success(let update) = rhr {
                let multiplier = update.value / avg
                level = heartRateLevelForMultiplier(multiplier: multiplier)
                elevatedRHR = level == .noticeablyElevated || level == .slightlyElevated || level == .wayAboveElevated
            }
            if let avg = avgWrist, avg != 0, case .success(let update) = wristTemperature {
                elevatedWristTemperature = decisionEngine.wristTemperatureIsAboveAverage(update: update, average: avg)
            }
            if elevatedRHR == nil && elevatedWristTemperature == nil {
                return AllMeasurementsDisplay(string: " ", color: .secondary, imageName: "exclamationmark.triangle") // to occupy the vertical space
            } else if elevatedRHR ?? false && elevatedWristTemperature ?? false {
                return AllMeasurementsDisplay(string: "All fine", color: .green, imageName: "checkmark")
            } else {
                var color: Color
                if elevatedWristTemperature ?? false {
                    color = .red
                    text = "Elevated measurements"
                    imageName = "exclamationmark.triangle"
                } else if let level = level {
                    color = colorForLevel(level)
                    text = (level == .belowAverage || level == .normal) ? "You're all fine" : "Elevated measurements"
                    imageName = (level == .belowAverage || level == .normal) ? "hand.thumbsup" : "exclamationmark.triangle"
                } else {
                    return AllMeasurementsDisplay(string: " ", color: .black, imageName: "") // to occupy the vertical space
                }

                return AllMeasurementsDisplay(string: text, color: color, imageName: imageName)
            }
        }

        var shouldShowMissingMeasurements: Bool {
            if missingMeasurementsIsDismissed { return false }
            if case .failure = rhr { return true }
            if case .failure = wristTemperature { return true }
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
            guard let avg = avg, avg != 0, case .success(let update) = rhr else { return nil }
            let multiplier = update.value / avg

            let level = heartRateLevelForMultiplier(multiplier: multiplier)
            return colorForLevel(level)
        }

        var wristTemperatureColor: Color? {
            guard let avg = avgWrist, avg != 0, case .success(let update) = wristTemperature else { return nil }
            let multiplier = update.value / avg

            let level = heartRateLevelForMultiplier(multiplier: multiplier)
            return colorForLevel(level)
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

        var wristTemperatureCurrentDisplayText: String {
            if case .success(let update) = wristTemperature {
                return String(format: "%.1f", update.value)
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

        var rhrStatusDisplayText: String {
            guard let avg = avg, avg != 0, case .success(let update) = rhr else { return "" }
            let multiplier = update.value / avg
            let level = heartRateLevelForMultiplier(multiplier: multiplier)
            return adjectiveForLevel(level: level)
        }

        private func adjectiveForLevel(level: HeartRateLevel) -> String {
            switch level {
            case .belowAverage, .normal: return "normal"
            case .slightlyElevated: return "slightly elevated"
            case .noticeablyElevated: return "elevated"
            case .wayAboveElevated: return "high"
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
            }

        func requestLatestRestingHeartRate() {
            restingHeartRateService.queryAverageRestingHeartRate { _ in
                self.restingHeartRateService.queryLatestMeasurement(type: .restingHeartRate) { _ in }
            }
        }

        func requestLatestWristTemperature() {
            restingHeartRateService.queryAverageWristTemperature { _ in
                self.restingHeartRateService.queryLatestMeasurement(type: .wristTemperature) { _ in }
            }
        }

        func checkNotificationStatus() {
            notificationCenter.getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if case .denied = settings.authorizationStatus {
                        self.notificationsDenied = true
                    } else {
                        self.notificationsDenied = false
                    }
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
