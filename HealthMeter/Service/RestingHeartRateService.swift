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

    var displayText: String {
        switch self {
        case .rising: return "Elevated resting heart rate"
        case .lowering: return "Resting heart rate back to normal"
        }
    }
}

// swiftlint:ignore type_body_length
class RestingHeartRateService {
    /**
     These are mapped to `HKAuthorizationRequestStatus`
     */
    enum HealthKitAuthorisationStatus {
        case unknown
        case shouldRequest
        case unnecessary
    }
    static let shared = RestingHeartRateService()

    // UserDefaults and its keys
    private let userDefaults: UserDefaults
    private let averageRestingHeartRateKey = "AverageRestingHeartRate"
    private let latestRestingHeartRateUpdateKey = "LatestRestingHeartRateUpdate"
    private let latestHighRHRNotificationPostDateKey = "LatestHighRHRNotificationPostDate"
    private let latestLoweredRHRNotificationPostDateKey = "LatestLoweredRHRNotificationPostDate"

    private var latestRestingHeartRateUpdate: RestingHeartRateUpdate?

    // If the latest update is this much above the avg. RHR, the notification will be triggered.
    var threshold: Double {
        return 1.05
    }

    /**
     if `true`, the manager is handling a `RestingHeartRateUpdate`. Set to `true` when handling begins, and to `false`when the function either
     decides to ignore the update, or when the `NotificationCenter` callback tells the notificaiton is handled.
     */
    private var isHandlingUpdate = false

    /// Pending updates that aren't handled yet. Used to resolve the issue where there can be multiple simultaneous `RestingHeartRateUpdate`s.
    private var updateQueue: [RestingHeartRateUpdate] = []

    // Dependencies
    private let calendar: Calendar
    private let healthStore: HKHealthStore

    ///  Provides the queries for the HKHealthStore to execute
    private let queryProvider: QueryProvider

    /// Parses the query responses
    private let queryParser: QueryParser

    /// Handles the sending of local push notifications
    private let notificationService: NotificationService

    private var currentObserverQuery: HKObserverQuery?

    var isObservingChanges: Bool {
        return currentObserverQuery != nil
    }

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

    /**
     Decodes the latest RHR update from UserDefaults
     */
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

    func queryAverageRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        let now = Date()
        let queryStartDate = now.addingTimeInterval(-60 * 60 * 24 * 60)
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

    /**
     Creates a fake update and handles it after a slight delay.
     */
    func handleDebugUpdate(update: RestingHeartRateUpdate) {
        let taskId =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            print("handling")
            self.handleHeartRateUpdate(update: update)
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }

    /**
     Decides if a notification needs to be sent about the update. If the update isn't above the average, the update will be ignored.
     */
    // swiftlint:ignore:next function_body_length
    func handleHeartRateUpdate(update: RestingHeartRateUpdate) {
        guard let averageHeartRate = averageHeartRate else {
            // No avg HR, the app cannot do the comparison
            return
        }

        /* It's possible that the HKObserverQuery sends multiple callback simultaneously. Posting notifications is asynchronous,
         which causes the notification sent timestamp to be updated after multiple notifications are sent. To prevent this,
         `isHandlingUpdate` flag is raised while this function handles the notification. The pending updates are added to the
         `updateQueue` array.
         */

        if update.isRealUpdate, isHandlingUpdate {
            print("Is already handling an update, adding it to the queue")
            updateQueue.append(update)
            return
        }

        isHandlingUpdate = true

        // Check if the date is later than the last saved rate update
        if let previousUpdate = latestRestingHeartRateUpdate {
            guard update.date > previousUpdate.date else {
                // The update is earlier than the latest, so no need to compare
                // This can be ignored
                isHandlingUpdate = false
                handleNextItemFromQueueIfNeeded()
                return
            }
        }

        if update.isRealUpdate {
            // Save the update so its date can be compared to the next updates
            self.latestRestingHeartRateUpdate = update
        }

        let isAboveAverageRHR = heartRateIsAboveAverage(update: update, average: averageHeartRate)

        // check if the trend is rising or lowering

        var message: String?
        var trend: Trend?
        if isAboveAverageRHR {
            if !hasPostedAboutRisingNotificationToday {
                trend = .rising
                message = notificationMessage(trend: .rising,
                                              heartRate: update.value,
                                              averageHeartRate: averageHeartRate)
            }
        } else {
            // RHR has been high, now it's lowered.
            if !hasPostedAboutLoweredNotificationToday, hasPostedAboutRisingNotificationToday {
                trend = .lowering
                message = notificationMessage(trend: .lowering,
                                              heartRate: update.value,
                                              averageHeartRate: averageHeartRate)
            }
        }

        guard let trend = trend, let message = message else {
            isHandlingUpdate = false
            handleNextItemFromQueueIfNeeded()
            return
        }

        notificationService.postNotification(title: notificationTitle(trend: trend,
                                                                      heartRate: update.value,
                                                                      averageHeartRate: averageHeartRate),
                                             body: message) { result in
            self.isHandlingUpdate = false
            if case .success = result, update.isRealUpdate { // The dates for test notifications aren't saved
                self.saveNotificationPostDate(forTrend: trend)
            }
            // If the pending updates queue has more items, process them
            self.handleNextItemFromQueueIfNeeded()
        }
    }

