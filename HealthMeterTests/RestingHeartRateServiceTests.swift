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
            update: RestingHeartRateUpdate(
                date: Date(),
                value: 70.0),
            average: 55.0), "Should be significant difference")
        XCTAssertFalse(service.heartRateIsAboveAverage(
            update: RestingHeartRateUpdate(
                date: Date(),
                value: 55.0),
            average: 55.0), "Should be significant difference")
    }

    func testUpdate_noNotificationIfAvgHRMissing() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: mockNotificationService)
        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

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

        let update = RestingHeartRateUpdate(date: Date(), value: 100.0)
        service.handleHeartRateUpdate(update: update)

        let predicate = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return service.hasPostedAboutRisingNotificationToday
        }
        _ = expectation(for: predicate, evaluatedWith: service, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testPosted_rising_debug() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(
            userDefaults: userDefaults,
            notificationService: mockNotificationService)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 100.0)
        service.handleHeartRateUpdate(update: update, isRealUpdate: false)

        let predicate = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return !service.hasPostedAboutRisingNotificationToday
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

        let risingUpdate = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate)
        let loweringUpdate = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate)

        let risingNotificationCalled = NSPredicate { service, _ in
            guard let service = service as? RestingHeartRateService else { return false }
            return service.hasPostedAboutRisingNotificationToday
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

        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertFalse(service.hasPostedAboutRisingNotificationToday)
        XCTAssertFalse(service.hasPostedAboutLoweredNotificationToday)
    }

    /**
     Service gets high, average, high average resting rate. The app should post notification about one about rising HRH, and one about lowered RHR.
     */
    func testPosted_multiple() throws {
        let notificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: notificationService)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate1 = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60*3), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate1)
        let loweringUpdate1 = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60*2), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate1)
        let risingUpdate2 = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate2)
        let loweringUpdate2 = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate2)
        XCTAssertEqual(notificationService.postNotificationCalledCount, 2, "Only two notifications should be sent - one for high RHR and and another for lowered RRH")

        XCTAssertTrue(service.hasPostedAboutRisingNotificationToday)
        XCTAssertTrue(service.hasPostedAboutLoweredNotificationToday)
    }

    // MARK: - Encoding and decoding latest resting heart rate
    func testDecodeLatestRestingHeartRateUpdate_initial() {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        XCTAssertNil(service.decodeLatestRestingHeartRateUpdate(), "Latest RHR should be initially nil")
    }

    func testDecodeLatestRestingHeartRateUpdate_encoding() throws {
        let latest = RestingHeartRateUpdate(date: Date(), value: 50.0)
        let data = try XCTUnwrap(JSONEncoder().encode(latest))
        userDefaults.set(data, forKey: "LatestRestingHeartRateUpdate")
        let service = RestingHeartRateService(userDefaults: userDefaults)
        XCTAssertNotNil(service.decodeLatestRestingHeartRateUpdate(), "Latest RHR shouldn't be nil")
    }

    // MARK: - HealthStore queries

    func testObserveInBacground_functionsCalled() {
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
        mockQueryParser.update = RestingHeartRateUpdate(date: Date(), value: 50.0)
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
        mockQueryParser.update = RestingHeartRateUpdate(date: Date(), value: 100.0)
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
        service.queryLatestRestingHeartRate { _ in }
        XCTAssertTrue(mockHealthStore.executeQueryCalled)
    }

    func testQueryLatestRestingHeartRate_completionBlock_emptySamples() {
        let mockHealthStore = MockHealthStore()
        let mockQueryProvider = MockQueryProvider()
        let service = RestingHeartRateService(userDefaults: userDefaults,
                                              healthStore: mockHealthStore,
                                              queryProvider: mockQueryProvider)
        let expectation = expectation(description: "No samples should result in an error.")
        service.queryLatestRestingHeartRate { result in
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
        service.queryLatestRestingHeartRate { result in
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
        mockQueryParser.update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        let expectation = expectation(description: "queryLatestRestingHeartRate's result should be success")
        service.queryLatestRestingHeartRate { result in
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

    override func getLatestRestingHeartRateQuery(resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) -> HKSampleQuery {
        getLatestRestingHeartRateQueryCalled = true
        let mockQuery = MockSampleQuery(sampleType: self.sampleTypeForRestingHeartRate,
                                        predicate: nil,
                                        limit: 1,
                                        sortDescriptors: [self.sortDescriptorForLatestRestingHeartRate],
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
    var update: RestingHeartRateUpdate?
    var error: Error?
    var queryResultsCalled = false

    override func parseLatestRestingHeartRateQueryResults(
        query: HKSampleQuery,
        results: [HKSample]?,
        error: Error?,
        completion: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
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
    override func postNotification(title: String, body: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        postNotificationCalledCount += 1

        completion?(.success(()))
    }
}

// MARK: - Helpers
private enum TestError: Error {
    case genericError
}
