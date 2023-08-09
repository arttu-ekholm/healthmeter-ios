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
                    heartRateService.observeInBackground()
                }
            }
        }
        return true
    }
}

// MARK: - App+WhatsNewCollectionProvider

extension HealthMeterApp: WhatsNewCollectionProvider {
    /// Declare your WhatsNew instances per version
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "1.3.0",
            title: "What's new in Restful",
            features: [
                WhatsNew.Feature(image: .init(systemName: "thermometer.medium", foregroundColor: .accentColor),
                                 title: "Wrist temperature measurement",
                                 subtitle: "Get notified when your body temperature gets elevated.")],
            primaryAction: WhatsNew.PrimaryAction(
                    title: "Grant access",
                    backgroundColor: .accentColor,
                    foregroundColor: .white,
                    hapticFeedback: .notification(.success),
                    onDismiss: {
                        RestingHeartRateService.shared.requestAuthorisation { _, _ in }
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