    private func handleNextItemFromQueueIfNeeded() {
        guard !updateQueue.isEmpty else { return }

        print("Handling pending update")
        let update = updateQueue.removeFirst()
        handleHeartRateUpdate(update: update)
    }

    private func saveNotificationPostDate(forTrend trend: Trend) {
        if trend == .rising {
            latestHighRHRNotificationPostDate = Date()
        } else if trend == .lowering {
            latestLoweredRHRNotificationPostDate = Date()
        }
    }

    func notificationTitle(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String {
        return trend.displayText
    }

    func notificationMessage(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String? {
        switch trend {
        case .rising:
            return heartRateAnalysisText(current: heartRate, average: averageHeartRate) + " " + "You should slow down."
        case .lowering:
            return "Your resting heart rate returned back to normal. Well done!"
        }
    }

    var hasPostedAboutRisingNotificationToday: Bool {
        guard let latestHighRHRNotificationPostDate = latestHighRHRNotificationPostDate else { return false }

        return calendar.isDateInToday(latestHighRHRNotificationPostDate)
    }

    var hasPostedAboutLoweredNotificationToday: Bool {
        guard let latestLoweredRHRNotificationPostDate = latestLoweredRHRNotificationPostDate else { return false }

        return calendar.isDateInToday(latestLoweredRHRNotificationPostDate)
    }

    /**
     Sets the app to observe the changes in HealthKit and wake up when there are new RHR updates.
     */
    func observeInBackground(completionHandler: @escaping ((Bool, Error?) -> Void)) {
        guard !isObservingChanges else {
            fatalError("App is currently observing")
        }

        let observerQuery = queryProvider.getObserverQuery { _, completionHandler, error in
            guard error == nil else { return }

            self.queryLatestRestingHeartRate { result in

                if case .success(let update) = result {
                    self.handleHeartRateUpdate(update: update)
                }

                completionHandler()
            }
        }
        healthStore.execute(observerQuery)

        healthStore.enableBackgroundDelivery(
            for: queryProvider.sampleTypeForRestingHeartRate,
               frequency: .hourly) { success, error in
                   if success {
                       print("BG observation successful")
                       self.currentObserverQuery = observerQuery
                   }
                   if let error = error {
                       print("BG observation failed with error: \(error)")
                   }
                   completionHandler(success, error)
               }
    }

    func queryLatestRestingHeartRate(completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        let sampleQuery = queryProvider.getLatestRestingHeartRateQuery { query, results, error in
            self.queryParser.parseLatestRestingHeartRateQueryResults(
                query: query,
                results: results,
                error: error) { result in
                    completionHandler(result)
            }
        }

        healthStore.execute(sampleQuery)
    }

    // MARK: - HealthKit permissions

    func requestAuthorisation(completion: @escaping (Bool, Error?) -> Void) {
        let rhr = Set([HKObjectType.quantityType(forIdentifier: .restingHeartRate)!])
        healthStore.requestAuthorization(toShare: [], read: rhr) { (success, error) in
            completion(success, error)
        }
    }

    func getAuthorisationStatusForRestingHeartRate(completion: @escaping (HealthKitAuthorisationStatus) -> Void) {
        let rhr = Set([HKObjectType.quantityType(forIdentifier: .restingHeartRate)!])
        healthStore.getRequestStatusForAuthorization(toShare: [], read: rhr) { status, _ in
            switch status {
            case .unnecessary: completion(.unnecessary)
            case .shouldRequest: completion(.shouldRequest)
            default: completion(.unknown)
            }
        }
    }

    var isHealthDataAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Strings

    func heartRateAnalysisText(current: Double, average: Double) -> String {
        let difference = current - average
        let adjective: String
        let multiplier = (current > average ? current / average : average / current) - 1.0

        if abs(multiplier) > 0.05 {
            if multiplier > 0.2 {
                adjective = "way"
            } else if multiplier > 0.1 {
                adjective = "noticeably"
            } else {
                adjective = "slightly"
            }
            if difference > 0 {
                return "Your resting heart rate is \(adjective) above your average."
            } else {
                return "Your resting heart rate is \(adjective) below your average."
            }
        } else {
            return "Your resting heart rate is normal."
        }
    }
}
