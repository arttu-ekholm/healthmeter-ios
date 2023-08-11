//
//  TutorialView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 3.2.2022.
//

import SwiftUI

struct TutorialView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: ViewModel

    enum Phase: CaseIterable {
        case authorizeHealthKit
        case allowPushNotifications
        case allDone
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12.0) {
                HStack {
                    Spacer()
                    Text("Welcome to Restful")
                        .font(.title)
                        .bold()
                        .padding()
                    Spacer()
                }

                Text("Restful tracks your resting heart rate and your sleeping wrist temperature and notifies you if either rises above your normal level.")
                Text("Elevated resting heart rate might be a sign of illness or stress.")
                Spacer()
                ZStack {
                    Divider()
                    Image(systemName:  "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)

                        .foregroundColor(.green)
                        .padding(.horizontal)
                }

                Spacer()
                Text("Setting up Restful contains three steps")
                    .font(.headline)
                    .bold()
                    .padding(.bottom)

                HStack {
                    Image(systemName: viewModel.authorized ? "checkmark" : "")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .fontWeight(viewModel.currentPhase == .authorizeHealthKit ? .semibold : .regular)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                    Text("Allow Restful to read from Health app.")
                        .font(.subheadline)
                        .fontWeight(viewModel.currentPhase == .authorizeHealthKit ? .semibold : .regular)
                }
                HStack {
                    Image(systemName: viewModel.notificationsEnabled ? "checkmark" : "")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.green)
                        .fontWeight(viewModel.currentPhase == .allowPushNotifications ? .semibold : .regular)
                        .padding()
                    Text("Enable push notifications")
                        .font(.subheadline)
                        .fontWeight(viewModel.currentPhase == .allowPushNotifications ? .semibold : .regular)
                }
                HStack {
                    Image(systemName: "")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.green)
                        .fontWeight(viewModel.currentPhase == .allDone ? .semibold : .regular)
                        .padding()
                    Text("Make sure you have an activity watch that records resting heart rate and wrist temperature, such as Apple Watch.")
                        .font(.subheadline)
                        .fontWeight(viewModel.currentPhase == .allDone ? .semibold : .regular)
                }
                .padding(.bottom)
            }

            Spacer()
            HStack(alignment: .center) {
                Spacer()

                switch viewModel.currentPhase {
                case .authorizeHealthKit:
                    Button {
                        viewModel.authorizeHealthKit()
                    } label: {
                        Text("Authorise Health app")
                            .bold()
                    }
                    .font(.title2)
                    .padding()
                    .foregroundColor(.white)
                    .background(.blue)
                    .cornerRadius(12)

                case .allowPushNotifications:
                    Button {
                        let center = UNUserNotificationCenter.current()
                        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                            if error != nil || !granted {
                                DispatchQueue.main.async {
                                    viewModel.presentNotificationsAlert = true
                                }
                            } else {
                                DispatchQueue.main.async {
                                    viewModel.notificationsEnabled = true
                                }
                            }
                        }
                    } label: {
                        Text("Enable push notifications")
                            .bold()
                    }
                    .font(.title2)
                    .padding()
                    .foregroundColor(.white)
                    .background(.blue)
                    .cornerRadius(12)
                case .allDone:
                    Button {
                        Haptics().playSuccessHapticFeedbackEvent()
                        settingsStore.tutorialShown = true
                        dismiss()
                    } label: {
                        Text("Done")
                            .bold()
                    }
                    .font(.title2)
                    .padding()
                    .foregroundColor(.white)
                    .background(.blue)
                    .cornerRadius(12)
                }
                Spacer()
            }
            .alert("Push notifications aren't enabled",
                   isPresented: $viewModel.presentNotificationsAlert, actions: {
                Button("OK", role: .cancel, action: {
                    viewModel.presentNotificationsAlert = false
                    viewModel.currentPhase = .allDone
                })
                Button("Settings", action: {
                    UIApplication.shared.open(viewModel.settingsAppURL)
                })
            }) {
                Text("To receive push notifications about elevated resting heart rate, go to the Settings app.")
            }
        }
        .padding()
    }
}

struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialView(
            settingsStore: SettingsStore(),
            viewModel: TutorialView.ViewModel(heartRateService: RestingHeartRateService.shared))
    }
}
