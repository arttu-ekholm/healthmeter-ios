//
//  ContentView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 23.1.2022.
//

import SwiftUI
import HealthKit

let healthStore: HKHealthStore = HKHealthStore()

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @State var shouldDisplayHealthKitAuthorisation = false
    @ObservedObject var settingsStore = SettingsStore()

    let heartRateService: RestingHeartRateService = RestingHeartRateService.shared

    @State var debugValue: Double = 50.0

    var body: some View {
        if settingsStore.tutorialShown {
            if !shouldDisplayHealthKitAuthorisation {
                HeartView(restingHeartRateService: heartRateService)
            }
            Text("")
                .onAppear {
                    heartRateService.getAuthorisationStatusForRestingHeartRate(completion: { status in
                        shouldDisplayHealthKitAuthorisation = (status == .unknown || status == .shouldRequest)
                    })
                }
            if Config.shared.displayDebugView {
                VStack {
                    Text("Debug view:")
                    latestHighRHR(date: heartRateService.latestHighRHRNotificationPostDate)
                    latestLowRHR(date: heartRateService.latestLoweredRHRNotificationPostDate)
                    latestDebugDate(date: heartRateService.latestDebugNotificationDate)

                    TextField("", value: $debugValue, format: .number)
                        .keyboardType(.numberPad)

                    Button("Handle fake update") {
                        heartRateService.handleDebugUpdate(update: RestingHeartRateUpdate(date: Date(), value: debugValue))
                    }
                }
                .border(.black, width: 1)
                .padding()
            }
        } else {
            TutorialView(settingsStore: settingsStore, heartRateService: heartRateService)
        }
    }

    func latestHighRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No high HRH notification") }

        return Text("Latest high HRH notification: \(date)")
    }

    func latestLowRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No low HRH notification") }

        return Text("Latest low HRH notification: \(date)")
    }

    func latestDebugDate(date: Date?) -> Text {
        guard let date = date else { return Text("No debug HRH notification") }

        return Text("Latest debug HRH notification: \(date)")
    }
    

    func averageHeartRateText(result: Result<Double, Error>?) -> Text? {
        guard let result = result else { return nil }

        switch result {
        case .success(let avgHeartRate):
            return Text("Your heart rate is \(avgHeartRate) bpm")
        case .failure(let error):
            return Text("Heart rate query failed with an error: \(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class SettingsStore: ObservableObject {
    @Published var tutorialShown: Bool = UserDefaults.standard.bool(forKey: "tutorialShown") {
        didSet {
            UserDefaults.standard.set(self.tutorialShown, forKey: "tutorialShown")
        }
    }
}
