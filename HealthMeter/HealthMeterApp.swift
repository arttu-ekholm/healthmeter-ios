//
//  HealthMeterApp.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 23.1.2022.
//

import SwiftUI

@main
struct HealthMeterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        RestingHeartRateService.shared.getAuthorisationStatusForRestingHeartRate { status in
            if status == .unnecessary {
                RestingHeartRateService.shared.observeInBackground { success, error in
                    print("Observing updates in the background: \(success), error: \(error.debugDescription)")
                }
            }
        }
        return true
    }
}
