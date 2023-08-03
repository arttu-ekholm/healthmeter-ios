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
                    Haptics().playHapticFeedbackEvent()
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
