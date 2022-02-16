//
//  SetttingsStore.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 16.2.2022.
//

import SwiftUI
import Foundation

class SettingsStore: ObservableObject {
    static let tutorialShownKey = "tutorialShown"
    let userDefaults: UserDefaults

    @Published var tutorialShown: Bool {
        didSet {
            userDefaults.set(self.tutorialShown, forKey: Self.tutorialShownKey)
        }
    }

    init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
        self.tutorialShown = userDefaults.bool(forKey: Self.tutorialShownKey)
    }
}
