//
//  RestingHeartRateServiceTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 26.1.2022.
//

import XCTest
@testable import HealthMeter
import HealthKit

// swiftlint:disable:next type_body_length
class RestingHeartRateServiceTests: XCTestCase {
    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults?.removePersistentDomain(forName: #file)
        userDefaults = UserDefaults(suiteName: #file)
    }

    override func tearDown() {
        super.tearDown()

        userDefaults.removePersistentDomain(forName: #file)
    }

    // MARK: - Tests

    func testAboveAverage() {
        let service = RestingHeartRateService()

        XCTAssertTrue(service.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 70.0,
                type: .restingHeartRate),
            average: 55.0), "Should be significant difference")
        XCTAssertFalse(service.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 55.0,
                type: .restingHeartRate),
            average: 55.0), "Should be significant difference")
        XCTAssertFalse(service.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 53.0,
                type: .restingHeartRate),
            average: 55.0), "Below average should return false")
        XCTAssertFalse(service.heartRateIsAboveAverage(
            update: GenericUpdate(
                date: Date(),
                value: 10.0,
                type: .restingHeartRate),
            average: 55.0), "Below average should return false")
    }

    func testUpdate_noNotificationIfAvgHRMissing() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: mockNotificationService)
        let update = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        XCTAssertFalse(mockNotificationService.postNotificationCalled, "Notification shouldn't be sent if there is no average heart rate")
    }

    func testDecodingAverageHeartRate_launch() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        XCTAssertNil(service.averageHeartRate, "AVG RHR should be nil.")
    }

    func testDecodingAverageHeartRate_notNil() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")
        let avgRHR = try XCTUnwrap(service.averageHeartRate)
        XCTAssertEqual(50.0, avgRHR, accuracy: 0.1, "AVG RHR should be 50.0")
    }

    func testPosted_rising() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(
            userDefaults: userDefaults,
            notificationService: mockNotificationService)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = GenericUpdate(date: Date(), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        let predicate = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }
        _ = expectation(for: predicate, evaluatedWith: service, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testPosted_risingToLowered() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(
            userDefaults: userDefaults,
            notificationService: mockNotificationService)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate = GenericUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: risingUpdate)
        let loweringUpdate = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: loweringUpdate)

        let risingNotificationCalled = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }

        let loweredNotificationCalled = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return service.hasPostedAboutLoweredNotificationToday
        }
        _ = expectation(for: risingNotificationCalled, evaluatedWith: service, handler: .none)
        _ = expectation(for: loweredNotificationCalled, evaluatedWith: service, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    /**
     Handling and update that == qvg RHR doesn't cause any notifications being posted
     */
    func testPosting_averageRHR() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        XCTAssertFalse(service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate))
        XCTAssertFalse(service.hasPostedAboutLoweredNotificationToday)
    }

    /**
     Service gets high, average, high average resting rate. The app should post notification about one about rising HRH, and one about lowered RHR.
     */
    func testPosted_multiple() throws {
        let notificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: notificationService)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate1 = GenericUpdate(date: Date().addingTimeInterval(-60*60*3), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: risingUpdate1)
        let loweringUpdate1 = GenericUpdate(date: Date().addingTimeInterval(-60*60*2), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: loweringUpdate1)
        let risingUpdate2 = GenericUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: risingUpdate2)
        let loweringUpdate2 = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        service.handleUpdate(update: loweringUpdate2)
        XCTAssertEqual(notificationService.postNotificationCalledCount, 2, "Only two notifications should be sent - one for high RHR and and another for lowered RRH")

        XCTAssertTrue(service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate))
        XCTAssertTrue(service.hasPostedAboutLoweredNotificationToday)
    }

    // MARK: - HealthStore queries

    func testObserveInBackground_functionsCalled() {
        let mockHealthStore = MockHealthStore()
        let service = RestingHeartRateService(userDefaults: userDefaults, healthStore: mockHealthStore)
        service.observeInBackground { _, _ in }
        XCTAssertTrue(mockHealthStore.executeQueryCalled)
        XCTAssertTrue(mockHealthStore.enableBackgroundDeliveryCalled)
    }

    func testObserveInBackground_latestQuerySuccessfullyCalled() {
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let mockQueryParser = MockQueryParser()
        mockQueryParser.update = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider,
                                              queryParser: mockQueryParser)
        let predicate = NSPredicate { parser, _ in
            guard let parser = parser as? MockQueryParser else { return false }
            return parser.queryResultsCalled
        }
        _ = expectation(for: predicate, evaluatedWith: mockQueryParser, handler: .none)

        service.observeInBackground(completionHandler: { _, _ in })
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    /**
     Test observeInBackground -> High RHR -> handleUpdate -> notification is posted pipeline works
     */
    func testObserveInBackground_successfulUpdateHandled() {
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let mockQueryParser = MockQueryParser()
        let mockNotificationService = MockNotificationService()
        mockQueryParser.update = GenericUpdate(date: Date(), value: 100.0, type: .restingHeartRate)
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              notificationService: mockNotificationService,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider,
                                              queryParser: mockQueryParser)
        let predicate = NSPredicate { mockNotificationService, _ in
            guard let mockNotificationService = mockNotificationService as? MockNotificationService else { return false }
            return mockNotificationService.postNotificationCalled
        }
        _ = expectation(for: predicate, evaluatedWith: mockNotificationService, handler: .none)

        service.observeInBackground(completionHandler: { _, _ in })
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testQueryLatestRestingHeartRate_healthStoreCalled() {
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let service = RestingHeartRateService(userDefaults: userDefaults, healthStore: mockHealthStore, queryProvider: mockQueryProvider)
        service.queryLatestMeasurement(type: .restingHeartRate) { _ in }
        XCTAssertTrue(mockHealthStore.executeQueryCalled)
    }

    func testQueryLatestRestingHeartRate_completionBlock_emptySamples() {
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider)
        let expectation = expectation(description: "No samples should result in an error.")
        service.queryLatestMeasurement(type: .restingHeartRate) { result in
            if case .failure(let error) = result, error is QueryParser.QueryParserError {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testQueryLatestRestingHeartRate_completionBlock_error() {
        let mockHealthStore = MockHealthStore()
        mockHealthStore.mockError = TestError.genericError
        let mockQueryProvider = MockQueryProvider()
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider)
        let expectation = expectation(description: "Query should fail with an error.")
        service.queryLatestMeasurement(type: .restingHeartRate) { result in
            if case .failure(let error) = result, error is TestError {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testQueryLatestRestingHeartRate_completionBlock_samples() {
        let mockHealthStore = MockHealthStore()
        mockHealthStore.mockSamples = nil
        let mockQueryProvider = MockQueryProvider()
        let mockQueryParser = MockQueryParser()
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider,
                                              queryParser: mockQueryParser)
        mockQueryParser.update = GenericUpdate(date: Date(), value: 50.0, type: .restingHeartRate)
        let expectation = expectation(description: "queryLatestRestingHeartRate's result should be success")
        service.queryLatestMeasurement(type: .restingHeartRate) { result in
            if case .success = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testQueryRestingHeartRate() throws {
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let mockQueryParser = MockQueryParser()
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider,
                                              queryParser: mockQueryParser)
        let expectation = expectation(description: "RHR query should fail if there isn't any results")

        service.queryAverageRestingHeartRate { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    // MARK: - Analysis text

    func testAnalysisText_normal() {
        let service = RestingHeartRateService()
        let normalRestingHeartRateText = "Your resting heart rate is normal."
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 50, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 52, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 51, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 49, average: 50))
        XCTAssertEqual(normalRestingHeartRateText, service.heartRateAnalysisText(current: 48, average: 50))
    }

    func testAnalysisText_slightlyAbove() {
        let service = RestingHeartRateService()
        let text = "Your resting heart rate is slightly above your average."
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 60, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 61, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 62, average: 57))
    }

    func testAnalysisText_slightlyBelow() {
        let service = RestingHeartRateService()
        let text = "Your resting heart rate is slightly below your average."
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 54, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 53, average: 57))
        XCTAssertEqual(text, service.heartRateAnalysisText(current: 52, average: 57))
    }

    func testAnalysisText_noticeablyHigher() {
        let service = RestingHeartRateService()
        let string = "Your resting heart rate is noticeably above your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 55, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 56, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 58, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 59, average: 50))
    }

    func testAnalysisText_noticeablyLower() {
        let service = RestingHeartRateService()
        let string = "Your resting heart rate is noticeably below your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 45, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 44, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 43, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 42, average: 50))
    }

    func testAnalysisText_muchHigher() {
        let service = RestingHeartRateService()
        let string = "Your resting heart rate is way above your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 65, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 70, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 90, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 100, average: 50))
    }

    func testAnalysisText_muchLower() {
        let service = RestingHeartRateService()
        let string = "Your resting heart rate is way below your average."
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 40, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 30, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 20, average: 50))
        XCTAssertEqual(string, service.heartRateAnalysisText(current: 1, average: 50))
    }

    func testMultipleObserverQueryCallbacks() {
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let mockQueryParser = MockQueryParser()
        let mockNotificationService = MockNotificationService()
        mockNotificationService.delay = 2.0

        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              notificationService: mockNotificationService,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider,
                                              queryParser: mockQueryParser)

        let now = Date()
        service.handleUpdate(update: GenericUpdate(date: now, value: 120.0, type: .restingHeartRate))
        service.handleUpdate(update: GenericUpdate(date: now, value: 120.0, type: .restingHeartRate))
        service.handleUpdate(update: GenericUpdate(date: now, value: 120.0, type: .restingHeartRate))
        service.handleUpdate(update: GenericUpdate(date: now, value: 120.0, type: .restingHeartRate))
        service.handleUpdate(update: GenericUpdate(date: now, value: 120.0, type: .restingHeartRate))
        service.handleUpdate(update: GenericUpdate(date: now, value: 120.0, type: .restingHeartRate))

        let predicate = NSPredicate { mockNotificationService, _ in
            guard let mockNotificationService = mockNotificationService as? MockNotificationService else { return false }

            return mockNotificationService.postNotificationCalledCount == 1
        }

        _ = expectation(for: predicate, evaluatedWith: mockNotificationService, handler: .none)

        waitForExpectations(timeout: 3.0, handler: .none)
    }

    /**
     When the service has a latest saved date and a new update with **earlier** date is handled, the latest handled date should be returned instead
     */
    func testHandleHKUpdate_previousThanStored() throws {
        let now = Date()
        let latestUpdate = GenericUpdate(date: now, value: 50.0, type: .restingHeartRate)
        let data = try XCTUnwrap(JSONEncoder().encode(latestUpdate))
        userDefaults.set(data, forKey: "LatestRestingHeartRateUpdate")

        let service = RestingHeartRateService(
            userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        // The update has _earlier_ date than the latest handled update.
        let update = GenericUpdate(date: Date().addingTimeInterval(-100), value: 100.0, type: .restingHeartRate)
        service.handleUpdate(update: update)

        let predicate = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return !service.hasPostedAboutRisingNotificationToday(type: .restingHeartRate)
        }
        _ = expectation(for: predicate, evaluatedWith: service, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    // MARK: - Multipliers and colors
    func testHeartRateLevelForMultiplier() {
        let service = RestingHeartRateService()
        XCTAssertEqual(service.heartRateLevelForMultiplier(multiplier: 50.0/50.0), .normal)
        XCTAssertEqual(service.heartRateLevelForMultiplier(multiplier: 20.0/50.0), .belowAverage)
        XCTAssertEqual(service.heartRateLevelForMultiplier(multiplier: 55.0/50.0), .slightlyElevated)
        XCTAssertEqual(service.heartRateLevelForMultiplier(multiplier: 60.0/50.0), .noticeablyElevated)
        XCTAssertEqual(service.heartRateLevelForMultiplier(multiplier: 85.0/50.0), .wayAboveElevated)
    }

    func testNotificationTitleContainsColorEmoji() {
        let service = RestingHeartRateService()
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .lowering, heartRate: 30, averageHeartRate: 50).contains("🟩"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 50, averageHeartRate: 50).contains("🟩"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 53, averageHeartRate: 50).contains("🟨"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 56, averageHeartRate: 50).contains("🟧"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 70, averageHeartRate: 50).contains("🟥"))
        XCTAssertTrue(service.restingHeartRateNotificationTitle(trend: .rising, heartRate: 100, averageHeartRate: 50).contains("🟥"))
    }
}

