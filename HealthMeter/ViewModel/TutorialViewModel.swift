//
//  TutorialViewModel.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 22.2.2022.
//

import Foundation
import UIKit

extension TutorialView {
    class ViewModel: ObservableObject {
        @Published var authorized = false {
            didSet {
                currentPhase = .allowPushNotifications
            }
        }
        @Published var notificationsEnabled = false {
            didSet {
                currentPhase = .allDone
            }
        }
        @Published var currentPhase: Phase = .authorizeHealthKit

        @Published var presentNotificationsAlert = false

        private let heartRateService: RestingHeartRateService

        init(heartRateService: RestingHeartRateService = RestingHeartRateService.shared) {
            self.heartRateService = heartRateService
        }

        func authorizeHealthKit() {
            heartRateService.requestAuthorisation { [weak self] _, _ in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.authorized = true
                }
            }
        }

        var settingsAppURL: URL {
            return URL(string: UIApplication.openSettingsURLString)!
        }
    }
}
