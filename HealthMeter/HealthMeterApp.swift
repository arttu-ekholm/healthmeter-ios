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