// MARK: - Mock classes

private class MockHealthStore: HKHealthStore {
    var executeQueryCalled = false
    var enableBackgroundDeliveryCalled = false

    var mockSamples: [HKSample]?
    var mockError: Error?

    var mockObserverQueryCompletionHandler: () -> Void = { }

    override func execute(_ query: HKQuery) {
        executeQueryCalled = true
        if let mockQuery = query as? MockSampleQuery {
            mockQuery.mockResultHandler?(mockQuery, mockSamples, mockError)
        } else if let mockObserverQuery = query as? MockObserverQuery {
            mockObserverQuery.mockResultHandler?(mockObserverQuery, mockObserverQueryCompletionHandler, mockError)
        } else if let mockStatisticQuery = query as? MockStatisticCollectionQuery {
            // HKStatisticCollection cannot be subclassed
            mockStatisticQuery.initialResultsHandler?(mockStatisticQuery, nil, mockError)
        }
    }

    override func enableBackgroundDelivery(
        for type: HKObjectType,
        frequency: HKUpdateFrequency,
        withCompletion completion: @escaping (Bool, Error?) -> Void) {
            enableBackgroundDeliveryCalled = true
        }
}

private class MockQueryProvider: QueryProvider {
    var getLatestRestingHeartRateQueryCalled = false
    var getObserverQueryCalled = false

