//
//  RestingHeartRateService.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 26.1.2022.
//

import Foundation
import HealthKit
import UIKit

enum Trend {
    case rising
    case lowering
    case low2low
    case high2high
}

class RestingHeartRateService {
    static let shared = RestingHeartRateService()

    // UserDefaults and its keys
    private let userDefaults: UserDefaults
    private let averageRestingHeartRateKey = "AverageRestingHeartRate"
    private let latestRestingHeartRateUpdateKey = "LatestRestingHeartRateUpdate"
    private let latestHighRHRNotificationPostDateKey = "LatestHighRHRNotificationPostDate"
    private let latestLoweredRHRNotificationPostDateKey = "LatestLoweredRHRNotificationPostDate"

    private var latestRestingHeartRateUpdate: RestingHeartRateUpdate?

    private let threshold = 1.05

    private let calendar: Calendar

    var averageHeartRate: Double? {
        get {
            return userDefaults.double(forKey: averageRestingHeartRateKey)
        }
        set {
            userDefaults.set(newValue, forKey: averageRestingHeartRateKey)
        }
    }

    /**
     The date when the last "You have a high RHR" notification is posted
     */
    var latestHighRHRNotificationPostDate: Date? {
        get {
            return userDefaults.object(forKey: latestHighRHRNotificationPostDateKey) as? Date
        } set {
            userDefaults.set(newValue, forKey: latestHighRHRNotificationPostDateKey)
        }
    }

    /**
     The date when the last "You lowered your RHR!" notification is posted
     */
    var latestLoweredRHRNotificationPostDate: Date? {
        get {
            return userDefaults.object(forKey: latestLoweredRHRNotificationPostDateKey) as? Date
        } set {
            userDefaults.set(newValue, forKey: latestLoweredRHRNotificationPostDateKey)
        }
    }

    init(userDefaults: UserDefaults = UserDefaults.standard, calendar: Calendar = Calendar.current) {
        self.userDefaults = userDefaults
        self.calendar = calendar

        self.latestRestingHeartRateUpdate = decodeLatestRestingHeartRateUpdate()
    }


    func decodeLatestRestingHeartRateUpdate() -> RestingHeartRateUpdate? {
        guard let data = userDefaults.data(forKey: latestRestingHeartRateUpdateKey) else { return nil }

        let decoder = JSONDecoder()
        let update = try? decoder.decode(RestingHeartRateUpdate.self, from: data)

        return update
    }

    /**
     - returns true if the heart rate is above the average
     */
    func heartRateIsAboveAverage(update: RestingHeartRateUpdate, average: Double) -> Bool {
        return update.value / average > threshold
    }

