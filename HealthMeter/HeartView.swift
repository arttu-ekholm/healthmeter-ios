//
//  HeartView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import SwiftUI

enum ViewState<T> {
    case loading
    case success(T)
    case error(Error)
}

struct HeartView: View {
    @State var viewState: ViewState<RestingHeartRateUpdate> = .loading
    let restingHeartRateService: RestingHeartRateService
    @State private var animationAmount: CGFloat = 1

    var body: some View {
        VStack {
            switch viewState {
            case .loading:
                Image(systemName: "heart.text.square")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(.red)
                Text("Loading…")
            case .error(let error):
                Image(systemName: "heart.slash")
                    .resizable()
                    .frame(width: 100, height: 100, alignment: .center)
                    .foregroundColor(.red)
                Text("Failed to load. \(error.localizedDescription)")
            case .success(let update):
                Image(systemName: "heart")
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
                    .onAppear {
                        animationAmount = 1.08
                    }
                Text("Latest resting heart rate is \(String(format: "%.0f", update.value)).")
                Text("Fetched \(update.date.timeAgoDisplay())")
            }
        }.onAppear {
            requestLatestRestingHeartRate()
        }
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
        }
    }

    func requestLatestRestingHeartRate() {
        restingHeartRateService.queryLatestRestingHeartRate { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let update):
                    viewState = .success(update)
                case .failure(let error):
                    viewState = .error(error)
                }
            }
        }
    }
}

struct HeartView_Previews: PreviewProvider {
    static var previews: some View {
        HeartView(viewState: .success(RestingHeartRateUpdate(date: Date(), value: 60.0)), restingHeartRateService: RestingHeartRateService.shared)
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
