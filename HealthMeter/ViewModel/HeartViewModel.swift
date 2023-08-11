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

extension HeartView {
    // swiftlint:disable type_body_length
    class ViewModel: ObservableObject {
        @Published private var restingHeartRateService: RestingHeartRateService
        private let calendar: Calendar
        private let notificationCenter = UNUserNotificationCenter.current()

        var shouldReloadContents: Bool
        @Published var viewState: ViewState<GenericUpdate, Double>
        @Published var notificationsDenied = false
        @Published var animationAmount: CGFloat = 1
        @Published var histogram: RestingHeartRateHistory?

        @Published var rhr: Result<GenericUpdate, Error>?
        @Published var avg: Double?
        @Published var avgWrist: Double?
        @Published var wristTemperature: Result<GenericUpdate, Error>?

        @Published private (set) var missingMeasurementsIsDismissed: Bool = false
        var shouldShowMissingMeasurements: Bool {
            if missingMeasurementsIsDismissed { return false }
            if case .failure = rhr { return true }
            if case .failure = wristTemperature { return true }
            return false
        }

        func markMissingMeasurementsAsShown(_ state: Bool = true) {
            missingMeasurementsIsDismissed = state
        }

        var rhrColor: Color? {
            guard let avg = avg, avg != 0, case .success(let update) = rhr else { return nil }
            let multiplier = update.value / avg

            let level = restingHeartRateService.heartRateLevelForMultiplier(multiplier: multiplier)
            return colorForLevel(level)
        }

        var wristTemperatureColor: Color? {
            guard let avg = avgWrist, avg != 0, case .success(let update) = wristTemperature else { return nil }
            let multiplier = update.value / avg

            let level = restingHeartRateService.heartRateLevelForMultiplier(multiplier: multiplier)
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
                return String(format: "%.1f\(Locale.current.temperatureSymbol)", update.value)
            } else {
                return ""
            }
        }

        var wristTemperatureDiffDisplayText: String {
            switch wristTemperature {
            case .success(let update):
                guard let avgWrist else { return "" }
                let aboveBelow = update.value > avgWrist ? "above" : "below"
                let diff = abs(update.value - avgWrist)
                return String(format: "%.1f\(Locale.current.temperatureSymbol) \(aboveBelow) average", diff)
            case .failure: return ""
            case nil: return ""
            }
        }

        var rhrStatusDisplayText: String {
            guard let avg = avg, avg != 0, case .success(let update) = rhr else { return "" }
            let multiplier = update.value / avg
            let level = restingHeartRateService.heartRateLevelForMultiplier(multiplier: multiplier)
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
            guard let avg = avg else { return "" }
            return String(format: "%.0f bpm", avg)
        }
        var restingHeartRateDisplayText: String {
            switch rhr {
            case .success(let update):
                guard avg != nil else { return "" }
                return String(format: "%.0f bpm", update.value)
            case .failure: return ""
            case nil: return ""
            }
        }

        var wristTemperatureDisplayText: String {
            switch wristTemperature {
            case .success(let update):
                guard avgWrist != nil else { return "" }
                return String(format: "%.1f\(Locale.current.temperatureSymbol)", update.value)
            case .failure: return ""
            case nil: return ""
            }
        }

        private var cancellables = Set<AnyCancellable>()

        init(
            heartRateService: RestingHeartRateService = RestingHeartRateService.shared,
            calendar: Calendar = Calendar.current,
            shouldReloadContents: Bool = true,
            viewState: ViewState<GenericUpdate, Double> = .loading) {
                self.restingHeartRateService = heartRateService
                self.calendar = calendar
                self.shouldReloadContents = shouldReloadContents
                self.viewState = viewState
                self.rhr = heartRateService.latestRestingHeartRateUpdate
                self.avg = heartRateService.averageHeartRatePublished
                self.wristTemperature = heartRateService.latestWristTemperatureUpdate
                restingHeartRateService.$averageWristTemperaturePublished.sink { [weak self] update in
                    self?.avgWrist = update
                }
                .store(in: &cancellables)
                restingHeartRateService.$averageHeartRatePublished.sink { [weak self] update in
                    DispatchQueue.main.async {
                        self?.avg = update
                    }
                }
                .store(in: &cancellables)
            }

