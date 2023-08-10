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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .center, spacing: 24) {

                ZStack {
                    Text("Settings")
                        .font(.title)
                        .bold()
                    ZStack {
                        HStack {
                            Spacer()
                            Button {
                                Haptics().playHapticFeedbackEvent()
                                    dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .bold()
                            }
                        }

                    }
                }
                .padding(.bottom)

                VStack(alignment: .leading) {
                    Text("What does Restful do?")
                        .font(.title2)
                        .bold()
                        .padding(.bottom)

                    Text(viewModel.notificationFootnoteString)
                        .font(.callout)
                        .foregroundColor(.primary)

                    /*
                    if viewModel.highRHRIsPostedToday {
                        Text("You have received a notification about your elevated resting heart rate today.")
                    }
                     */
                }

                Divider()

                Toggle("Observe updates and receive notifications", isOn: $viewModel.backgroundObserverIsOn)
                    .alert("Observer and notifications are now disabled",
                           isPresented: $viewModel.presentAlert, actions: {
                        Button("OK", role: .cancel, action: {
                            viewModel.presentAlert = false
                        })
                    }) {
                        Text("You won't see updates about your elevated resting heart rate or wrist temperature, and you won't receive notifications about it.")
                    }
                    .padding(.horizontal)
                Text(viewModel.backgroundObservationText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Spacer()
                Text(viewModel.applicationVersionDisplayable)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView(viewModel: InfoView.ViewModel(heartRateService: RestingHeartRateService.shared))
    }
}
