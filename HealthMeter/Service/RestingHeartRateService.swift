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

/**
 Protocol for providing the latest and average values.
 */
protocol RestingHeartRateProvider: AnyObject {
    var averageHeartRatePublished: Double? { get }
    var averageWristTemperaturePublished: Double? { get }

    var averageWristTemperature: Double? { get }
    var averageHeartRate: Double? { get }
    var averageHRV: Double? { get }

    var latestRestingHeartRateUpdate: Result<GenericUpdate, Error>? { get }
    var latestWristTemperatureUpdate: Result<GenericUpdate, Error>? { get }
}

// swiftlint: disable type_body_length
/**
 Handles the fetching and providing the HealthKit queries while being a wrapper over HealthKit without exposing it to the rest of the app.
 */
class RestingHeartRateService: ObservableObject, RestingHeartRateProvider {
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

    private let latestRestingHeartRateUpdateKey = "LatestRestingHeartRateUpdate"
    private let latestWristTemperatureUpdateKey = "LatestWristTemperatureUpdate"
    private let latestHrvUpdateKey = "LatestHrvUpdate"

    private let backgroundObserverQueryEnabledKey = "BackgroundObserverQueryEnabledKey"

    @Published private(set) var latestRestingHeartRateUpdate: Result<GenericUpdate, Error>?
    @Published private(set) var latestWristTemperatureUpdate: Result<GenericUpdate, Error>?
    @Published private(set) var latestHRVUpdate: Result<GenericUpdate, Error>?

    @Published private(set) var averageHeartRatePublished: Double?
    @Published private(set) var averageWristTemperaturePublished: Double?
    @Published private(set) var averageHRVPublished: Double?

    // Dependencies
    private let calendar: Calendar
    private let healthStore: HKHealthStore

    ///  Provides the queries for the HKHealthStore to execute
    private let queryProvider: QueryProvider

    /// Parses the query responses
    private let queryParser: QueryParser

    /// Updates are passed to decisonManager. It decides whether or not a push notification should be sent.
    private let decisionManager: DecisionManager

    /// Background observer queries for each HealthKit update type
    private var observerQueries: [UpdateType: HKObserverQuery] = [:]

    /// Two month average
    private(set) var averageHeartRate: Double? {
        get {
            guard let avg = userDefaults.object(forKey: userDefaultsKeyForUpdateType(type: .restingHeartRate)) else { return nil }
            return avg as? Double
        }
        set {
            userDefaults.set(newValue, forKey: userDefaultsKeyForUpdateType(type: .restingHeartRate))
            averageHeartRatePublished = newValue
        }
    }

    /// Two month average
    private(set) var averageWristTemperature: Double? {
        get {
            guard let avg = userDefaults.object(forKey: userDefaultsKeyForUpdateType(type: .wristTemperature)) else { return nil }
            return avg as? Double
        }
        set {
            userDefaults.set(newValue, forKey: userDefaultsKeyForUpdateType(type: .wristTemperature))
            DispatchQueue.main.async {
                self.averageWristTemperaturePublished = newValue
                self.objectWillChange.send()
            }
        }
    }

    /// Two month average
    private(set) var averageHRV: Double? {
        get {
            guard let avg = userDefaults.object(forKey: userDefaultsKeyForUpdateType(type: .hrv)) else { return nil }
            return avg as? Double
        }
        set {
            userDefaults.set(newValue, forKey: userDefaultsKeyForUpdateType(type: .hrv))
            DispatchQueue.main.async {
                self.averageHRVPublished = newValue
                self.objectWillChange.send()
            }
        }
    }

    var backgroundObserverQueryEnabled: Bool {
        get {
            return userDefaults.bool(forKey: backgroundObserverQueryEnabledKey)
        } set {
            userDefaults.set(newValue, forKey: backgroundObserverQueryEnabledKey)
            observerQueries.forEach { keyValue in
                print("stopping observer query: \(keyValue.value)")
                healthStore.stop(keyValue.value)
            }
            observerQueries.removeAll()
            if newValue == true {
                UpdateType.allCases.forEach { type in
                    observeInBackground(type: type)
                }
            }
        }
    }

    /// Two months
    private var averageTimeInterval: TimeInterval {
        return -60 * 60 * 24 * 60
    }

    init(userDefaults: UserDefaults = UserDefaults.standard,
         calendar: Calendar = Calendar.current,
         healthStore: HKHealthStore = HKHealthStore(),
         queryProvider: QueryProvider = QueryProvider(),
         queryParser: QueryParser = QueryParser(),
         decisionManager: DecisionManager = DecisionManager(decisionEngine: DecisionEngineImplementation())) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.healthStore = healthStore
        self.queryProvider = queryProvider
        self.queryParser = queryParser
        self.decisionManager = decisionManager

        decisionManager.restingHeartRateProvider = self

        self.latestRestingHeartRateUpdate = decodeLatestUpdate(ofType: .restingHeartRate)
        self.latestWristTemperatureUpdate = decodeLatestUpdate(ofType: .wristTemperature)