        var heartColor: Color {
            switch viewState {
            case .success(let latest, let average):
                guard calendar.isDateInToday(latest.date) else {
                    return .gray
                }

                let current = latest.value
                let multiplier = current / average - 1.0
                if multiplier >= 0 {
                    if multiplier > 0.2 {
                        return .red
                    } else if multiplier > 0.1 {
                        return .orange
                    } else if multiplier > 0.05 {
                        return .yellow
                    } else {
                        return .green
                    }
                } else {
                    if multiplier < -0.05 {
                        return .green // over -5 %
                    } else {
                        return .green // within +- 5 %
                    }
                }
            default: return .green
            }
        }

        var heartImageName: String {
            switch viewState {

            case .success(let latest, let average):
                guard calendar.isDateInToday(latest.date) else {
                    return "heart.text.square"
                }

                let current = latest.value
                let multiplier = current / average - 1.0
                if multiplier >= 0 {
                    if multiplier > 0.05 {
                        return "arrow.up.heart.fill"
                    } else {
                        return "heart.fill"
                    }
                } else {
                    return "heart.fill"
                }
            default:
                return "heart.fill"
            }
        }

        func requestLatestRestingHeartRate() {
            restingHeartRateService.queryAverageRestingHeartRate { averageResult in

                self.restingHeartRateService.queryLatestMeasurement(type: .restingHeartRate) { latestResult in
                    DispatchQueue.main.async {
                        if case .success(let update) = latestResult, case .success(let average) = averageResult {
                            self.viewState = .success(update, average)
                        } else if case .failure = averageResult, case .failure = latestResult {
                            self.viewState = .error(HeartViewError.missingBoth)
                        } else if case .failure = averageResult {
                            self.viewState = .error(HeartViewError.missingLatestHeartRate)
                        } else if case .failure = latestResult {
                            self.viewState = .error(HeartViewError.missingLatestHeartRate)
                        }
                    }
                }
            }
        }

        func requestLatestWristTemperature() {
            restingHeartRateService.queryAverageWristTemperature { _ in
                self.restingHeartRateService.queryLatestMeasurement(type: .wristTemperature) { _ in }
            }
        }

        func getLatestRestingHeartRateDisplayString(update: GenericUpdate) -> String {
            if calendar.isDateInToday(update.date) {
                return "Your resting heart rate today is"
            } else if calendar.isDateInYesterday(update.date) {
                return "Yesterday, your resting heart rate was"
            } else { // past
                return "Earlier, your resting heart rate was"
            }
        }

        func heartRateAnalysisText(update: GenericUpdate, average: Double) -> String {
            if calendar.isDateInToday(update.date) {
                return restingHeartRateService.heartRateAnalysisText(current: update.value, average: average)
            } else {
                return "Today's resting heart rate hasn't been calculated yet."
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

        var restingHeartRateIsUpdatedToday: Bool {
            guard case .success(let update, _) = viewState else {
                return false
            }

            return calendar.isDateInToday(update.date)
        }

        var heartImageShouldAnimate: Bool {
            if case .success(let latest, _) = viewState, calendar.isDateInToday(latest.date) {
                return true
            } else {
                return false
            }
        }

        // MARK: - URLs
        var healthAppURL: URL {
            return URL(string: "x-apple-health://")!
        }

        var settingsAppURL: URL {
            return URL(string: UIApplication.openSettingsURLString)!
        }

        // MARK: - RHR histogram
        func fetchHistogramData() {
            restingHeartRateService.fetchRestingHeartRateHistory(startDate: Date().addingTimeInterval(-60*60*24*30*6)) { result in
                if case .success(let histogram) = result {
                    DispatchQueue.main.async {
                        self.histogram = histogram
                    }
                }
            }
        }

        var heartRateLevels: HeartRateRanges? {
            guard let averageHeartRate = restingHeartRateService.averageHeartRate else { return nil }

            return restingHeartRateService.rangesForHeartRateLevels(average: averageHeartRate)
        }
    }
    // swiftlint:enable type_body_length
}
