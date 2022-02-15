//
//  HeartViewViewModelTests.swift
//  HealthMeterTests
//
//  Created by Arttu Ekholm on 15.2.2022.
//

import XCTest
@testable import HealthMeter

class HeartViewViewModelTests: XCTestCase {
    func testRequestLatestRestingHeartRate_success() {
        let mockHeartRateService = MockRestingHeartRateService()
        mockHeartRateService.mockAverageRHRResult = .success(50)
        mockHeartRateService.mockLatestRHRResult = .success(RestingHeartRateUpdate(date: Date(), value: 50))

        let viewModel = HeartView.ViewModel(heartRateService: mockHeartRateService)

        viewModel.requestLatestRestingHeartRate()

        let predicate = NSPredicate { viewModel, _ in
            guard let viewModel = viewModel as? HeartView.ViewModel else { return false }

            switch viewModel.viewState {
            case .success: return true
            default: return false
            }
        }
        _ = expectation(for: predicate, evaluatedWith: viewModel, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testRequestLatestRestingHeartRate_loading() {
        let mockHeartRateService = MockRestingHeartRateService()
        let viewModel = HeartView.ViewModel(heartRateService: mockHeartRateService)

        viewModel.requestLatestRestingHeartRate()
        switch viewModel.viewState {
        case.loading: break
        default: XCTFail("The view model should be loading")
        }
    }

    func testRequestLatestRestingHeartRate_failure_both() {
        let mockHeartRateService = MockRestingHeartRateService()
        mockHeartRateService.mockAverageRHRResult = .failure(HeartViewViewModelTestsError.testError)
        mockHeartRateService.mockLatestRHRResult = .failure(HeartViewViewModelTestsError.testError)

        let viewModel = HeartView.ViewModel(heartRateService: mockHeartRateService)

        viewModel.requestLatestRestingHeartRate()

        let predicate = NSPredicate { viewModel, _ in
            guard let viewModel = viewModel as? HeartView.ViewModel else { return false }

            switch viewModel.viewState {
            case .error: return true
            default: return false
            }
        }
        _ = expectation(for: predicate, evaluatedWith: viewModel, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testRequestLatestRestingHeartRate_failure_latest() {
        let mockHeartRateService = MockRestingHeartRateService()
        mockHeartRateService.mockAverageRHRResult = .success(50.0)
        mockHeartRateService.mockLatestRHRResult = .failure(HeartViewViewModelTestsError.testError)

        let viewModel = HeartView.ViewModel(heartRateService: mockHeartRateService)

        viewModel.requestLatestRestingHeartRate()

        let predicate = NSPredicate { viewModel, _ in
            guard let viewModel = viewModel as? HeartView.ViewModel else { return false }

            switch viewModel.viewState {
            case .error: return true
            default: return false
            }
        }
        _ = expectation(for: predicate, evaluatedWith: viewModel, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testRequestLatestRestingHeartRate_failure_average() {
        let mockHeartRateService = MockRestingHeartRateService()
        mockHeartRateService.mockAverageRHRResult = .failure(HeartViewViewModelTestsError.testError)
        mockHeartRateService.mockLatestRHRResult = .success(RestingHeartRateUpdate(date: Date(), value: 50.0))

        let viewModel = HeartView.ViewModel(heartRateService: mockHeartRateService)

        viewModel.requestLatestRestingHeartRate()

        let predicate = NSPredicate { viewModel, _ in
            guard let viewModel = viewModel as? HeartView.ViewModel else { return false }

            switch viewModel.viewState {
            case .error: return true
            default: return false
            }
        }
        _ = expectation(for: predicate, evaluatedWith: viewModel, handler: .none)

        waitForExpectations(timeout: 2.0, handler: .none)
    }

    func testIsDateInToday() {
        let calendar = Calendar.current
        let viewModel = HeartView.ViewModel(heartRateService: RestingHeartRateService.shared, calendar: calendar)

        let now = Date()
        let notToday = Date().addingTimeInterval(-60*60*1000)
        XCTAssertTrue(calendar.isDateInToday(now))
        XCTAssertTrue(viewModel.isDateInToday(now))

        XCTAssertEqual(viewModel.isDateInToday(now), calendar.isDateInToday(now))
        XCTAssertEqual(viewModel.isDateInYesterday(now), calendar.isDateInYesterday(now))

        XCTAssertFalse(calendar.isDateInToday(notToday))
        XCTAssertFalse(viewModel.isDateInToday(notToday))
        XCTAssertEqual(viewModel.isDateInToday(notToday), calendar.isDateInToday(notToday))
        XCTAssertEqual(viewModel.isDateInYesterday(notToday), calendar.isDateInYesterday(notToday))

    }
}

private class MockRestingHeartRateService: RestingHeartRateService {
    var mockAverageRHRResult: Result<Double, Error>?
    var mockLatestRHRResult: Result<RestingHeartRateUpdate, Error>?

    override func queryAverageRestingHeartRate(averageRHRCallback: @escaping (Result<Double, Error>) -> Void) {
        if let result = mockAverageRHRResult {
            averageRHRCallback(result)
        }
    }

    override func queryLatestRestingHeartRate(completionHandler: @escaping (Result<RestingHeartRateUpdate, Error>) -> Void) {
        if let result = mockLatestRHRResult {
            completionHandler(result)
        }
    }
}

private enum HeartViewViewModelTestsError: Error {
    case testError
}
