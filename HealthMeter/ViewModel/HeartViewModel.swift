//
//  HeartViewModel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 22.2.2022.
//

import Foundation
import UserNotifications
import SwiftUI

extension HeartView {
    class ViewModel: ObservableObject {
        private let restingHeartRateService: RestingHeartRateService
        private let calendar: Calendar
        let notificationCenter = UNUserNotificationCenter.current()

        var shouldReloadContents: Bool
        @Published var viewState: ViewState<RestingHeartRateUpdate, Double>
        @Published var notificationsDenied = false

        init(
            heartRateService: RestingHeartRateService = RestingHeartRateService.shared,
            calendar: Calendar = Calendar.current,
            shouldReloadContents: Bool = true,
            viewState: ViewState<RestingHeartRateUpdate, Double> = .loading) {
                self.restingHeartRateService = heartRateService
                self.calendar = calendar
                self.shouldReloadContents = shouldReloadContents
                self.viewState = viewState
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
                        return .blue // over -5 %
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
                    if multiplier < -0.05 {
                        return "arrow.down.heart.fill"
                    } else {
                        return "heart.fill"
                    }
                }
            default:
                return "heart.fill"
            }
        }

        func requestLatestRestingHeartRate() {
            restingHeartRateService.queryAverageRestingHeartRate { averageResult in

                self.restingHeartRateService.queryLatestRestingHeartRate { latestResult in
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

        func getLatestRestingHeartRateDisplayString(update: RestingHeartRateUpdate) -> String {
            if calendar.isDateInToday(update.date) {
                return "Your resting heart rate today is"
            } else if calendar.isDateInYesterday(update.date) {
                return "Yesterday, your resting heart rate was"
            } else { // past
                return "Earlier, your resting heart rate was"
            }
        }

        func heartRateAnalysisText(update: RestingHeartRateUpdate, average: Double) -> String {
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
    }
}
