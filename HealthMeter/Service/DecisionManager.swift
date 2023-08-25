//
//  DecisionManager.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 14.8.2023.
//

import Foundation

/**
 Handles decisions about the health updates - whether or not to post a push notification.
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

    private let latestHRVNotificationPostDateKey = "LatestHRVNotificationPostDate"

    /// Pending updates that aren't handled yet. Used to resolve the issue where there can be multiple simultaneous `RestingHeartRateUpdate`s.
    private var updateQueue: [GenericUpdate] = []
    private var currentUpdate: GenericUpdate?

    /**
     if `true`, the manager is handling a `RestingHeartRateUpdate`. Set to `true` when handling begins, and to `false`when the function either
     decides to ignore the update, or when the `NotificationCenter` callback tells the notification is handled.
     */
    private var isHandlingUpdate: Bool {
        return currentUpdate != nil
    }

    weak var restingHeartRateProvider: RestingHeartRateProvider?

    private func handleNextItemFromQueueIfNeeded() {
        guard !updateQueue.isEmpty else {
            print("No pending updates")
            return
        }

        let update = updateQueue.removeFirst()
        print("Handling pending update \(update)")
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
        case .hrv: handleHRVUpdate(update: update)
        }
    }

    private func handleRestingHeartRateUpdate(update: GenericUpdate) {
        /* It's possible that the HKObserverQuery sends multiple callback simultaneously. Posting notifications is asynchronous,
         which causes the notification sent timestamp to be updated after multiple notifications are sent. To prevent this,
         `isHandlingUpdate` flag is raised while this function handles the notification. The pending updates are added to the
         `updateQueue` array.
         */

        if isHandlingUpdate {
            updateQueue.append(update)
            return
        }

        guard let provider = restingHeartRateProvider, let averageHeartRate = provider.averageHeartRate else {
            handleNextItemFromQueueIfNeeded()
            return
        }

        self.currentUpdate = update

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
            self.currentUpdate = nil
            handleNextItemFromQueueIfNeeded()
            return
        }

        notificationService.postNotification(title: restingHeartRateNotificationTitle(trend: trend,
                                                                                      heartRate: update.value,
                                                                                      averageHeartRate: averageHeartRate),
                                             body: message) { result in
            self.currentUpdate = nil
            if case .success = result {
                self.saveNotificationPostDate(forTrend: trend, type: .restingHeartRate)
            }
            self.handleNextItemFromQueueIfNeeded()
        }
    }

    private func handleWristTemperatureUpdate(update: GenericUpdate) {
        if isHandlingUpdate {
            print("Is already handling an update, adding the update \(update) to the queue")
            updateQueue.append(update)
            return
        }

        guard let provider = restingHeartRateProvider, let averageWristTemperature = provider.averageWristTemperature else {
            handleNextItemFromQueueIfNeeded()
            return
        }

        currentUpdate = update

        let trend: Trend
        let message: String?
        let isAboveAverageWristTemperature = decisionEngine.wristTemperatureIsAboveAverage(update: update, average: averageWristTemperature)

        if isAboveAverageWristTemperature, !hasPostedAboutRisingNotificationToday(type: .wristTemperature) {
                trend = .rising
                message = wristTemperatureNotificationMessage(temperature: update.value, averageTemperature: averageWristTemperature)

            guard let message = message else {
                currentUpdate = nil
                handleNextItemFromQueueIfNeeded()
                return
            }

            notificationService.postNotification(
                title: wristTemperatureNotificationTitle(
                    temperature: update.value,
                    averageTemperature: averageWristTemperature),
                body: message) { result in
                    self.currentUpdate = nil
                    if case .success = result {
                        self.saveNotificationPostDate(forTrend: trend, type: .wristTemperature)
                    }
                    // If the pending updates queue has more items, process them
                    self.handleNextItemFromQueueIfNeeded()
                }
        } else {
            currentUpdate = nil
            handleNextItemFromQueueIfNeeded()
        }
    }

    private func handleHRVUpdate(update: GenericUpdate) {
        if isHandlingUpdate {
            print("Is already handling an update, adding the update \(update) to the queue")
            updateQueue.append(update)
            return
        }

        guard let provider = restingHeartRateProvider, let averageHRV = provider.averageHRV else {
            handleNextItemFromQueueIfNeeded()
            return
        }

        currentUpdate = update

        let trend: Trend
        let message: String?
        let isBelowAverageHRV = decisionEngine.hrvIsBelowAverage(update: update, average: averageHRV)

        if isBelowAverageHRV, !hasPostedAboutRisingNotificationToday(type: .hrv) {
                trend = .rising
                message = hrvNotificationMessage(hrv: update.value, averageHRV: averageHRV)

            guard let message = message else {
                currentUpdate = nil
                handleNextItemFromQueueIfNeeded()
                return
            }

            notificationService.postNotification(
                title: hrvNotificationTitle(
                    temperature: update.value,
                    averageTemperature: averageHRV),
                body: message) { result in
                    self.currentUpdate = nil
                    if case .success = result {
                        self.saveNotificationPostDate(forTrend: trend, type: .hrv)
                    }
                    // If the pending updates queue has more items, process them
                    self.handleNextItemFromQueueIfNeeded()
                }
        } else {
            currentUpdate = nil
            handleNextItemFromQueueIfNeeded()
        }
    }

    func hasPostedAboutRisingNotificationToday(type: UpdateType) -> Bool {
        let date: Date?
        switch type {
        case .restingHeartRate: date = latestHighRHRNotificationPostDate
        case .wristTemperature: date = latestWTNotificationPostDate
        case .hrv: date = latestHRVNotificationPostDate
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

    func hrvNotificationMessage(hrv: Double, averageHRV: Double) -> String {
        return "You might be stressed"
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

    func hrvNotificationTitle(temperature: Double, averageTemperature: Double) -> String {
        return "Your heart rate variable is below your average."
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
        case .hrv: latestHRVNotificationPostDate = Date()
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

    var latestHRVNotificationPostDate: Date? {
        get {
            return userDefaults.object(forKey: latestHRVNotificationPostDateKey) as? Date
        } set {
            userDefaults.set(newValue, forKey: latestHRVNotificationPostDateKey)
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
