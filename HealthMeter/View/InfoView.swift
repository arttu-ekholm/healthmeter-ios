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
