//
//  HeartView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import SwiftUI

struct HeartView: View {

    @StateObject var viewModel: ViewModel
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36, content: {
                Spacer(minLength: 40)

                if let disp = viewModel.allMeasurementsDisplay {
                    HStack {
                        Spacer()
                        Text(disp.string)
                            .foregroundColor(.primary)
                            .font(.title2)
                            .bold()
                        Spacer()
                    }
                    ZStack {
                        Divider()
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 48, height: 48)
                        Image(systemName: disp.imageName)
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(disp.color)
                            .scaledToFit()
                    }
                } else {
                    Divider()
                }

                HStack {
                    Image(systemName: "heart")
                        .font(.title2)
                        .bold()
                        .foregroundColor(viewModel.rhrDisabled ? .gray : .secondary)
                        .frame(width: 36)
                    VStack(alignment: .leading, content: {
                        HStack {
                            Text("Resting heart rate")
                                .font(.title2)
                                .foregroundColor(viewModel.rhrDisabled ? .gray : .primary)
                                .bold()
                            Spacer()
                            Text(viewModel.rhrStatusDisplayText)
                                .font(.title2)
                                .foregroundColor(viewModel.rhrColor)
                                .bold()
                        }
                        if case .failure(let error) = viewModel.rhr {
                            if case QueryParser.QueryParserError.noLatestValueFound = error {
                                Text("No measurements found")
                                    .foregroundColor(.gray)
                            } else {
                                Text("Failed to fetch measurements")
                                    .foregroundColor(.gray)
                            }
                            Text("").font(.footnote) // occupies vertical space
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("Current")
                                Text(viewModel.restingHeartRateDisplayText)
                                    .font(.title3)
                                    .bold()
                                Text(viewModel.rhrUnits)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .bold()
                                Spacer()
                                Text("Average")
                                Text(viewModel.rhrAverageDisplayText)
                                    .font(.title3)
                                    .bold()
                                Text(viewModel.rhrUnits)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .bold()
                            }
                            HStack {
                                if case .success(let update) = viewModel.rhr {
                                    Text(update.date.timeAgoDisplay())
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if viewModel.avg != nil {
                                    Text("2 month average")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    })
                }
                HStack {
                    Image(systemName: "thermometer.medium")
                        .font(.title2)
                        .bold()
                        .foregroundColor(viewModel.rhrDisabled ? .gray: .secondary)
                        .frame(width: 36)
                    VStack(alignment: .leading, content: {
                        HStack {
                            Text("Wrist temperature")
                                .font(.title2)
                                .bold()
                                .foregroundColor(viewModel.wristTemperatureDisabled ? .gray : .primary)
                            Spacer()
                            Text(viewModel.wristTemperatureStatusDisplayText)
                                .foregroundColor(viewModel.wristTemperatureColor)
                                .font(.title2)
                                .bold()
                        }
                        if case .failure(let error) = viewModel.rhr {
                            if case QueryParser.QueryParserError.noLatestValueFound = error {
                                Text("No measurements found")
                                    .foregroundColor(.gray)
                            } else {
                                Text("Failed to fetch measurements")
                                    .foregroundColor(.gray)
                            }
                            Text("").font(.footnote) // occupies vertical space
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("Current")
                                Text(viewModel.wristTemperatureCurrentDisplayText)
                                    .font(.title3)
                                    .bold()
                                Text(viewModel.wtUnits)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .bold()
                                Spacer()

                                Text(viewModel.wtAverageDisplayText)
                                    .font(.title3)
                                    .bold()
                                Text(viewModel.wtUnits)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .bold()
                                Text(viewModel.wristTemperatureDiffDisplayText)
                            }
                        }
                        HStack {
                            if case .success(let update) = viewModel.wristTemperature {
                                Text(update.date.timeAgoDisplay())
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if viewModel.avgWrist != nil {
                                Text("2 month average")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    })
                }

                /*
                if viewModel.shouldShowMissingMeasurements {
                    Divider()
                    MissingMeasurementsView(viewModel: viewModel,
                                            title: "Missing measurements",
                                            bodyText: "We're unable to fetch some of the measurements. Make sure you have authorised the reading of the measurements in the Health app",
                                            linkTitle: "Health app",
                                            linkURL: URL(string: "x-apple-health://Sources/")!) {
                        viewModel.markMissingMeasurementsAsShown()
                    }
                }
                 */
                if viewModel.shouldShowDisabledNotificationsAlert {
                    MissingMeasurementsView(viewModel: viewModel,
                                            title: "Notifications disabled",
                                            bodyText: "To get notifications about elevated resting heart rate, go to the Settings app and enable them.",
                                            linkTitle: "Settings app",
                                            linkURL: viewModel.settingsAppURL) {
                        viewModel.markDisabledNotificationsAlertAsShown()
                    }
                }

                Spacer()
            })
            .padding()
            .onAppear {
                if viewModel.shouldReloadContents {
                    viewModel.requestLatestRestingHeartRate()
                    viewModel.requestLatestWristTemperature()
                }

                viewModel.checkNotificationStatus()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, viewModel.shouldReloadContents {
                    viewModel.requestLatestRestingHeartRate()
                    viewModel.requestLatestWristTemperature()
                }
                viewModel.checkNotificationStatus()
            }
        }

    }

    func heartRateText(restingHeartRateResult: Result<GenericUpdate, Error>?) -> Text? {
        guard let result = restingHeartRateResult else {
            return nil
        }

        switch result {
        case .success(let update):
            return Text(String(update.value))
        case .failure(let error):
            return Text(error.localizedDescription)
                .bold()
                .font(.headline)
        }
    }
}

private struct MissingMeasurementsView: View {
    let viewModel: HeartView.ViewModel
    let title: String
    let bodyText: String
    let linkTitle: String
    let linkURL: URL
    let dismissAction: (() -> Void)?
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text(title)
                    .font(.headline)
                    .bold()
                Spacer()
                Button {
                    withAnimation {
                        dismissAction?()
                    }
                } label: {
                    Image(systemName: "xmark")
                }
            }
            Text(bodyText)
                .font(.footnote)
            Link(linkTitle, destination: linkURL)
                .bold()
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange, lineWidth: 1)
        )
    }
}

private struct DescriptionTextView: View {
    let title: String
    let subtitle: String?
    var body: some View {
        VStack(alignment: .center, spacing: 12.0) {
            Text(title)
                .bold()
                .font(.headline)
            if let subtitle = subtitle {
                Text(subtitle)
            }
        }
        .padding()
    }
}