    var mockResultHandler: ((HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void)?

    override func getLatestMeasurement(for type: UpdateType, resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) -> HKSampleQuery {
        getLatestRestingHeartRateQueryCalled = true
        let mockQuery = MockSampleQuery(sampleType: self.sampleTypeFor(.restingHeartRate),
                                        predicate: nil,
                                        limit: 1,
                                        sortDescriptors: [self.sortDescriptor],
                                        resultsHandler: resultsHandler)
        return mockQuery
    }

    override func getObserverQuery(updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) -> HKObserverQuery {
        getObserverQueryCalled = true
        let mockObserverQuery = MockObserverQuery(sampleType: self.sampleTypeForRestingHeartRate,
                                                  predicate: nil,
                                                  updateHandler: updateHandler)
        // This needs to be set here because variable is set to nil on the second init call.
        mockObserverQuery.mockResultHandler = updateHandler
        return mockObserverQuery
    }

    override func getAverageRestingHeartRateQuery(queryStartDate: Date) -> HKStatisticsCollectionQuery {
        let quantityType = sampleTypeForRestingHeartRate
        let interval = NSDateComponents()
        interval.month = 6

        let query = MockStatisticCollectionQuery(quantityType: quantityType,
                                                 quantitySamplePredicate: nil,
                                                 options: .discreteAverage,
                                                 anchorDate: queryStartDate,
                                                 intervalComponents: interval as DateComponents)
        query.mockInitialResulstHandler = mockResultHandler
        return query
    }
}

private class MockStatisticCollectionQuery: HKStatisticsCollectionQuery {
    var mockInitialResulstHandler: ((HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void)?

}

private class MockQueryParser: QueryParser {
    var update: GenericUpdate?
    var error: Error?
    var queryResultsCalled = false

