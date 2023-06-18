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
        var sender: URLRequestSenderMock!
        var publisher: URLSession.HTTPValid<URLRequestSenderMock>!
        var validator: MockValidator!
        context("request is failing") {
            beforeEach {
                validator = MockValidator()
                sender = URLRequestSenderMock(result: .failure(.expectedError))
                publisher = .init(sender: sender, validator: validator)
            }
            it("valid should never called") {
                validator.validation = .valid
                
                let result = try sendRequest(using: publisher)
                
                expect(validator.called).to(beFalse())
                expectToBeExpectedError(for: result)
            }
            it("invalid should never called") {
                validator.validation = .invalid(reason: "expected error")
                
                let result = try sendRequest(using: publisher)
                
                expect(validator.called).to(beFalse())
                expectToBeExpectedError(for: result)
            }
        }
        context("request is succeed") {
            beforeEach {
                validator = MockValidator()
                sender = URLRequestSenderMock(result: .success((Data(), HTTPURLResponse())))
                publisher = .init(sender: sender, validator: validator)
            }
            it("should adapt with new request") {
                validator.validation = .valid
                
                let result = try sendRequest(using: publisher)
                
                expect(validator.called).to(beTrue())
                expectToBeDefaultSuccess(for: result)
            }
            it("should not with new request") {
                validator.validation = .invalid(reason: "expected error")
                
                let result = try sendRequest(using: publisher)
                
                expect(validator.called).to(beTrue())
                expectToBeValidationError(for: result)
            }
        }
    }
}

// MARK: Test

private func sendRequest(using publisher: URLSession.HTTPValid<URLRequestSenderMock>) throws -> Result<(data: Data, response: URLResponse), HTTPURLError> {
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

private func expectToBeValidationError(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
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

private class MockValidator: HTTPDataTaskValidator {
    
    var validation: HTTPDataTaskValidation = .valid
    var called: Bool = false
    
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation {
        called = true
        return validation
    }
}

