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
        var sender: MockablePublisher!
        var publisher: URLSession.HTTPRetry!
        var retrier: MockRetrier!
        context("request is failing") {
            beforeEach {
                retrier = MockRetrier()
                sender = MockablePublisher(.failure(.error(TestError.expectedError)))
                publisher = .init(retrier: retrier)
                sender.subscribe(publisher)
            }
            it("should drop the request") {
                retrier.decision = .drop
                
                let result = try waitForResponse(to: publisher)
                
                expect(retrier.called).to(beTrue())
                expectToBeExpectedError(for: result)
            }
            it("should drop the request with reason") {
                retrier.decision = .dropWithReason(reason: "expected error")
                
                let result = try waitForResponse(to: publisher)
                
                expect(retrier.called).to(beTrue())
                expectToBeToRetryError(for: result)
            }
            it("should retry the request") {
                retrier.decision = .retry
                
                let result = try waitForResponse(to: publisher)
                
                expect(retrier.called).to(beTrue())
                expectToBeExpectedError(for: result)
            }
        }
        context("request is succeed") {
            beforeEach {
                retrier = MockRetrier()
                sender = MockablePublisher(.success((data: Data(), response: HTTPURLResponse())))
                publisher = .init(retrier: retrier)
                sender.subscribe(publisher)
            }
            it("should success and never drop") {
                retrier.decision = .drop
                
                let result = try waitForResponse(to: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
            it("should success and never drop with reason") {
                retrier.decision = .dropWithReason(reason: "unexpected error")
                
                let result = try waitForResponse(to: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
            it("should success and never retry") {
                retrier.decision = .retry
                
                let result = try waitForResponse(to: publisher)
                
                expect(retrier.called).to(beFalse())
                expectToBeDefaultSuccess(for: result)
            }
        }
    }
    // swiftlint:enable function_body_length
}

// MARK: Expectation

private func expectToBeDefaultSuccess(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        return
    case .failure(let error):
        fail("result should not be an error: \(String(describing: error))")
    }
}

private func expectToBeWhileRetryError(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failWhileRetry(let underlyingError, _) = error,
              let httpUrlError = underlyingError as? HTTPURLError,
              case .error(let subUnderlyingError) = httpUrlError,
                let testError = subUnderlyingError as? TestError else {
            fail("result should produce TestError but produce \(String(describing: error))")
            return
        }
        expect(testError).to(equal(.expectedError))
    }
}

private func expectToBeToRetryError(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failToRetry(let reason, _) = error else {
            fail("result should produce TestError but produce \(String(describing: error))")
            return
        }
        expect(reason).to(equal("expected error"))
    }
}

private func expectToBeExpectedError(for result: Result<URLResponseOutput, HTTPURLError>) {
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
    var called: Bool { calledCount > 0 }
    var calledCount: Int = 0
    
    func httpDataTaskShouldRetry(for error: HTTPURLError) async throws -> HTTPDataTaskRetryDecision {
        // make sure only retry once so the test will not retry forever
        guard !called else { return .drop }
        calledCount  += 1
        return decision
    }
}