    func queryRestingHeartRate(healthStore: HKHealthStore, averageRHRCallback: @escaping (Result<Double?, Error>) -> Void) {
        // TODO: Check if the user has enough HRV data to make the calculation feasible. If not, display something like "You need at least 2w of data to make this app work.

        let now = Date()
        let queryStart = Date().addingTimeInterval(-60 * 60 * 24 * 180)

        guard
            let quantityType = HKQuantityType.quantityType(forIdentifier: type)
        else {
            fatalError("Nil quantity type")
        }

        let interval = NSDateComponents()
        interval.month = 6

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: queryStart,
            intervalComponents: interval as DateComponents
        )
        // TODO: add statisticsUpdateHandler
        query.initialResultsHandler = { query, results, error in
            if let error = error {
                averageRHRCallback(.failure(error))
                return
            }

            guard let statsCollection = results else {
                averageRHRCallback(.success(nil))
                return
            }

            var avgValues = [Double]()
            statsCollection.enumerateStatistics(from: queryStart, to: now) { statistics, stop in
                if let quantity = statistics.averageQuantity() {
                    let value = quantity.doubleValue(for: HKUnit(from: "count/min"))
                    print(value)
                    avgValues.append(value)
                }
            }
            let avgRestingValue = avgValues.reduce(0.0, { partialResult, next in
                return partialResult + next
            }) / Double(avgValues.count)
            print("AVERAGE RESTING HEART RATE IS = \(avgRestingValue)")
            self.averageHeartRate = avgRestingValue
            averageRHRCallback(.success(avgRestingValue))
        }
        healthStore.execute(query)
    }
    

    func handleHeartRateUpdate(sample: HKQuantitySample) {
        let newHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        let update = RestingHeartRateUpdate(date: sample.endDate, value: newHeartRate)

        guard let averageHeartRate = averageHeartRate else {
            // No avg HR, the app cannot do the comparison
            postDebugNotification(message: "DEBUG MESSAGE: guard 1 fails")
            return
        }

        // Check if the date is later than the last saved rate update
        if let previousUpdate = latestRestingHeartRateUpdate {
            guard sample.endDate > previousUpdate.date else {
                // The update is earlier than the latest, so no need to compare
                // This can be ignored
                postDebugNotification(message: "DEBUG MESSAGE: guard 1 fails")
                return
            }
        } else {
            // No previous update. Notify about the rising heart rate
        }

        let isAboveAverageRHR = heartRateIsAboveAverage(update: update, average: averageHeartRate)

        // check if it is -, _, / or \

        var message: String?
        var trend: Trend?
        if isAboveAverageRHR {
            if !postedAboutRisingNotificationToday {
                trend = .rising
                message = notificationMessage(trend: .rising, heartRate: newHeartRate, averageHeartRate: averageHeartRate)
            }
        } else {
            // RHR has been high, now it's lowered.
            if !postedAboutLoweredNotificationToday, postedAboutRisingNotificationToday {
                trend = .lowering
                message = notificationMessage(trend: .lowering, heartRate: newHeartRate, averageHeartRate: averageHeartRate)
            }
        }

        if trend != nil, let message = message {
            postNotification(message: message)
            if trend == .rising {
                latestHighRHRNotificationPostDate = Date()
            } else if trend == .lowering {
                latestLoweredRHRNotificationPostDate = Date()
            }
        } else {
            let debugTrend: Trend = isAboveAverageRHR ? .high2high : .low2low
            let debugMessage = notificationMessage(trend: debugTrend, heartRate: newHeartRate, averageHeartRate: averageHeartRate)
            postNotification(message: debugMessage)
        }
    }

    func postDebugNotification(message: String) {
        postNotification(message: message)
    }

    func postNotification(message: String) {



        DispatchQueue.main.async {
            print("posting notification with message: \(message)")
            if UIApplication.shared.applicationState != .active {
                UIApplication.shared.applicationIconBadgeNumber = 1
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }

            let content = UNMutableNotificationContent()
            content.title = message

            content.sound = UNNotificationSound.default

            // choose a random identifier
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

            // add our notification request
           UNUserNotificationCenter.current().add(request) { error in
               if let error = error {
                   print("posting the notification failed with error: \(error)")
                   UIApplication.shared.applicationIconBadgeNumber = 9
               } else {
                   print("notification posted successfully")
               }
           }
        }
    }

    func notificationMessage(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String {
        let message: String
        let percentage: String = String(format: "%.0f", (heartRate / averageHeartRate) * 100.0)
        let debugString: String = "L RHR: \(String(format: "%.0f", heartRate)), avg: \(String(format: "%.0f", averageHeartRate))"
        switch trend {
        case .rising:
            message = "Your heart rate is \(percentage) above your average heart rate. You need to slow down. (\(debugString))"
        case .lowering:
            message = "Your heart rate returned back to normal. Well done! (\(debugString))"
        default:
            message = "Debug: \(debugString)"
        }

        return message
    }

    var postedAboutRisingNotificationToday: Bool {
        guard let latestHighRHRNotificationPostDate = latestHighRHRNotificationPostDate else { return false }

        return calendar.isDateInToday(latestHighRHRNotificationPostDate)
    }

    var postedAboutLoweredNotificationToday: Bool {
        guard let latestLoweredRHRNotificationPostDate = latestLoweredRHRNotificationPostDate else { return false }

        return calendar.isDateInToday(latestLoweredRHRNotificationPostDate)
    }

    func observeInBackground() {
        let sampleType = HKObjectType.quantityType(forIdentifier: type)!
        let query = HKObserverQuery(
            sampleType: sampleType,
            predicate: nil) { query, completionHandler, error in

                print("OBSERVER QUERY CALLBACK \(Date())")

                guard error == nil else { return }

                print("Observing in the background")

                // TODO: Do something here
                self.queryLatestRestingHeartRate {
                    print("Querying successful")
                    completionHandler()
                }
            }
        healthStore.execute(query)

        healthStore.enableBackgroundDelivery(
            for: sampleType,
               frequency: .hourly) { success, error in
                   print("Something happens here in HKObserverQuery. Success: \(success), error: \(String(describing: error?.localizedDescription))")
               }
    }

    func queryLatestRestingHeartRate(completionHandler: @escaping (() -> Void)) {
        let sampleType = HKSampleType.quantityType(forIdentifier: type)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let sampleQuery = HKSampleQuery(sampleType: sampleType,
                                        predicate: nil,
                                        limit: 1,
                                        sortDescriptors: [sortDescriptor],
                                        resultsHandler: { (query, results, error) in
            // TODO: Implement
            print("RESULTS are here")

            guard let sample = results?.last as? HKQuantitySample else {
                print("FUCK")
                return
            }

            self.handleHeartRateUpdate(sample: sample)

            completionHandler()
        })

        healthStore.execute(sampleQuery)
    }
}

struct RestingHeartRateUpdate: Codable {
    let date: Date
    let value: Double
}

