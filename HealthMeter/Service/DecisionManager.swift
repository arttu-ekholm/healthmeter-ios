//
//  DecisionManager.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 14.8.2023.
//

import Foundation

/**
 Handles decisions about the health updates
 */
class DecisionManager {
    // Dependencies
    let notificationService: NotificationService
    let calendar: Calendar
    let userDefaults: UserDefaults
    let decisionEngine: DecisionEngine

    // UserDefault keys
    private let latestHighRHRNotificationPostDateKey = "LatestHighRHRNotificationPostDate"
    private let latestHighWTNotificationPostDateKey = "LatestHighWTNotificationPostDateKey"
    private let latestLoweredRHRNotificationPostDateKey = "LatestLoweredRHRNotificationPostDate"

    /**
     if `true`, the manager is handling a `RestingHeartRateUpdate`. Set to `true` when handling begins, and to `false`when the function either
     decides to ignore the update, or when the `NotificationCenter` callback tells the notification is handled.
     */
    private var isHandlingUpdate = false

    /// Pending updates that aren't handled yet. Used to resolve the issue where there can be multiple simultaneous `RestingHeartRateUpdate`s.
    private var updateQueue: [GenericUpdate] = []

    weak var restingHeartRateProvider: RestingHeartRateProvider?

    private func handleNextItemFromQueueIfNeeded() {
        guard !updateQueue.isEmpty else { return }

        print("Handling pending update")
        let update = updateQueue.removeFirst()
        handleUpdate(update: update)
    }

    init(notificationService: NotificationService = NotificationService(),
         calendar: Calendar = .current,
         userDefaults: UserDefaults = .standard,
         decisionEngine: DecisionEngine = DecisionEngineImplementation()) {
        self.notificationService = notificationService
        self.calendar = calendar
        self.userDefaults = userDefaults
        self.decisionEngine = decisionEngine
    }

    func handleUpdate(update: GenericUpdate) {
        switch update.type {
        case .wristTemperature: handleWristTemperatureUpdate(update: update)
        case .restingHeartRate: handleRestingHeartRateUpdate(update: update)
        }
    }

    private func handleRestingHeartRateUpdate(update: GenericUpdate) {
        guard let provider = restingHeartRateProvider else { return }

        guard let averageHeartRate = provider.averageHeartRate else {
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
        if let previousUpdate = provider.latestRestingHeartRateUpdate, case .success(let res) = previousUpdate {
            guard update.date > res.date else {
                // The update is earlier than the latest, so no need to compare
                // This can be ignored
                isHandlingUpdate = false
                handleNextItemFromQueueIfNeeded()
                return
            }
        }

        let isAboveAverageRHR = decisionEngine.heartRateIsAboveAverage(update: update, average: averageHeartRate)

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

    private func handleWristTemperatureUpdate(update: GenericUpdate) {
        guard let provider = restingHeartRateProvider else {
            print("DecisionManager is missing RestingHeartRateProvider")
            return
        }

        if isHandlingUpdate {
            print("Is already handling an update, adding the update to the queue")
            updateQueue.append(update)
            return
        }

        guard let averageWristTemperature = provider.averageWristTemperature else {
            // No avg HR, the app cannot do the comparison
            return
        }

        isHandlingUpdate = true

        let trend: Trend
        let message: String?
        let isAboveAverageWristTemperature = decisionEngine.wristTemperatureIsAboveAverage(update: update, average: averageWristTemperature)

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

    func wristTemperatureNotificationMessage(temperature: Double, averageTemperature: Double) -> String {
        return String(format: "It's %.1f°\(Locale.current.temperatureSymbol) above the average", temperature - averageTemperature)
    }

    func restingHeartRateNotificationMessage(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String? {
        switch trend {
        case .rising:
            return heartRateAnalysisText(current: heartRate, average: averageHeartRate) + " " + "You should slow down."
        case .lowering:
            return "Your resting heart rate returned back to normal. Well done!"
        }
    }

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

    func restingHeartRateNotificationTitle(trend: Trend, heartRate: Double, averageHeartRate: Double) -> String {
        let emoji = colorEmojiForLevel(heartRateLevelForMultiplier(multiplier: heartRate / averageHeartRate))
        return "\(emoji) \(trend.displayText)"
    }

    func wristTemperatureNotificationTitle(temperature: Double, averageTemperature: Double) -> String {
        return String(format: "Your wrist temperature is elevated: %.1f°\(Locale.current.temperatureSymbol)", temperature)
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
}

/**
    Collection of decision that can be shared between the notification decisions and the view model logic.
 */
protocol DecisionEngine {
    func wristTemperatureIsAboveAverage(update: GenericUpdate, average: Double) -> Bool
    func heartRateIsAboveAverage(update: GenericUpdate, average: Double) -> Bool
}

class DecisionEngineImplementation: DecisionEngine {
    let locale: Locale

    init (locale: Locale = .current) {
        self.locale = locale
    }

    func wristTemperatureIsAboveAverage(update: GenericUpdate, average: Double) -> Bool {
        guard update.type == .wristTemperature else { return false }

        if locale.measurementSystem == .us {
            return update.value - average > 1.8
        } else {
            return update.value - average > 1.0
        }
    }

    /**
     - returns true if the heart rate is above the average
     */
    func heartRateIsAboveAverage(update: GenericUpdate, average: Double) -> Bool {
        return update.value / average > threshold
    }

    // If the latest update is this much above the avg. RHR, the notification will be triggered.
    var threshold: Double {
        return 1 + thresholdMultiplier
    }

    var thresholdMultiplier: Double {
        return 0.05
    }
}