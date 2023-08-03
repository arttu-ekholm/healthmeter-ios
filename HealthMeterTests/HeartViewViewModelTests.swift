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

    // MARK: - Colors and strings
    func testColors() {
        XCTAssertEqual(model(50.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(49.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(40.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(51.0, 50.0).heartColor, .green)
        XCTAssertEqual(model(53.0, 50.0).heartColor, .yellow)
        XCTAssertEqual(model(55.0, 50.0).heartColor, .orange)
        XCTAssertEqual(model(60.0, 50.0).heartColor, .orange)
        XCTAssertEqual(model(65.0, 50.0).heartColor, .red)
        XCTAssertEqual(model(100.0, 50.0).heartColor, .red)
    }

    func testImageString() {
        let upArrow = "arrow.up.heart.fill"
        let fill = "heart.fill"
        let notToday = "heart.text.square"
        let yesterday = Date().addingTimeInterval(-60*60*24)

        XCTAssertEqual(model(50.0, 50.0).heartImageName, fill)
        XCTAssertEqual(model(51.0, 50.0).heartImageName, fill)
        XCTAssertEqual(model(150.0, 50.0).heartImageName, upArrow)
        XCTAssertEqual(model(30.0, 50.0).heartImageName, fill)

        XCTAssertEqual(model(50.0, 50.0, yesterday).heartImageName, notToday)
        XCTAssertEqual(model(51.0, 50.0, yesterday).heartImageName, notToday)
        XCTAssertEqual(model(150.0, 50.0, yesterday).heartImageName, notToday)
        XCTAssertEqual(model(30.0, 50.0, yesterday).heartImageName, notToday)
    }
}

private enum HeartViewViewModelTestsError: Error {
    case testError
}

private func model(_ latest: Double, _ average: Double, _ date: Date = Date()) -> HeartView.ViewModel {
    let mockService = MockRestingHeartRateService()
    return HeartView.ViewModel(heartRateService: mockService, shouldReloadContents: false, viewState: .success(RestingHeartRateUpdate(date: date, value: latest), average))
}
