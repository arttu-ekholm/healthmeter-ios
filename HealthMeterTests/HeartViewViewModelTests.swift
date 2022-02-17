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
}

private enum HeartViewViewModelTestsError: Error {
    case testError
}
