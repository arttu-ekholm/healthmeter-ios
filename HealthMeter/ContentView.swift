//
//  ContentView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 23.1.2022.
//

import SwiftUI
import HealthKit

//let type: HKQuantityTypeIdentifier = HKQuantityTypeIdentifier.heartRate

let healthStore: HKHealthStore = HKHealthStore()

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @State var queryResult: Result<Double, Error>?
    @State var shouldDisplayHealthKitAuthorisation = false

    let heartRateService: RestingHeartRateService = RestingHeartRateService.shared

    var body: some View {
        if shouldDisplayHealthKitAuthorisation {
            Button("Request authorization") {
                heartRateService.requestAuthorisation { success, error in
                    heartRateService.getAuthorisationStatusForRestingHeartRate(completion: { needsAuthorisation in
                        shouldDisplayHealthKitAuthorisation = needsAuthorisation
                    })
                }
            }
        }

        Button("query") {
            heartRateService.queryRestingHeartRate() { result in
                self.queryResult = result
            }
        }
        Text("This app measures your average resting heart rate. You'll be alerted if it rises above your average.")
            .padding().onChange(of: scenePhase) { newValue in
                if newValue == .inactive || newValue == .background {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }.onAppear {
                heartRateService.getAuthorisationStatusForRestingHeartRate(completion: { needsAuthorisation in
                    shouldDisplayHealthKitAuthorisation = needsAuthorisation
                })
            }
        latestHighRHR(date: heartRateService.latestHighRHRNotificationPostDate)
        latestLowRHR(date: heartRateService.latestLoweredRHRNotificationPostDate)

        averageHeartRateText(result: queryResult)
    }

    func latestHighRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No high HRH notification") }

        return Text("Latest high HRH notification: \(date)")
    }

    func latestLowRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No low HRH notification") }

        return Text("Latest low HRH notification: \(date)")
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
        ContentView(queryResult: nil)
    }
}

