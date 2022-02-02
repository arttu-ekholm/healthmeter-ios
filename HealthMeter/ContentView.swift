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
    @State var queryResult: Result<Double?, Error>?
    let heartRateService: RestingHeartRateService

    var body: some View {
        Text("TODO: display the correct authorization status here")
        Button("Request authorization") {
            requestHealthKitAuthorization(healthStore: healthStore)
        }
        Button("query") {
            heartRateService.queryRestingHeartRate(healthStore: healthStore) { result in
                self.queryResult = result
            }
        }
        Text("This app measures your average resting heart rate. You'll be alerted if it rises above your average.")
            .padding().onChange(of: scenePhase) { newValue in
                if newValue == .inactive || newValue == .background {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
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
    

    func averageHeartRateText(result: Result<Double?, Error>?) -> Text? {
        guard let result = result else { return nil }

        switch result {
        case .success(let avgHeartRate):
            if let avgHeartRate = avgHeartRate {
                return Text("Your heart rate is \(avgHeartRate) bpm")
            } else {
                return Text("You don't have a heart rate ☠️")
            }
        case .failure(let error):
            return Text("Heart rate query failed with an error: \(error.localizedDescription)")
        }
    }

    /**
     Requests authorization from HealthKit store
     */
    private func requestHealthKitAuthorization(healthStore: HKHealthStore) {
        // TODO: add completion handler to the func parameter

        let allTypes = Set([
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!])
        healthStore.requestAuthorization(toShare: allTypes, read: allTypes) { (success, error) in
            if let error = error {
                print("HK authorisation failed with error: \(error.localizedDescription)")
            }
            if success {
                print("HK authorized successfully")
            } else {
                print("HK failed to authorize")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(queryResult: nil, heartRateService: RestingHeartRateService())
    }
}

