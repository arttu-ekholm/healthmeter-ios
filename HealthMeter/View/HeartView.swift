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
            case .missingBoth, .missingAverageHeartRate: return "Please try again when you have collected more resting heart rate data. Also, check if you have authorised HealthKit."
            case .missingLatestHeartRate:
                return "Make sure your health devices record your resting heart rate."
            default: return nil
            }
        }
    }

    class ViewModel: ObservableObject {
        private let restingHeartRateService: RestingHeartRateService
        private let calendar: Calendar
        var shouldReloadContents: Bool
        @Published var viewState: ViewState<RestingHeartRateUpdate, Double>

        init(
            heartRateService: RestingHeartRateService = RestingHeartRateService.shared,
            calendar: Calendar = Calendar.current,
            shouldReloadContents: Bool = true,
            viewState: ViewState<RestingHeartRateUpdate, Double> = .loading) {
                self.restingHeartRateService = heartRateService
                self.calendar = calendar
                self.shouldReloadContents = shouldReloadContents
                self.viewState = viewState
            }

        var heartColor: Color {
            switch viewState {
            case .success(let latest, let average):
                let current = latest.value
                let multiplier = (current > average ? current / average : average / current) - 1.0
                if multiplier > 0 {
                    if multiplier > 0.2 {
                        return .red
                    } else if multiplier > 0.1 {
                        return .orange
                    } else if multiplier > 0.05 {
                        return .yellow
                    } else {
                        return .green
                    }
                } else {
                    return .blue
                }
            default: return .green
            }
        }

        func requestLatestRestingHeartRate() {
            restingHeartRateService.queryLatestRestingHeartRate { [weak self] latestResult in
                guard let self = self else { return }

                self.restingHeartRateService.queryAverageRestingHeartRate { [weak self] averageResult in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if case .success(let update) = latestResult, case .success(let average) = averageResult {
                            self.viewState = .success(update, average)
                        } else if case .failure = averageResult, case .failure = latestResult {
                            self.viewState = .error(HeartViewError.missingBoth)
                        } else if case .failure = averageResult {
                            self.viewState = .error(HeartViewError.missingLatestHeartRate)
                        } else if case .failure = latestResult {
                            self.viewState = .error(HeartViewError.missingLatestHeartRate)
                        }
                    }
                }
            }
        }

        func getLatestRestingHeartRateDisplayString(update: RestingHeartRateUpdate) -> String {
            if calendar.isDateInToday(update.date) {
                return "Your resting heart rate today is"
            } else if calendar.isDateInYesterday(update.date) {
                return "Yesteday, your resting heart rate was"
            } else { // past
                return "Earlier, your resting heart rate was"
            }
        }

        func heartRateAnalysisText(update: RestingHeartRateUpdate, average: Double) -> String {
            if calendar.isDateInToday(update.date) {
                return restingHeartRateService.heartRateAnalysisText(current: update.value, average: average)
            } else {
                return "Today's resting heart rate hasn't been calculated yet."
            }
        }
    }

    @State private var animationAmount: CGFloat = 1
    @StateObject var viewModel: ViewModel
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(alignment: .center, spacing: 12, content: {
            switch viewModel.viewState {
            case .loading:
                Image(systemName: "heart.text.square.fill")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(.red)
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
            case .success(let update, let average):
                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(viewModel.heartColor)
                    .scaleEffect(animationAmount)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.0)
                            .delay(0.01)
                            .repeatForever(autoreverses: true),
                        value: animationAmount
                    )
                    .padding()
                    .onAppear {
                        animationAmount = 1.08
                    }

                Text(viewModel.heartRateAnalysisText(update: update, average: average))
                    .font(.headline)
                    .padding(.bottom)

                VStack {
                    Text(viewModel.getLatestRestingHeartRateDisplayString(update: update)) + Text(" ") +
                    Text(String(format: "%.0f", update.value))
                        .font(.title2)
                        .bold() +
                    Text(" bpm.")
                        .bold()

                    /*
                     Text("Updated \(update.date.timeAgoDisplay())").font(.footnote)
                     .padding(.bottom)
                     */

                    Text("Your average resting heart rate is ") +
                    Text(String(format: "%.0f", average))
                        .font(.title2)
                        .bold() +
                    Text(" bpm.")
                        .bold()
                }
            }
        })
            .onAppear {
                if viewModel.shouldReloadContents {
                    viewModel.requestLatestRestingHeartRate()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, viewModel.shouldReloadContents {
                    viewModel.requestLatestRestingHeartRate()
                }
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

struct DescriptionTextView: View {
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
