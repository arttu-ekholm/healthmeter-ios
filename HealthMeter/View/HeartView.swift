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

private struct RestingHeartRateHistogram: View {
    let histogram: RestingHeartRateHistory
    let levels: HeartRateRanges
    let average: Double
    let active: Double
    @State var spacing: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(histogram.histogramItems, id: \.self) { item in
                    let width = (geometry.size.width / CGFloat(histogram.histogramItems.count)) - spacing
                    HistogramBar(
                        item: item,
                        value: normalizedValue(value: item.count,
                                               maximumValue: histogram.maximumValue),
                        level: levels.levelForRestingHeartRate(rate: Double(item.item)) ?? nil,
                        isAverage: Int(average) == item.item,
                        isActive: Int(active) == item.item)
                        .frame(width: width, alignment: .bottom)
                }
            }
        }
    }

    func normalizedValue(value: Int, maximumValue: Int) -> Double {
        return Double(value) / Double(maximumValue)
    }
}

private let history = RestingHeartRateHistory(histogramItems: [
    RestingHeartRateHistogramItem(item: 50, count: 3),
    RestingHeartRateHistogramItem(item: 51, count: 0),
    RestingHeartRateHistogramItem(item: 52, count: 4),
    RestingHeartRateHistogramItem(item: 53, count: 6),
    RestingHeartRateHistogramItem(item: 54, count: 8),
    RestingHeartRateHistogramItem(item: 55, count: 4),
    RestingHeartRateHistogramItem(item: 56, count: 3),
    RestingHeartRateHistogramItem(item: 57, count: 1),
    RestingHeartRateHistogramItem(item: 58, count: 3),
    RestingHeartRateHistogramItem(item: 59, count: 0),
    RestingHeartRateHistogramItem(item: 60, count: 4),
    RestingHeartRateHistogramItem(item: 61, count: 6),
    RestingHeartRateHistogramItem(item: 62, count: 8),
    RestingHeartRateHistogramItem(item: 63, count: 4),
    RestingHeartRateHistogramItem(item: 64, count: 3),
    RestingHeartRateHistogramItem(item: 65, count: 1)
])

struct RestingHeartRateHistogram_Previews: PreviewProvider {
    static var previews: some View {
        RestingHeartRateHistogram(
            histogram: history,
            levels: RestingHeartRateService.shared.rangesForHeartRateLevels(average: 50.0),
            average: 50.0,
            active: 52.0)
    }
}

private struct HistogramBar: View {
    let item: RestingHeartRateHistogramItem
    let value: Double
    let level: HeartRateLevel?
    let isAverage: Bool
    let isActive: Bool

    var body: some View {
        VStack {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4.0)
                    .foregroundColor(color)
                    .brightness(isActive ? 0.1 : 0)
                    .frame(width: geometry.size.width, height: geometry.size.height * value, alignment: .bottom)
                    .offset(x: 0, y: geometry.size.height * (1 - value))

            }
            Text(text)
                .font(.footnote)
                .fontWeight(isAverage ? .bold : .regular)
                .fixedSize()
        }
    }

    private var text: String {
        if isAverage { return String(item.item) }
        return item.item % 5 == 0 ? String(item.item) : " "
    }

    private var color: Color {
        switch self.level {
        case .belowAverage: return .blue
        case .normal: return .green
        case .slightlyElevated: return .yellow
        case .noticeablyElevated: return .orange
        case .wayAboveElevated: return .red
        case nil: return .gray
        }
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
