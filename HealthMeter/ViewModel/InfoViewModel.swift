//
//  InfoViewModel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 22.2.2022.
//

import Foundation

extension InfoView {
    class ViewModel: ObservableObject {
        private let heartRateService: RestingHeartRateService

        @Published var presentAlert = false
        @Published var backgroundObserverIsOn: Bool = true {
            didSet {
                heartRateService.backgroundObserverQueryEnabled = backgroundObserverIsOn
                if !backgroundObserverIsOn {
                    presentAlert = true
                }
            }
        }

        @Published var fakeHeartRateValue: Double = 100.0

        init(heartRateService: RestingHeartRateService = RestingHeartRateService.shared) {
            self.heartRateService = heartRateService

            if let averageHeartRate = heartRateService.averageHeartRate {
                fakeHeartRateValue = averageHeartRate * heartRateService.threshold + 1
            }

            // This could be simpler with @AppStorage
            backgroundObserverIsOn = heartRateService.backgroundObserverQueryEnabled
        }

        var latestHighRHRNotificationPostDate: Date? {
            return heartRateService.latestHighRHRNotificationPostDate
        }

        var averageHeartRate: Double? {
            return heartRateService.averageHeartRate
        }

        var fakeUpdateDescriptionText: String {
            return """
            Tapping the button will make the app to process a fake resting heart rate update with a resting heart rate of \(String(format: "%.0f", (fakeHeartRateValue))) bpm. It will be posted after a short delay.

            The value won't be saved to the HealthKit database and it won't affect the notifications you'd receive from Restful normally, so it's safe to test the update.
            """
        }

        var latestHighRHRNotificationDisplayString: String {
            if let date = latestHighRHRNotificationPostDate {
                return "Restful has notified you about elevated resting heart rate \(date.timeAgoDisplay())"
            } else {
                return "No elevated resting heart levels detected."
            }
        }

        var backgroundObservationText: String {
            if backgroundObserverIsOn {
                return "Restful is observing the changes in your resting heart rate in the background. If this switch is off, you won't receive notifications."
            } else {
                return "Restful has stopped observing the cnahges in your resting heart rate. It won't send you notifications until this switch is turned on."
            }
        }

        var highRHRIsPostedToday: Bool {
            return heartRateService.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }

        var applicationVersionDisplayable: String {
            guard let versionNumber = Bundle.main.releaseVersionNumber else {
                return ""
            }

            if let buildNumber = Bundle.main.buildVersionNumber {
                return "Restful version " + versionNumber + " (" + buildNumber + ")"
            } else {
                return "Restful version " + versionNumber
            }
        }
    }
}
