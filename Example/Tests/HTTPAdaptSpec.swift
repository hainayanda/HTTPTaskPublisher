//
//  HTTPAdaptSpec.swift
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

class HTTPAdaptSpec: QuickSpec {
    override class func spec() {
        var sender: URLRequestSenderMock!
        var publisher: URLSession.HTTPAdapt<URLRequestSenderMock>!
        var adapter: MockAdapter!
        context("request is failing") {
            beforeEach {
                adapter = MockAdapter()
                sender = URLRequestSenderMock(result: .failure(.expectedError))
                publisher = .init(sender: sender, adapter: adapter)
            }
            it("should adapt with new request") {
                let newRequest = URLRequest(url: URL(string: "http://www.adapt.com")!)
                adapter.result = .success(newRequest)
                
                let result = try sendRequest(using: publisher)
                
                expect(sender.sentRequest).to(equal(newRequest))
                expectToBeExpectedError(for: result)
            }
            it("should not with new request") {
                adapter.result = .failure(.expectedError)
                
                let result = try sendRequest(using: publisher)
                
                expect(sender.sentRequest).to(beNil())
                expectToBeExpectedError(for: result)
            }
        }
        context("request is succeed") {
            beforeEach {
                adapter = MockAdapter()
                sender = URLRequestSenderMock(result: .success((Data(), HTTPURLResponse())))
                publisher = .init(sender: sender, adapter: adapter)
            }
            it("should adapt with new request") {
                let newRequest = URLRequest(url: URL(string: "http://www.adapt.com")!)
                adapter.result = .success(newRequest)
                
                let result = try sendRequest(using: publisher)
                
                expect(sender.sentRequest).to(equal(newRequest))
                expectToBeDefaultSuccess(for: result)
            }
            it("should not with new request") {
                adapter.result = .failure(.expectedError)
                
                let result = try sendRequest(using: publisher)
                
                expect(sender.sentRequest).to(beNil())
                expectToBeExpectedError(for: result)
            }
        }
    }
}

// MARK: Test

private func sendRequest(using publisher: URLSession.HTTPAdapt<URLRequestSenderMock>) throws -> Result<(data: Data, response: URLResponse), HTTPURLError> {
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

private func expectToBeExpectedError(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failWhileAdapt(_, let underlyingError) = error,
                let testError = underlyingError as? TestError else {
            fail("result should produce TestError but produce \(String(describing: error))")
            return
        }
        expect(testError).to(equal(.expectedError))
    }
}

private class MockAdapter: HTTPDataTaskAdapter {
    
    var result: Result<URLRequest, TestError> = .failure(.initialError)
    var request: URLRequest?
    
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest {
        self.request = request
        switch result {
        case .success(let adaptRequest):
            return adaptRequest
        case .failure(let error):
            throw error
        }
    }
}
