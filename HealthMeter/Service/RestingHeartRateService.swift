//
//  RestingHeartRateService.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 26.1.2022.
//

import Foundation
import HealthKit
import UIKit
import Combine
import SwiftUI

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

// swiftlint: disable type_body_length
class RestingHeartRateService: ObservableObject {
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
    private let averageWristTemperatureKey = "AverageWristTemperature"
    private let latestRestingHeartRateUpdateKey = "LatestRestingHeartRateUpdate"
    private let latestWristTemperatureUpdateKey = "LatestWristTemperatureUpdate"
    private let latestHighRHRNotificationPostDateKey = "LatestHighRHRNotificationPostDate"
    private let latestHighWTNotificationPostDateKey = "LatestHighWTNotificationPostDateKey"
    private let latestLoweredRHRNotificationPostDateKey = "LatestLoweredRHRNotificationPostDate"
    private let backgroundObserverQueryEnabledKey = "BackgroundObserverQueryEnabledKey"

    @Published private(set) var latestRestingHeartRateUpdate: Result<GenericUpdate, Error>?
    @Published private(set) var latestWristTemperatureUpdate: Result<GenericUpdate, Error>?

    // If the latest update is this much above the avg. RHR, the notification will be triggered.
    var threshold: Double {
        return 1 + thresholdMultiplier
    }

    var thresholdMultiplier: Double {
        return 0.05
    }

    /**
     if `true`, the manager is handling a `RestingHeartRateUpdate`. Set to `true` when handling begins, and to `false`when the function either
     decides to ignore the update, or when the `NotificationCenter` callback tells the notification is handled.
     */
    private var isHandlingUpdate = false

    /// Pending updates that aren't handled yet. Used to resolve the issue where there can be multiple simultaneous `RestingHeartRateUpdate`s.
    private var updateQueue: [GenericUpdate] = []

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

    @Published private(set) var averageHeartRatePublished: Double?
    @Published private(set) var averageWristTemperaturePublished: Double?

    private(set) var averageHeartRate: Double? {
        get {
            guard let avg = userDefaults.object(forKey: averageRestingHeartRateKey) else { return nil }
            return avg as? Double
        }
        set {
            userDefaults.set(newValue, forKey: averageRestingHeartRateKey)
            averageHeartRatePublished = newValue
        }
    }

