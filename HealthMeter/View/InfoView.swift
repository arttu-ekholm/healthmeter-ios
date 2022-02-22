//
//  InfoView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 14.2.2022.
//

import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: ViewModel

    class ViewModel: ObservableObject {
        private let heartRateService: RestingHeartRateService

        @Published var presentAlert = false
        @Published var backgroundObserverIsOn: Bool = true {
            didSet {
                heartRateService.backgroundObserverQueryEnabled = backgroundObserverIsOn
                if !backgroundObserverIsOn {
                    presentAlert = true
                }
            }
        }

        @Published var fakeHeartRateValue: Double = 100.0

        init(heartRateService: RestingHeartRateService = RestingHeartRateService.shared) {
            self.heartRateService = heartRateService

            if let averageHeartRate = heartRateService.averageHeartRate {
                fakeHeartRateValue = averageHeartRate * heartRateService.threshold + 1
            }

            // This could be simpler with @AppStorage
            backgroundObserverIsOn = heartRateService.backgroundObserverQueryEnabled
        }

        var latestHighRHRNotificationPostDate: Date? {
            return heartRateService.latestHighRHRNotificationPostDate
        }

        func sendFakeHeartRateUpdate() {
            let update = RestingHeartRateUpdate(date: Date(), value: fakeHeartRateValue, isRealUpdate: false)
            heartRateService.handleDebugUpdate(update: update)
        }

        var averageHeartRate: Double? {
            return heartRateService.averageHeartRate
        }

        var fakeUpdateDescriptionText: String {
            return """
            Tapping the button will make the app to process a fake resting heart rate update with a resting heart rate of \(String(format: "%.0f", (fakeHeartRateValue))) bpm. It will be posted after a short delay.

            The value won't be saved to the HealthKit database and it won't affect the notifications you'd receive from Restful normally, so it's safe to test the update.
            """
        }

        var notificationFootnoteString: String {
            let thresholdRestingHeartRate: String
            if let averageHeartRate = averageHeartRate {
                thresholdRestingHeartRate = String(format: " (above %.0f bpm)", averageHeartRate * heartRateService.threshold)
            } else {
                thresholdRestingHeartRate = ""
            }

            return """
            If Restful detects an elevated resting heart rate\(thresholdRestingHeartRate), you'll receive a push notification. You'll be notified only once per day about elevated resting heart rate.
            """
        }

        var latestHighRHRNotificationDisplayString: String {
            if let date = latestHighRHRNotificationPostDate {
                return "Restful has notified you about elevated resting heart rate \(date.timeAgoDisplay())"
            } else {
                return "No elevated resting heart levels detected."
            }
        }

        var backgroundObservationText: String {
            if backgroundObserverIsOn {
                return "Restful is observing the changes in your resting heart rate in the background. If this switch is off, you won't receive notifications."
            } else {
                return "Restful has stopped observing the cnahges in your resting heart rate. It won't send you notifications until this switch is turned on."
            }
        }

        var highRHRIsPostedToday: Bool {
             return heartRateService.hasPostedAboutRisingNotificationToday
        }

        var applicationVersionDisplayable: String {
            guard let versionNumber = Bundle.main.releaseVersionNumber else {
                return ""
            }

            if let buildNumber = Bundle.main.buildVersionNumber {
                return "Restful version " + versionNumber + " (" + buildNumber + ")"
            } else {
                return "Restful version " + versionNumber
            }
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .padding()
            }

            Toggle("Observe resting heart rate updates and receive notifications", isOn: $viewModel.backgroundObserverIsOn)
                .alert("Observer and notifications disabled",
                       isPresented: $viewModel.presentAlert, actions: {
                    Button("OK", role: .cancel, action: {
                        viewModel.presentAlert = false
                    })
                }) {
                    Text("You won't see updates about your resting heart rate and won't receive notifications.")
                }
            Text(viewModel.backgroundObservationText)
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()

            VStack {
                Text("How does Restful work?")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)

                Text(viewModel.notificationFootnoteString)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if viewModel.highRHRIsPostedToday {
                    Text("You have received a notification about your elevated resting heart rate today.")
                }
            }

            Spacer()

            Text(viewModel.latestHighRHRNotificationDisplayString)

            Spacer()

            VStack(alignment: .center, spacing: 12, content: {
                Text("Test the notification")
                    .font(.title3)
                    .bold()
                HStack {
                    Spacer()
                    Stepper("Fake resting heart rate: \(String(format: "%.0f", (viewModel.fakeHeartRateValue))) bpm", value: $viewModel.fakeHeartRateValue, in: 1...150)
                        .font(.footnote)
                    Spacer()
                }
                Button {
                    viewModel.sendFakeHeartRateUpdate()
                } label: {
                    Text("Handle fake update")
                        .bold()
                }
                .font(.title2)
                .padding()
                .foregroundColor(.white)
                .background(.blue)
                .cornerRadius(12)
                Text(viewModel.fakeUpdateDescriptionText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            })
                .padding()
                .border(.secondary, width: 2)
            Spacer()
        }
        .padding()
        Text(viewModel.applicationVersionDisplayable)
            .font(.footnote)
            .foregroundColor(.secondary)
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView(viewModel: InfoView.ViewModel(heartRateService: RestingHeartRateService.shared))
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
