//
//  TutorialView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 3.2.2022.
//

import SwiftUI

struct TutorialView: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .center, spacing: 12.0) {
            Text("HealthMeter").font(.title)
            Text("HealthMeter tracks your resting heart rate and notifies you if it rises above normal level. Higher than usual resting heart rate might be sign of an illness.")
            Text("""
    To make HealthMeter work, you need two things:
    1. your permission to read thee resting heart rate from HealthKit.
    2. a device that provides resting heart rate values, such as Apple Watch
    """)
            Button("Authorise HealthKit") {
                settingsStore.tutorialShown = true
            }
            .font(.title2)
            .padding()
            .foregroundColor(.white)
            .background(.blue)
            .cornerRadius(12)
        }
        .padding()
    }
}

struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialView(settingsStore: SettingsStore())
    }
}
