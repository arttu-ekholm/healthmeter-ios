//
//  TutorialView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 3.2.2022.
//

import SwiftUI

struct TutorialView: View {
    @ObservedObject var settingsStore: SettingsStore
    let heartRateService: RestingHeartRateService

    var body: some View {
        VStack(alignment: .center, spacing: 12.0) {
            Text("HealthMeter tracks your resting heart rate and notifies you if it rises above normal level. Higher than usual resting heart rate might be a sign of an illness.")
            Text("To make HealthMeter app work, you need two things:")
                .padding()

            HStack {
                Image(systemName: "lock.open.fill")
                    .foregroundColor(.blue)
                Text("Allow HealthMeter to read resting heart rate from HealthKit.")
            }

            HStack {
                Image(systemName: "heart.square")
                    .foregroundColor(.blue)
                Text("A device that records resting heart rate, such as Apple Watch.")
            }
            .padding(.bottom)
            Button {
                heartRateService.requestAuthorisation { success, _ in
                    if success {
                        DispatchQueue.main.async {
                            self.settingsStore.tutorialShown = true
                        }
                    }
                }
            } label: {
                Text("Authorise HealthKit").bold()
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
        TutorialView(settingsStore: SettingsStore(), heartRateService: RestingHeartRateService.shared)
    }
}
