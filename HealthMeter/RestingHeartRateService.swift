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

    typealias ObserverQueryHandler = (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void

    // UserDefaults and its keys
    private let userDefaults: UserDefaults
    private let averageRestingHeartRateKey = "AverageRestingHeartRate"
    private let latestRestingHeartRateUpdateKey = "LatestRestingHeartRateUpdate"
    private let latestHighRHRNotificationPostDateKey = "LatestHighRHRNotificationPostDate"
    private let latestLoweredRHRNotificationPostDateKey = "LatestLoweredRHRNotificationPostDate"

    private var latestRestingHeartRateUpdate: RestingHeartRateUpdate?

    private let threshold = 1.05

    // Dependencies
    private let calendar: Calendar
    private let healthStore: HKHealthStore
    private let queryProvider: QueryProvider
    private let queryParser: QueryParser

    // TODO: change this as it needs to be set to false on every test
    var postDebugNotifications = true

    let notificationService: NotificationService

    var averageHeartRate: Double? {
        get {
            guard let avg = userDefaults.object(forKey: averageRestingHeartRateKey) else { return nil }
            return avg as? Double
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

    init(userDefaults: UserDefaults = UserDefaults.standard,
         calendar: Calendar = Calendar.current,
         notificationService: NotificationService = NotificationService(),
         healthStore: HKHealthStore = HKHealthStore(),
         queryProvider: QueryProvider = QueryProvider(),
         queryParser: QueryParser = QueryParser()) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.notificationService = notificationService
        self.healthStore = healthStore
        self.queryProvider = queryProvider
        self.queryParser = queryParser

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

    func queryRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        // TODO: Check if the user has enough HRV data to make the calculation feasible. If not, display something like "You need at least 2w of data to make this app work.

        let now = Date()
        let queryStartDate = now.addingTimeInterval(-60 * 60 * 24 * 180)
        let query = queryProvider.getAverageRestingHeartRateQuery(queryStartDate: queryStartDate)

        query.initialResultsHandler = { query, results, error in
            self.queryParser.parseAverageRestingHeartRateQueryResults(startDate: queryStartDate,
                                                                      endDate: now,
                                                                      query: query,
                                                                      result: results,
                                                                      error: error,
                                                                      callback: { result in
                if case .success(let value) = result {
                    self.averageHeartRate = value
                }
                averageRHRCallback(result)
            })
        }
        healthStore.execute(query)
    }
    

    func handleHeartRateUpdate(update: RestingHeartRateUpdate) {
        guard let averageHeartRate = averageHeartRate else {
            // No avg HR, the app cannot do the comparison
            postDebugNotification(message: "DEBUG MESSAGE: guard 1 fails")
            return
        }

        // Check if the date is later than the last saved rate update
        if let previousUpdate = latestRestingHeartRateUpdate {
            guard update.date > previousUpdate.date else {
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
                message = notificationMessage(trend: .rising, heartRate: update.value, averageHeartRate: averageHeartRate)
            }
        } else {
            // RHR has been high, now it's lowered.
            if !postedAboutLoweredNotificationToday, postedAboutRisingNotificationToday {
                trend = .lowering
                message = notificationMessage(trend: .lowering, heartRate: update.value, averageHeartRate: averageHeartRate)
            }
        }

        if trend != nil, let message = message {
            notificationService.postNotification(message: message)
            if trend == .rising {
                latestHighRHRNotificationPostDate = Date()
            } else if trend == .lowering {
                latestLoweredRHRNotificationPostDate = Date()
            }
        } else {
            let debugTrend: Trend = isAboveAverageRHR ? .high2high : .low2low
            let debugMessage = notificationMessage(trend: debugTrend, heartRate: update.value, averageHeartRate: averageHeartRate)
            postDebugNotification(message: debugMessage)
        }
    }

    func postDebugNotification(message: String) {
        guard postDebugNotifications else { return }

        notificationService.postNotification(message: message)
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
        let observerQuery = queryProvider.getObserverQuery { query, completionHandler, error in
            print("OBSERVER QUERY CALLBACK \(Date())")

            guard error == nil else { return }

            print("Observing in the background")

            // TODO: Do something here
            self.queryLatestRestingHeartRate { _ in
                completionHandler()
            }
        }
        healthStore.execute(observerQuery)

        healthStore.enableBackgroundDelivery(
            for: queryProvider.sampleTypeForRestingHeartRate,
               frequency: .hourly) { success, error in
                   print("Something happens here in HKObserverQuery. Success: \(success), error: \(String(describing: error?.localizedDescription))")
               }
    }

    func queryLatestRestingHeartRate(completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        let sampleQuery = queryProvider.getLatestRestingHeartRateQuery { query, results, error in
            self.queryParser.parseLatestRestingHeartRateQueryResults(query: query, results: results, error: error) { result in
                completionHandler(result)
            }
        }

        healthStore.execute(sampleQuery)
    }

    // MARK: - HealthKit permissions
    func requestAuthorisation(completion: @escaping (Bool, Error?) -> Void) {
        let rhr = Set([
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!])
        healthStore.requestAuthorization(toShare: [], read: rhr) { (success, error) in
            completion(success, error)
        }
    }

    func getAuthorisationStatusForRestingHeartRate(completion: @escaping (Bool) -> Void) {
        let rhr = Set([
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!])
        healthStore.getRequestStatusForAuthorization(toShare: [], read: rhr) { status, error in
            if status == .unnecessary {
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
