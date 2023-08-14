//
//  HealthMeterApp.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 23.1.2022.
//

import SwiftUI
import WhatsNewKit

@main
struct HealthMeterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.whatsNew,
                     WhatsNewEnvironment(
                        versionStore: UserDefaultsWhatsNewVersionStore(),
                        whatsNewCollection: self
                     )
                )
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let heartRateService = RestingHeartRateService.shared
        heartRateService.getAuthorisationStatusForRestingHeartRate { status in
            if status == .unnecessary {
                if heartRateService.backgroundObserverQueryEnabled {
                    heartRateService.observeInBackground(type: .restingHeartRate)
                    heartRateService.observeInBackground(type: .wristTemperature)
                }
            }
        }
        return true
    }
}

// MARK: - App+WhatsNewCollectionProvider

extension HealthMeterApp: WhatsNewCollectionProvider {
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "1.3.0",
            title: "What's new in Restful",
            features: [
                WhatsNew.Feature(image: .init(systemName: "thermometer.medium", foregroundColor: .accentColor),
                                 title: "Wrist temperature measurement",
                                 subtitle: "Apple Watch measures the wrist temperature during your sleep. Get notified if your wrist temperature rises.")],
            primaryAction: WhatsNew.PrimaryAction(
                    title: "Grant access",
                    backgroundColor: .accentColor,
                    foregroundColor: .white,
                    hapticFeedback: .notification(.success),
                    onDismiss: {
                        RestingHeartRateService.shared.getAuthorisationStatusForRestingHeartRate { status in
                            if status == .shouldRequest {
                                RestingHeartRateService.shared.requestAuthorisation { success, error in
                                    if success, error == nil {
                                        RestingHeartRateService.shared.observeInBackground(type: .wristTemperature)

                                        RestingHeartRateService.shared.queryAverageWristTemperature { res in
                                            RestingHeartRateService.shared.queryLatestMeasurement(type: .wristTemperature) { res in print("WT done \(res)") }
                                        }
                                        RestingHeartRateService.shared.queryAverageRestingHeartRate { res in
                                            RestingHeartRateService.shared.queryLatestMeasurement(type: .restingHeartRate) { res in print("RHR done \(res)")}
                                        }
                                    }
                                }
                            }
                        }
                    }
                ),
                // The optional secondary action that is displayed above the primary action
                secondaryAction: WhatsNew.SecondaryAction(
                    title: "Continue",
                    foregroundColor: .accentColor,
                    hapticFeedback: .selection,
                    action: .dismiss
                )
        )
    }

}
