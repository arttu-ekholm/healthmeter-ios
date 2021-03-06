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
        VStack(alignment: .center, spacing: 12, content: {
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
        })
            .onAppear {
                if viewModel.shouldReloadContents {
                    viewModel.requestLatestRestingHeartRate()
                }
                viewModel.checkNotificationStatus()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, viewModel.shouldReloadContents {
                    viewModel.requestLatestRestingHeartRate()
                }
                viewModel.checkNotificationStatus()
            }
    }

    func heartRateText(restingHeartRateResult: Result<RestingHeartRateUpdate, Error>?) -> Text? {
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
                    viewState: .success(RestingHeartRateUpdate(date: Date(), value: 90.0), 60.0)))
            HeartView(
                viewModel: HeartView.ViewModel(
                    heartRateService: RestingHeartRateService.shared,
                    shouldReloadContents: false,
                    viewState: .success(RestingHeartRateUpdate(date: Date(), value: 60.0), 60.0)))
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