        userDefaults.register(defaults: [backgroundObserverQueryEnabledKey: true])
    }

    /**
     Decodes the latest RHR update from UserDefaults
     */
    private func decodeLatestUpdate(ofType type: UpdateType) -> Result<GenericUpdate, Error>? {
        let key: String
        switch type {
        case .restingHeartRate: key = latestRestingHeartRateUpdateKey
        case .wristTemperature: key = latestWristTemperatureUpdateKey
        case .hrv: key = latestHrvUpdateKey
        }
        guard let data = userDefaults.data(forKey: key) else { return nil }

        let decoder = JSONDecoder()
        do {
            let update = try decoder.decode(GenericUpdate.self, from: data)
            return .success(update)
        } catch {
            // Remove the object as it might be an incompatible with the earlier version
            print("Decoding of an object with UserDefaults key of \(key) failed with an error: \(error). Removing it from the UserDefaults")
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }

    func queryAverageOfType(_ type: UpdateType, callback: @escaping (Result<Double, Error>) -> Void) {
        let now = Date()
        let queryStartDate = now.addingTimeInterval(averageTimeInterval)
        let query = queryProvider.getAverageOfType(type, queryStartDate: queryStartDate)

        query.initialResultsHandler = { query, results, error in
            self.queryParser.parseAverageResults(type: type, startDate: queryStartDate, endDate: now, query: query, result: results, error: error) { result in
                if case .success(let value) = result {
                    switch type {
                    case .restingHeartRate: self.averageHeartRate = value
                    case .wristTemperature: self.averageWristTemperature = value
                    case .hrv: self.averageHRV = value
                    }
                }
                callback(result)
            }
        }
        healthStore.execute(query)
    }

    func handleUpdate(update: GenericUpdate) {
        switch update.type {
        case .restingHeartRate: handleHeartRateUpdate(update: update)
        case .wristTemperature: handleWristTemperatureUpdate(update: update)
        case .hrv: handleHRVUpdate(update: update)
        }
    }
    func handleUpdateFailure(error: Error, type: UpdateType) {
        switch type {
        case .restingHeartRate: latestRestingHeartRateUpdate = .failure(error)
        case .wristTemperature: latestWristTemperatureUpdate = .failure(error)
        case .hrv: latestHRVUpdate = .failure(error)
        }
    }

    private func handleWristTemperatureUpdate(update: GenericUpdate) {
        if case .success(let previousUpdate) = latestWristTemperatureUpdate {
            if update.date > previousUpdate.date {
                decisionManager.handleUpdate(update: update)
                self.latestWristTemperatureUpdate = .success(update)
            }
        } else {
            decisionManager.handleUpdate(update: update)
            self.latestWristTemperatureUpdate = .success(update)
        }
    }

    private func handleHRVUpdate(update: GenericUpdate) {
        if case .success(let previousUpdate) = latestHRVUpdate {
            if update.date > previousUpdate.date {
                decisionManager.handleUpdate(update: update)
                self.latestHRVUpdate = .success(update)
            }
        } else {
            decisionManager.handleUpdate(update: update)
            self.latestHRVUpdate = .success(update)
        }
    }

    /**
     Decides if a notification needs to be sent about the update. If the update isn't above the average, the update will be ignored.
     */
    private func handleHeartRateUpdate(update: GenericUpdate) {
        if case .success(let previousUpdate) = latestRestingHeartRateUpdate {
            if update.date > previousUpdate.date {
                decisionManager.handleUpdate(update: update)
                self.latestRestingHeartRateUpdate = .success(update)
            }
        } else {
            decisionManager.handleUpdate(update: update)
            self.latestRestingHeartRateUpdate = .success(update)
        }
    }

    /**
     Sets the app to observe the changes in HealthKit and wake up when there are new RHR updates.
     */
    func observeInBackground(type: UpdateType, completionHandler: ((Bool, Error?) -> Void)? = nil) {
        let observerQuery = queryProvider.getObserverQuery(type: type) { query, completionHandler, error in
            if self.shouldStopBackgroundQuery { // store the query hash and compare it here if there's a need to stop a specific queue
                self.healthStore.stop(query)
                completionHandler()
                return
            }

            guard error == nil else { return }

            self.queryLatestMeasurement(type: type, completionHandler: { result in
                if case .success(let update) = result {
                    self.handleUpdate(update: update)
                }
                completionHandler()
            })
        }
        healthStore.execute(observerQuery)

        healthStore.enableBackgroundDelivery(
            for: queryProvider.sampleTypeFor(type),
            frequency: .hourly) { success, error in
                if success {
                    print("BG observation successful for type \(type)")
                    self.observerQueries[type] = observerQuery
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
                    case .hrv: latestUpdateForType = self.latestHRVUpdate
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
                       HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
                       HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!])
        healthStore.requestAuthorization(toShare: [], read: rhr) { (success, error) in
            completion(success, error)
        }
    }

    func getAuthorisationStatusForRestingHeartRate(completion: @escaping (HealthKitAuthorisationStatus) -> Void) {
        let rhr = Set([HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
                       HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
                       HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
                      ])
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

    // MARK: - UserDefaults handling
    func userDefaultsKeyForUpdateType(type: UpdateType) -> String {
        return "average_\(type.name)_key"
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
