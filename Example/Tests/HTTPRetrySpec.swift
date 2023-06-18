//
//  HTTPRetrySpec.swift
//  HTTPTaskPublisher_Tests
//
//  Created by Nayanda Haberty on 16/6/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import Quick
import Nimble
import Combine
@testable import HTTPTaskPublisher

class HTTPRetrySpec: QuickSpec {
    // swiftlint:disable function_body_length
    override class func spec() {
        var sender: URLRequestSenderMock!
        var publisher: URLSession.HTTPRetry<URLRequestSenderMock>!
        var retrier: MockRetrier!
        context("request is failing") {
            beforeEach {
                retrier = MockRetrier()
                sender = URLRequestSenderMock(result: .failure(.expectedError))
                publisher = .init(sender: sender, retrier: retrier)
            }
            it("should drop the request") {
                retrier.decision = .drop
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beTrue())
                expectToBeExpectedError(for: result)
            }
            it("should drop the request with reason") {
                retrier.decision = .dropWithReason(reason: "expected error")
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beTrue())
                expectToBeToRetryError(for: result)
            }
            it("should retry the request") {
                retrier.decision = .retry
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beTrue())
                expectToBeWhileRetryError(for: result)
            }
            it("should retry with new request") {
                let newRequest = URLRequest(url: URL(string: "http://www.adapt.com")!)
                retrier.decision = .retryWithNewRequest(newRequest)
                
                let result = try sendRequest(using: publisher)
                
                expect(sender.sentRequest).to(equal(newRequest))
                expect(retrier.called).to(beTrue())
                expectToBeWhileRetryError(for: result)
            }
        }
        context("request is succeed") {
            beforeEach {
                retrier = MockRetrier()
                sender = URLRequestSenderMock(result: .success((Data(), HTTPURLResponse())))
                publisher = .init(sender: sender, retrier: retrier)
            }
            it("should success and never drop") {
                retrier.decision = .drop
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
            it("should success and never drop with reason") {
                retrier.decision = .dropWithReason(reason: "unexpected error")
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
            it("should success and never retry") {
                retrier.decision = .retry
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
            it("should success and never retry with new reqeust") {
                let newRequest = URLRequest(url: URL(string: "http://www.adapt.com")!)
                retrier.decision = .retryWithNewRequest(newRequest)
                
                let result = try sendRequest(using: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
        }
    }
    // swiftlint:enable function_body_length
}

// MARK: Test

private func sendRequest(using publisher: URLSession.HTTPRetry<URLRequestSenderMock>) throws -> Result<(data: Data, response: URLResponse), HTTPURLError> {
    var result: Result<(data: Data, response: URLResponse), HTTPURLError>?
    var cancellable: AnyCancellable?
    waitUntil { done in
        cancellable = publisher.sink { completion in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                result = .failure(error)
            }
            done()
        } receiveValue: { value in
            result = .success(value)
        }
    }
    cancellable?.cancel()
    guard let result else {
        fail("result should not be nil at this point")
        throw TestError.unexpectedError
    }
    return result
}

// MARK: Expectation

private func expectToBeDefaultSuccess(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
    switch result {
    case .success:
        return
    case .failure(let error):
        fail("result should not be an error: \(String(describing: error))")
    }
}

private func expectToBeWhileRetryError(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failWhileRetry(let underlyingError, _, _) = error,
              let httpUrlError = underlyingError as? HTTPURLError,
              case .error(let subUnderlyingError) = httpUrlError,
                let testError = subUnderlyingError as? TestError else {
            fail("result should produce TestError but produce \(String(describing: error))")
            return
        }
        expect(testError).to(equal(.expectedError))
    }
}

private func expectToBeToRetryError(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failToRetry(let reason, _, _) = error else {
            fail("result should produce TestError but produce \(String(describing: error))")
            return
        }
        expect(reason).to(equal("expected error"))
    }
}

private func expectToBeExpectedError(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .error(let underlyingError) = error,
                let testError = underlyingError as? TestError else {
            fail("result should produce TestError but produce \(String(describing: error))")
            return
        }
        expect(testError).to(equal(.expectedError))
    }
}

private class MockRetrier: HTTPDataTaskRetrier {
    
    var decision: HTTPDataTaskRetryDecision = .drop
    var called: Bool = false
    
    func httpDataTaskShouldRetry(for error: HTTPURLError, request: URLRequest) async throws -> HTTPDataTaskRetryDecision {
        // make sure only retry once so the test will not retry forever
        guard !called else { return .drop }
        called = true
        return decision
    }
}
