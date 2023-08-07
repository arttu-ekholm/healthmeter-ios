//
//  HeartView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import SwiftUI

struct HeartView: View {
    enum ViewState<T, E> {
        case loading
        case success(T, E)
        case error(Error)
    }

    enum HeartViewError: LocalizedError {
        case missingLatestHeartRate
        case missingAverageHeartRate
        case missingBoth
        case other(Error)

        var errorDescription: String? {
            switch self {
            case .missingBoth: return "You don't have any resting heart rate data saved to your device."
            case .missingLatestHeartRate: return "HeartRate couldn't read your latest resting heart rate."
            case .missingAverageHeartRate: return "You don't have enough resting heart rate data collected. HeartRate app starts to work when your devices have collected enough data."
            case .other(let error):
                if let error = error as? LocalizedError {
                    return error.localizedDescription
                } else {
                    return nil
                }
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .missingBoth, .missingAverageHeartRate: return
                """
            Please try again when you have collected more resting heart rate data. Go to the Health app and authorise Restful to read your resting heart rate.
            """
            case .missingLatestHeartRate:
                return "Make sure your health devices record your resting heart rate."
            default: return nil
            }
        }
    }

    @StateObject var viewModel: ViewModel
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 24, content: {
            Text("Your measurements")
                .font(.title)
                .bold()
                .padding()
            HStack {
                Image(systemName: "heart")
                    .font(.title2)
                    .bold()
                    .foregroundColor(viewModel.rhrDisabled ? .gray : viewModel.rhrColor)
                    .frame(width: 36)
                VStack(alignment: .leading, content: {
                    HStack {
                        Text("Resting heart rate")
                            .font(.title2)
                            .foregroundColor(viewModel.rhrDisabled ? .gray : .black)
                            .bold()
                        Spacer()
                        Text(viewModel.rhrStatusDisplayText)
                            .font(.title2)
                            .foregroundColor(viewModel.rhrColor)
                            .bold()
                    }
                    if viewModel.rhrDisabled {
                        Text("Failed to fetch measurement")
                            .foregroundColor(.gray)
                    } else {
                        HStack {
                            Text("Current:")
                            Text(viewModel.restingHeartRateDisplayText)

                                .bold()
                            Spacer()
                            Text("Average:")
                            Text(viewModel.rhrAverageDisplayText)
                                .bold()
                        }
                    }

                })
            }
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2)
                    .bold()
                    .foregroundColor(viewModel.wristTemperatureColor)
                    .frame(width: 36)
                VStack(alignment: .leading, content: {
                    HStack {
                        Text("Wrist temperature")
                            .font(.title2)
                            .bold()
                        Spacer()
                        Text(viewModel.wristTemperatureStatusDisplayText)
                            .foregroundColor(viewModel.wristTemperatureColor)
                            .font(.title2)
                            .bold()
                    }
                    HStack {
                        Text("Current")
                        Text(viewModel.wristTemperatureCurrentDisplayText)
                            .foregroundColor(viewModel.wristTemperatureColor)
                            .bold()
                        Spacer()

                        Text(viewModel.wristTemperatureDiffDisplayText)
                    }
                })
            }
            /*
            HStack {
                Image(systemName: "bolt.heart")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.gray)
                    .frame(width: 36)
                VStack(alignment: .leading, content: {
                    Text("Heart rate variability")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.gray)
                    Text("Unable to fetch measurements.")
                        .foregroundColor(.gray)
                })
            }
*/


            if viewModel.shouldShowMissingMeasurements {
                Divider()
                VStack(alignment: .center, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.orange)
                        Text("Missing measurements")
                            .font(.title3)
                            .bold()
                        Spacer()
                        Image(systemName: "xmark")
                            .bold()
                    }
                    .padding(.bottom)

                    Text("We're unable to fetch some of the measurements. Make sure you have authorised the reading of the measurements in the Settings app")
                    Link("Settings app", destination: URL(string: UIApplication.openSettingsURLString)!)
                        .bold()
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange, lineWidth: 3)
                )
            }
            if viewModel.notificationsDenied {
                NotificationsDisabledView(settingsAppURL: viewModel.settingsAppURL)
            }


            Spacer()


            //            Text("Resting heart rate")
            //            Text(viewModel.restingHeartRateDisplayText)
            //            Text("Wrist temperature")
            //            Text(viewModel.wristTemperatureDisplayText)
            /*
             switch viewModel.viewState {
             case .loading:
             DescriptionTextView(title: "Loading…", subtitle: nil)
             case .error(let error):
             Image(systemName: "heart.slash.fill")
             .resizable()
             .frame(width: 100, height: 100, alignment: .center)
             .foregroundColor(.red)
             if let error = error as? LocalizedError, let recoverySuggestion = error.recoverySuggestion {
             DescriptionTextView(title: error.localizedDescription, subtitle: recoverySuggestion)
             } else {
             DescriptionTextView(title: error.localizedDescription, subtitle: nil)
             }
             Link("Health app", destination: viewModel.healthAppURL)
             .font(.title2)

             case .success(let update, let average):
             Image(systemName: viewModel.heartImageName)
             .resizable()
             .frame(width: 100, height: 100, alignment: .center)
             .foregroundColor(viewModel.heartColor)
             .scaleEffect(viewModel.animationAmount)
             .animation(
             .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.0)
             .delay(0.01)
             .repeatForever(autoreverses: true),
             value: viewModel.animationAmount
             )
             .padding()
             .onAppear {
             // "not calculated yet today" icon shouldn't be animated.
             viewModel.animationAmount = viewModel.heartImageShouldAnimate ? 1.08 : 1.0
             viewModel.fetchHistogramData()
             }

             Text(viewModel.heartRateAnalysisText(update: update, average: average))
             .font(.headline)
             .padding(.bottom)

             VStack {
             if let histogram = viewModel.histogram, let levels = viewModel.heartRateLevels {
             RestingHeartRateHistogram(
             histogram: histogram,
             levels: levels,
             average: average,
             active: update.value)
             .frame(maxHeight: 200, alignment: .bottom)
             .padding()
             }
             Text(viewModel.getLatestRestingHeartRateDisplayString(update: update)) + Text(" ") +
             Text(String(format: "%.0f", update.value))
             .font(.title2)
             .foregroundColor(colorForLevel(viewModel.heartRateLevels?.levelForRestingHeartRate(rate: update.value)))
             .bold() +
             Text(" bpm.")
             .bold()

             if viewModel.restingHeartRateIsUpdatedToday {
             Text("Updated \(update.date.timeAgoDisplay())")
             .font(.footnote)
             .padding(.bottom)
             }

             Text("Your average resting heart rate is ") +
             Text(String(format: "%.0f", average))
             .font(.title2)
             .foregroundColor(colorForLevel(viewModel.heartRateLevels?.levelForRestingHeartRate(rate: average)))
             .bold() +
             Text(" bpm.")
             .bold()
             if viewModel.notificationsDenied {
             NotificationsDisabledView(settingsAppURL: viewModel.settingsAppURL)
             }
             }
             }
             */
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

private struct NotificationsDisabledView: View {
    let settingsAppURL: URL
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.system(size: 36, weight: .medium))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notifications are disabled")
                        .bold()
                    Text("To get notifications about elevated resting heart rate, go to the Settings app and enable them.")
                        .font(.footnote)
                }
            }

            Link("Settings app", destination: settingsAppURL)
        }
        .padding()
        .border(.orange, width: 2)
        .padding()
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

struct HeartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .success(GenericUpdate(date: Date(), value: 90.0, type: .restingHeartRate), 60.0)))
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .success(GenericUpdate(date: Date(), value: 60.0, type: .restingHeartRate), 60.0)))
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .error(HeartView.HeartViewError.missingLatestHeartRate)))
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .error(HeartView.HeartViewError.missingAverageHeartRate)))
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .error(HeartView.HeartViewError.missingBoth)))
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .loading))
        }
    }
}