    override func parseLatestRestingHeartRateQueryResults(
        query: HKSampleQuery,
        results: [HKSample]?,
        error: Error?,
        type: UpdateType,
        completion: @escaping (Result<GenericUpdate, Error>) -> Void) {
            queryResultsCalled = true
            if let error = error {
                completion(.failure(error))
            } else if let update = update {
                completion(.success(update))
            } else {
                fatalError("Either error or update variable needs to be set in MockQueryParser")
            }
        }
}

private class MockObserverQuery: HKObserverQuery {
    var mockResultHandler: ((HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void)?

    override init(sampleType: HKSampleType,
                  predicate: NSPredicate?,
                  updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        self.mockResultHandler = updateHandler
        super.init(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
    }

    override init(
        queryDescriptors: [HKQueryDescriptor],
        updateHandler: @escaping (HKObserverQuery, Set<HKSampleType>?, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
            super.init(queryDescriptors: queryDescriptors, updateHandler: updateHandler)
    }
}

private class MockSampleQuery: HKSampleQuery {
    var mockResultHandler: ((HKSampleQuery, [HKSample]?, Error?) -> Void)?

    // All the initialisers need to be overriden, otherwise the app crashes.

    override init(sampleType: HKSampleType,
                  predicate: NSPredicate?,
                  limit: Int,
                  sortDescriptors: [NSSortDescriptor]?,
                  resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.mockResultHandler = resultsHandler
        super.init(sampleType: sampleType,
                   predicate: predicate,
                   limit: limit,
                   sortDescriptors: sortDescriptors,
                   resultsHandler: resultsHandler)
    }

    override init(
        queryDescriptors: [HKQueryDescriptor],
        limit: Int,
        resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.mockResultHandler = resultsHandler
        super.init(
            queryDescriptors: queryDescriptors,
            limit: limit,
            resultsHandler: resultsHandler)
    }

    override init(
        queryDescriptors: [HKQueryDescriptor],
        limit: Int,
        sortDescriptors: [NSSortDescriptor],
        resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.mockResultHandler = resultsHandler
        super.init(
            queryDescriptors: queryDescriptors,
            limit: limit,
            sortDescriptors: sortDescriptors,
            resultsHandler: resultsHandler)
    }
}

private class MockNotificationService: NotificationService {
    var postNotificationCalledCount = 0
    var postNotificationCalled: Bool {
        return postNotificationCalledCount > 0
    }
    var delay: TimeInterval?

    override func postNotification(title: String, body: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        if let delay = delay {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.postNotificationCalledCount += 1
                completion?(.success(()))
            }
        } else {
            postNotificationCalledCount += 1
            completion?(.success(()))
        }
    }
}

// MARK: - Helpers
private enum TestError: Error {
    case genericError
}
