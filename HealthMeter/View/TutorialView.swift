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

        @Published var presentHealthKitAlert = false
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            HStack {
                Spacer()
                Text("Restful")
                    .font(.title)
                    .bold()
                    .padding()
                Spacer()
            }
            Spacer()

            Text("Restful tracks your resting heart rate and notifies you if it rises above normal level. Higher than usual resting heart rate might be a sign of an illness.")
            Text("To make Restful work, you need three things:")
                .bold()
                .padding()

            HStack {
                Image(systemName: viewModel.authorized ? "checkmark.square" : "square")
                    .foregroundColor(.blue)
                    .padding()
                Text("Allow Restful to read resting heart rate from HealthKit.")
                    .fontWeight(viewModel.currentPhase == .authorizeHealthKit ? .bold : .regular)
            }
            HStack {
                Image(systemName: viewModel.notificationsEnabled ? "checkmark.square" : "square")
                    .foregroundColor(.blue)
                    .padding()
                Text("Have push notifications enabled.")
                    .fontWeight(viewModel.currentPhase == .allowPushNotifications ? .bold : .regular)
            }
            HStack {
                Image(systemName: "square")
                    .foregroundColor(.blue)
                    .padding()
                Text("A device that records resting heart rate, such as Apple Watch.")
                    .fontWeight(viewModel.currentPhase == .allDone ? .bold : .regular)
            }

            .padding(.bottom)
            Spacer()
            HStack(alignment: .center) {
                Spacer()

                switch viewModel.currentPhase {
                case .authorizeHealthKit:
                    Button {
                        viewModel.authorizeHealthKit()
                    } label: {
                        Text("Authorise HealthKit")
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
                        settingsStore.tutorialShown = true
                        dismiss()
                    } label: {
                        Text("Start using the app")
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
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
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