    private(set) var averageWristTemperature: Double? {
        get {
            guard let avg = userDefaults.object(forKey: averageWristTemperatureKey) else { return nil }
            return avg as? Double
        }
        set {
            userDefaults.set(newValue, forKey: averageWristTemperatureKey)
            DispatchQueue.main.async {
                self.averageWristTemperaturePublished = newValue
                self.objectWillChange.send()
            }

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

    var latestWTNotificationPostDate: Date? {
        get {
            return userDefaults.object(forKey: latestHighWTNotificationPostDateKey) as? Date
        } set {
            userDefaults.set(newValue, forKey: latestHighWTNotificationPostDateKey)
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

    var backgroundObserverQueryEnabled: Bool {
        get {
            return userDefaults.bool(forKey: backgroundObserverQueryEnabledKey)
        } set {
            userDefaults.set(newValue, forKey: backgroundObserverQueryEnabledKey)
            if newValue == true {
                observeInBackground()
            } else { // Stop the most recent observer query if it was launched during the app lifecycle
                if let currentObserverQuery = currentObserverQuery {
                    print("stopping observer query: \(currentObserverQuery)")
                    healthStore.stop(currentObserverQuery)
                }
                currentObserverQuery = nil
            }
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

        userDefaults.register(defaults: [backgroundObserverQueryEnabledKey: true])
    }

    /**
     Decodes the latest RHR update from UserDefaults
     */
    private func decodeLatestRestingHeartRateUpdate() -> Result<GenericUpdate, Error>? {
        guard let data = userDefaults.data(forKey: latestRestingHeartRateUpdateKey) else { return nil }

        let decoder = JSONDecoder()
        do {
            let update = try decoder.decode(GenericUpdate.self, from: data)
            return .success(update)
        } catch {
            return .failure(error)
        }
    }

    /**
     - returns true if the heart rate is above the average
     */
    func heartRateIsAboveAverage(update: GenericUpdate, average: Double) -> Bool {
        return update.value / average > threshold
    }

    func wristTemperatureIsAboveAverage(update: GenericUpdate, average: Double, locale: Locale = .current) -> Bool {
        if locale.measurementSystem == .us {
            return update.value - average > 1.8
        } else {
            return update.value - average > 1.0
        }
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

    func queryAverageWristTemperature(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        let now = Date()
        let queryStartDate = now.addingTimeInterval(-60 * 60 * 24 * 60)
        let query = queryProvider.getAverageWristTemperatureQuery(queryStartDate: queryStartDate)

        query.initialResultsHandler = { query, results, error in
            self.queryParser.parseAverageWristTemperatureQueryResults(startDate: queryStartDate,
                                                                      endDate: now,
                                                                      query: query,
                                                                      result: results,
                                                                      error: error,
                                                                      callback: { result in
                if case .success(let value) = result {
                    self.averageWristTemperature = value
                }
                averageRHRCallback(result)
            })
        }
        healthStore.execute(query)
    }

    func handleUpdate(update: GenericUpdate) {
        switch update.type {
        case .restingHeartRate: handleHeartRateUpdate(update: update)
        case .wristTemperature: handleWristTemperatureUpdate(update: update)
        }
    }
    func handleUpdateFailure(error: Error, type: UpdateType) {
        switch type {
        case .restingHeartRate: latestRestingHeartRateUpdate = .failure(error)
        case .wristTemperature: latestWristTemperatureUpdate = .failure(error)
        }
    }

    private func handleWristTemperatureUpdate(update: GenericUpdate) {
        self.latestWristTemperatureUpdate = .success(update)

        guard let averageWristTemperature = averageWristTemperature else {
            // No avg HR, the app cannot do the comparison
            return
        }

        if isHandlingUpdate {
            print("Is already handling an update, adding it to the queue")
            updateQueue.append(update)
            return
        }

        isHandlingUpdate = true

        // Check if the date is later than the last saved rate update
        if let previousUpdate = latestWristTemperatureUpdate, case .success(let res) = previousUpdate {
            guard update.date > res.date else {
                // The update is earlier than the latest, so no need to compare
                // This can be ignored
                isHandlingUpdate = false
                handleNextItemFromQueueIfNeeded()
                return
            }
        }

        // Save the update so its date can be compared to the next updates
        self.latestWristTemperatureUpdate = .success(update)
        let trend: Trend
        let message: String?
        let isAboveAverageWristTemperature = wristTemperatureIsAboveAverage(update: update, average: averageWristTemperature)

        if isAboveAverageWristTemperature {
            if !hasPostedAboutRisingNotificationToday(type: .wristTemperature) {
                trend = .rising
                message = wristTemperatureNotificationMessage(temperature: update.value, averageTemperature: averageWristTemperature)
            } else {
                isHandlingUpdate = false
                handleNextItemFromQueueIfNeeded()
                return
            }

            guard let message = message else { return }

            notificationService.postNotification(
                title: wristTemperatureNotificationTitle(
                    temperature: update.value,
                    averageTemperature: averageWristTemperature),
                body: message) { result in
                    self.isHandlingUpdate = false
                    if case .success = result {
                        self.saveNotificationPostDate(forTrend: trend, type: .wristTemperature)
                    }
                    // If the pending updates queue has more items, process them
                    self.handleNextItemFromQueueIfNeeded()
                }
        }
    }

    /**
     Decides if a notification needs to be sent about the update. If the update isn't above the average, the update will be ignored.
     */
    private func handleHeartRateUpdate(update: GenericUpdate) {
        guard let averageHeartRate = averageHeartRate else {
            // No avg HR, the app cannot do the comparison
            return
        }

        /* It's possible that the HKObserverQuery sends multiple callback simultaneously. Posting notifications is asynchronous,
         which causes the notification sent timestamp to be updated after multiple notifications are sent. To prevent this,
         `isHandlingUpdate` flag is raised while this function handles the notification. The pending updates are added to the
         `updateQueue` array.
         */

        if isHandlingUpdate {
            print("Is already handling an update, adding it to the queue")
            updateQueue.append(update)
            return
        }

        isHandlingUpdate = true

        // Check if the date is later than the last saved rate update
        if let previousUpdate = latestRestingHeartRateUpdate, case .success(let res) = previousUpdate {
            guard update.date > res.date else {
                // The update is earlier than the latest, so no need to compare
                // This can be ignored
                isHandlingUpdate = false
                handleNextItemFromQueueIfNeeded()
                return
            }
        }

        // Save the update so its date can be compared to the next updates
        self.latestRestingHeartRateUpdate = .success(update)

        let isAboveAverageRHR = heartRateIsAboveAverage(update: update, average: averageHeartRate)

        // check if the trend is rising or lowering

        var message: String?
        var trend: Trend?
        if isAboveAverageRHR {
            if !hasPostedAboutRisingNotificationToday(type: .restingHeartRate) {
                trend = .rising
                message = restingHeartRateNotificationMessage(trend: .rising,
                                              heartRate: update.value,
                                              averageHeartRate: averageHeartRate)
            }
        } else {
            // RHR has been high, now it's lowered.
            if !hasPostedAboutLoweredNotificationToday, hasPostedAboutRisingNotificationToday(type: .restingHeartRate) {
                trend = .lowering
                message = restingHeartRateNotificationMessage(trend: .lowering,
                                              heartRate: update.value,
                                              averageHeartRate: averageHeartRate)
            }
        }

        guard let trend = trend, let message = message else {
            isHandlingUpdate = false
            handleNextItemFromQueueIfNeeded()
            return
        }

        notificationService.postNotification(title: restingHeartRateNotificationTitle(trend: trend,
                                                                                      heartRate: update.value,
                                                                                      averageHeartRate: averageHeartRate),
                                             body: message) { result in
            self.isHandlingUpdate = false
            if case .success = result {
                self.saveNotificationPostDate(forTrend: trend, type: .restingHeartRate)
            }
            // If the pending updates queue has more items, process them
            self.handleNextItemFromQueueIfNeeded()
        }
    }

    private func handleNextItemFromQueueIfNeeded() {
        guard !updateQueue.isEmpty else { return }

        print("Handling pending update")
        let update = updateQueue.removeFirst()
        handleUpdate(update: update)
    }

    private func saveNotificationPostDate(forTrend trend: Trend, type: UpdateType) {
        switch type {
        case .restingHeartRate:
            if trend == .rising {
                latestHighRHRNotificationPostDate = Date()
            } else if trend == .lowering {
                latestLoweredRHRNotificationPostDate = Date()
            }
        case .wristTemperature: latestWTNotificationPostDate = Date()
        }
    }

    func restingHeartRateNotificationTitle(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String {
        let emoji = colorEmojiForLevel(heartRateLevelForMultiplier(multiplier: heartRate / averageHeartRate))
        return "\(emoji) \(trend.displayText)"
    }

    func wristTemperatureNotificationTitle(temperature: Double, averageTemperature: Double) -> String {
        return String(format: "Your wrist temperature is elevated: %.1f\(Locale.current.temperatureSymbol)", temperature)
    }

    func wristTemperatureNotificationMessage(temperature: Double, averageTemperature: Double) -> String {
        return String(format: "It's %.1f\(Locale.current.temperatureSymbol) above the average", temperature - averageTemperature)
    }

    func restingHeartRateNotificationMessage(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String? {
        switch trend {
        case .rising:
            return heartRateAnalysisText(current: heartRate, average: averageHeartRate) + " " + "You should slow down."
        case .lowering:
            return "Your resting heart rate returned back to normal. Well done!"
        }
    }

    func hasPostedAboutRisingNotificationToday(type: UpdateType) -> Bool {
        let date: Date?
        switch type {
        case .restingHeartRate: date = latestHighRHRNotificationPostDate
        case .wristTemperature: date = latestWTNotificationPostDate
        }
        guard let date else { return false }

        return calendar.isDateInToday(date)
    }

    var hasPostedAboutLoweredNotificationToday: Bool {
        guard let latestLoweredRHRNotificationPostDate = latestLoweredRHRNotificationPostDate else { return false }

        return calendar.isDateInToday(latestLoweredRHRNotificationPostDate)
    }

    /**
     Sets the app to observe the changes in HealthKit and wake up when there are new RHR updates.
     */
    func observeInBackground(completionHandler: ((Bool, Error?) -> Void)? = nil) {
        let observerQuery = queryProvider.getObserverQuery { query, completionHandler, error in
            if self.shouldStopBackgroundQuery { // store the query hash and compare it here if there's a need to stop a specific queue
                self.healthStore.stop(query)
                completionHandler()
                return
            }

            guard error == nil else { return }

            self.queryLatestMeasurement(type: .restingHeartRate, completionHandler: { result in
                if case .success(let update) = result {
                    self.handleUpdate(update: update)
                }
                completionHandler()
            })

            self.queryLatestMeasurement(type: .wristTemperature, completionHandler: { result in
                if case .success(let update) = result {
                    self.handleUpdate(update: update)
                }
                completionHandler()
            })
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
                completionHandler?(success, error)
            }
    }

    func queryLatestMeasurement(type: UpdateType, completionHandler: @escaping (Result<GenericUpdate, Error>) -> Void) {
        let sampleQuery = queryProvider.getLatestMeasurement(for: type, resultsHandler: { query, results, error in
            self.queryParser.parseLatestRestingHeartRateQueryResults(
                query: query,
                results: results,
                error: error,
                type: type) { result in
                    // Verify the latest update from HealthKit is later than the previously handled.
                    // If not, pass the last handled update instead.
                    // Consider adding a Boolean flag indicating the update is "cached".

                    switch result {
                    case .success(let update):
                        self.handleUpdate(update: update)
                    case .failure(let error):
                        self.handleUpdateFailure(error: error, type: type)
                    }
                    let latestUpdateForType: Result<GenericUpdate, any Error>?
                    switch type {
                    case .restingHeartRate: latestUpdateForType = self.latestRestingHeartRateUpdate
                    case .wristTemperature: latestUpdateForType = self.latestWristTemperatureUpdate
                    }

                    if case .success(let update) = result, let latestUpdateForType = latestUpdateForType, case .success(let latestUpdate) = latestUpdateForType {
                        if update.date > latestUpdate.date {
                            completionHandler(.success(update))
                        } else {
                            completionHandler(.success(latestUpdate))
                        }
                    } else {
                        completionHandler(result)
                    }
                }
        })

        healthStore.execute(sampleQuery)
    }

    // MARK: - HealthKit permissions

    func requestAuthorisation(completion: @escaping (Bool, Error?) -> Void) {
        let rhr = Set([HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
                       HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!])
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

    // MARK: - Average resting heart rate data for chart
    func fetchRestingHeartRateHistory(startDate: Date, completion: @escaping (Result<RestingHeartRateHistory, Error>) -> Void) {
        let now = Date()

        let query = queryProvider.getRestingHeartRateHistogramQuery()
        query.initialResultsHandler = { query, results, error in
            self.queryParser.parseRestingHeartRateHistogram(startDate: startDate,
                                                            endDate: now,
                                                            query: query,
                                                            result: results,
                                                            error: error,
                                                            callback: { result in
                completion(result)
            })
        }
        healthStore.execute(query)
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

    func heartRateLevelForMultiplier(multiplier: Double) -> HeartRateLevel {
        if multiplier > 1.05 {
            if multiplier > 1.2 {
                return .wayAboveElevated
            } else if multiplier > 1.1 {
                return .noticeablyElevated
            } else {
                return .slightlyElevated
            }
        } else if multiplier < 0.95 {
            return .belowAverage
        } else {
            return .normal
        }
    }

    func rangesForHeartRateLevels(average: Double) -> HeartRateRanges {
        let ranges: [HeartRateLevel: Range<Double>] = [
            .belowAverage: 0..<(average * (1 - thresholdMultiplier)),
            .normal: (average * (1 - thresholdMultiplier))..<average + (average * thresholdMultiplier),
            .slightlyElevated: average + (average * thresholdMultiplier)..<average + (average * 2 * thresholdMultiplier),
            .noticeablyElevated: average + (average * 2 * thresholdMultiplier)..<average + (average * 4 * thresholdMultiplier),
            .wayAboveElevated: average + (average * 4 * thresholdMultiplier)..<Double.infinity
        ]
        return HeartRateRanges(ranges: ranges)
    }

    // MARK: - Background observer

    var shouldStopBackgroundQuery: Bool {
        return !backgroundObserverQueryEnabled
    }
}
// swiftlint: enable type_body_length

struct RestingHeartRateHistory {
    let histogramItems: [RestingHeartRateHistogramItem]

    var maximumValue: Int {
        return histogramItems.map {$0.count}.max() ?? 0
    }
}

struct RestingHeartRateHistogramItem: Hashable {
    let item: Int
    let count: Int
}

struct HeartRateRanges {
    let ranges: [HeartRateLevel: Range<Double>]
    func levelForRestingHeartRate(rate: Double) -> HeartRateLevel? {
        return ranges.first(where: { $0.value.contains(rate) })?.key
    }
}

enum HeartRateLevel {
    case belowAverage
    case normal
    case slightlyElevated
    case noticeablyElevated
    case wayAboveElevated
}
