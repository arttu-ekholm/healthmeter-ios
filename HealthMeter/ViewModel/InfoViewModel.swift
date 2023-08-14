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

        init(heartRateService: RestingHeartRateService = RestingHeartRateService.shared) {
            self.heartRateService = heartRateService

            // This could be simpler with @AppStorage
            backgroundObserverIsOn = heartRateService.backgroundObserverQueryEnabled
        }

        var averageHeartRate: Double? {
            return heartRateService.averageHeartRate
        }

        var backgroundObservationText: String {
            if backgroundObserverIsOn {
                return "Restful is observing the changes in your resting heart rate in the background. If this switch is off, you won't receive notifications."
            } else {
                return "Restful has stopped observing the cnahges in your resting heart rate. It won't send you notifications until this switch is turned on."
            }
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
