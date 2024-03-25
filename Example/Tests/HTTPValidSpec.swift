//
//  HTTPValidSpec.swift
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

class HTTPValidSpec: QuickSpec {
    override class func spec() {
        var sender: MockablePublisher!
        var publisher: URLSession.HTTPValid!
        var validator: MockValidator!
        beforeEach {
            validator = MockValidator()
        }
        context("request is failing") {
            beforeEach {
                sender = MockablePublisher(.failure(.error(TestError.expectedError)))
                publisher = .init(validator: validator)
                sender.subscribe(publisher)
            }
            it("valid should never called") {
                validator.validation = .valid
                
                let result = try waitForResponse(to: publisher)
                
                expect(validator.called).to(beFalse())
                expectToBeExpectedError(for: result)
            }
            it("invalid should never called") {
                validator.validation = .invalid(reason: "expected error")
                
                let result = try waitForResponse(to: publisher)
                
                expect(validator.called).to(beFalse())
                expectToBeExpectedError(for: result)
            }
        }
        context("request is succeed") {
            beforeEach {
                sender = MockablePublisher(.success((data: Data(), response: HTTPURLResponse())))
                publisher = .init(validator: validator)
                sender.subscribe(publisher)
            }
            it("should adapt with new request") {
                validator.validation = .valid
                
                let result = try waitForResponse(to: publisher)
                
                expect(validator.called).to(beTrue())
                expectToBeDefaultSuccess(for: result)
            }
            it("should not with new request") {
                validator.validation = .invalid(reason: "expected error")
                
                let result = try waitForResponse(to: publisher)
                
                expect(validator.called).to(beTrue())
                expectToBeValidationError(for: result)
            }
        }
    }
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

private func expectToBeValidationError(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failValidation(let reason, _, _) = error else {
            fail("result should produce failValidation but produce \(String(describing: error))")
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

private class MockValidator: HTTPDataTaskValidator {
    
    var validation: HTTPDataTaskValidation = .valid
    var called: Bool = false
    
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation {
        called = true
        return validation
    }
}
