//
//  HeartView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import SwiftUI

struct HeartView: View {
    enum ViewState<T, S> {
        case loading
        case success(T, S)
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
            case .missingLatestHeartRate: return "TODO: implement this"
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
            case .missingBoth, .missingAverageHeartRate: return "Please try again when you have collected more resting heart rate data."
            default: return nil
            }
        }
    }

    var shouldReloadContents: Bool = true

    @State var viewState: ViewState<RestingHeartRateUpdate, Double> = .loading
    let restingHeartRateService: RestingHeartRateService
    @State private var animationAmount: CGFloat = 1
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(alignment: .center, spacing: 12, content: {
            switch viewState {
            case .loading:
                Image(systemName: "heart.text.square.fill")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(.red)
                Text("Loading…")
            case .error(let error):
                Image(systemName: "heart.slash.fill")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .bold()
                    .font(.headline)
                    .padding()
                if let error = error as? LocalizedError, let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                }
            case .success(let update, let average):
                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(.red)
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
                Text(restingHeartRateService.heartRateAnalysisText(current: update.value, average: average))
                    .font(.headline)
                    .padding(.bottom)
                VStack {
                    Text("Your latest resting heart rate is \(String(format: "%.0f", update.value)) bpm.")
                    Text("Your average resting heart rate is \(String(format: "%.0f", average)) bpm.")
                    Text("(Fetched \(update.date.timeAgoDisplay()))").font(.footnote)
                }

            }
        })
            .onAppear {
                if shouldReloadContents {
                    requestLatestRestingHeartRate()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, shouldReloadContents {
                    requestLatestRestingHeartRate()
                }
            }
    }

    func heartRateAnalysisText(current: Double, average: Double) -> Text {
        let difference = current - average
        let string: String
        let adjective: String
        let multiplier = current > average ? current / average : average / current

        switch multiplier {
        case let x where x > 20: adjective = "very"
        case 10...20: adjective = "quite"
        case 5...10: adjective = "a bit"
        default: adjective = "slighty"
        }

        switch difference {
        case let x where x - difference == 0:
            string = "Your resting heart rate is normal"
        case let x where x - difference > 0:
            string = "Your resting heart rate is \(adjective) above your average."
        case let x where x - difference < 0:
            string = "Your resting heart rate is \(adjective) below your average."
        default: string = "Keep going"
        }

        return Text(string)
            .bold()
            .font(.headline)
    }

    func heartRateText(restingHeartRateResult: Result<RestingHeartRateUpdate, Error>?) -> Text? {
        print("heartRateText render called \(restingHeartRateResult.debugDescription)")
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

    func requestLatestRestingHeartRate() {
        restingHeartRateService.queryLatestRestingHeartRate { latestResult in
            self.restingHeartRateService.queryAverageRestingHeartRate { averageResult in
                DispatchQueue.main.async {
                    if case .success(let update) = latestResult, case .success(let average) = averageResult {
                        viewState = .success(update, average)
                    } else if case .failure = averageResult, case .failure = latestResult {
                        viewState = .error(HeartViewError.missingBoth)
                    } else if case .failure = averageResult {
                        viewState = .error(HeartViewError.missingLatestHeartRate)
                    } else if case .failure = latestResult {
                        viewState = .error(HeartViewError.missingLatestHeartRate)
                    }
                }
            }
        }
    }
}

struct HeartView_Previews: PreviewProvider {
    static var previews: some View {
        HeartView(shouldReloadContents: false, viewState: .success(RestingHeartRateUpdate(date: Date(), value: 90.0), 60.0), restingHeartRateService: RestingHeartRateService.shared)
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
