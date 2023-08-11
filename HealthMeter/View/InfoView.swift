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
            ZStack {
                Text("Settings and info")
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
            VStack(alignment: .center, spacing: 24) {
                /*
                 return """
                 Restful monitors your resting heart rate and wrist temperature levels on the background. If either appears to be elevated, the app sends you a notification.\(thresholdRestingHeartRate)

                 You'll receive only one notification about either event per day.

                 Restful doesn't need a network connection to function. It doesn't modify your records in the Health app. Restful doesn't collect your personal information or gather analytics.
                 """
                 */

                VStack(alignment: .leading) {
                    Text("What does Restful do?")
                        .font(.title3)
                        .bold()
                        .padding(.bottom)
                    VStack(spacing: 24) {
                        HStack(spacing: 16) {
                            Image(systemName: "figure.walk")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.accentColor)
                            Text("Restful monitors your resting heart rate and wrist temperature levels on the background. The app notifies you if either seems to be elevated.")
                                .font(.subheadline)
                            Spacer()
                        }
                        HStack(spacing: 16) {
                            Image(systemName: "bell.badge")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.accentColor)
                            Text("The amount of notifications is limited to one per day for each measurement type.")
                                .font(.subheadline)
                            Spacer()
                        }
                        HStack(spacing: 16) {
                            Image(systemName: "checkerboard.shield")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.accentColor)
                            Text("Restful doesn't need a network connection to function. It doesn't modify your records in the Health app. Restful doesn't collect your personal information or gather analytics.")
                                .font(.subheadline)
                            Spacer()

                        }
                    }
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
