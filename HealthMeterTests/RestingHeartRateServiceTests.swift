//
//  RestingHeartRateServiceTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 26.1.2022.
//

import XCTest
@testable import HealthMeter
import HealthKit
import SwiftUI

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

        XCTAssertTrue(service.heartRateIsAboveAverage(update: RestingHeartRateUpdate(date: Date(), value: 70.0), average: 55.0), "Should be significant difference")
        XCTAssertFalse(service.heartRateIsAboveAverage(update: RestingHeartRateUpdate(date: Date(), value: 55.0), average: 55.0), "Should be significant difference")
    }

    func testUpdate_noNotificationIfAvgHRMissing() throws {
        let mockNotificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: mockNotificationService)
        service.postDebugNotifications = false
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
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 100.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
    }

    func testPosted_risingToLowered() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let risingUpdate = RestingHeartRateUpdate(date: Date().addingTimeInterval(-60*60), value: 100.0)
        service.handleHeartRateUpdate(update: risingUpdate)
        let loweringUpdate = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: loweringUpdate)

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
        XCTAssertTrue(service.postedAboutLoweredNotificationToday)
    }

    /**
     Handling and update that == qvg RHR doesn't cause any notifications being posted
     */
    func testPosting_averageRHR() throws {
        let service = RestingHeartRateService(userDefaults: userDefaults)
        service.postDebugNotifications = false
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertFalse(service.postedAboutRisingNotificationToday)
        XCTAssertFalse(service.postedAboutLoweredNotificationToday)
    }

    /**
     Service gets high, average, high average resting rate. The app should post notification about one about rising HRH, and one about lowered RHR.
     */
    func testPosted_multiple() throws {
        let notificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: notificationService)
        service.postDebugNotifications = false
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

        XCTAssertTrue(service.postedAboutRisingNotificationToday)
        XCTAssertTrue(service.postedAboutLoweredNotificationToday)
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

    // MARK: - Debug notification
    func testDebugNotification_enabled() {
        let notificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: notificationService)
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertTrue(notificationService.postNotificationCalled, "Debug notification should be sent if the debug flag is enabled.")
    }

    func testDebugNotification_disabled() {
        let notificationService = MockNotificationService()
        let service = RestingHeartRateService(userDefaults: userDefaults, notificationService: notificationService)
        service.postDebugNotifications = false
        userDefaults.set(50.0, forKey: "AverageRestingHeartRate")

        let update = RestingHeartRateUpdate(date: Date(), value: 50.0)
        service.handleHeartRateUpdate(update: update)

        XCTAssertFalse(notificationService.postNotificationCalled, "Debug notification shuoldn't be sent if the debug flag is disabled.")
    }

    // MARK: - HealthStore queries

    func testObserveInBacground_functionsCalled() {
        let mockHealthStore = MockHealthStore()
        let service = RestingHeartRateService(userDefaults: userDefaults, healthStore: mockHealthStore)
        service.observeInBackground()
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
            return parser.parseLatestRestingHeartRateQueryResultsCalled
        }
        _ = expectation(for: predicate, evaluatedWith: mockQueryParser, handler: .none)

        service.observeInBackground()
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
        let expectation = expectation(description: "Completion handler shouldn't be called if the samples are empty")
        expectation.isInverted = true
        service.queryLatestRestingHeartRate { _ in
            expectation.fulfill()
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
        }
    }

    override func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency, withCompletion completion: @escaping (Bool, Error?) -> Void) {
        enableBackgroundDeliveryCalled = true
    }
}

private class MockQueryProvider: QueryProvider {
    var getLatestRestingHeartRateQueryCalled = false
    var getObserverQueryCalled = false

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
}

private class MockQueryParser: QueryParser {
    var update: RestingHeartRateUpdate?
    var error: Error?
    var parseLatestRestingHeartRateQueryResultsCalled = false

    override func parseLatestRestingHeartRateQueryResults(query: HKSampleQuery, results: [HKSample]?, error: Error?, completion: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        parseLatestRestingHeartRateQueryResultsCalled = true
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

    override init(sampleType: HKSampleType, predicate: NSPredicate?, updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        self.mockResultHandler = updateHandler
        super.init(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
    }

    override init(queryDescriptors: [HKQueryDescriptor], updateHandler: @escaping (HKObserverQuery, Set<HKSampleType>?, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        super.init(queryDescriptors: queryDescriptors, updateHandler: updateHandler)
    }
}

private class MockSampleQuery: HKSampleQuery {
    var mockResultHandler: ((HKSampleQuery, [HKSample]?, Error?) -> Void)?

    // All the initialisers need to be overriden, otherwise the app crashes.

    override init(sampleType: HKSampleType, predicate: NSPredicate?, limit: Int, sortDescriptors: [NSSortDescriptor]?, resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.mockResultHandler = resultsHandler
        super.init(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
    }

    override init(queryDescriptors: [HKQueryDescriptor], limit: Int, resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.mockResultHandler = resultsHandler
        super.init(queryDescriptors: queryDescriptors, limit: limit, resultsHandler: resultsHandler)
    }

    override init(queryDescriptors: [HKQueryDescriptor], limit: Int, sortDescriptors: [NSSortDescriptor], resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        self.mockResultHandler = resultsHandler
        super.init(queryDescriptors: queryDescriptors, limit: limit, sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
    }
}

private class MockNotificationService: NotificationService {
    var postNotificationCalledCount = 0
    var postNotificationCalled: Bool {
        return postNotificationCalledCount > 0
    }
    override func postNotification(message: String) {
        postNotificationCalledCount += 1
    }
}

// MARK: - Helpers
enum TestError: Error {
    case genericError
}

func createLatestHeartRate() -> HKSample {
    fatalError()
}
