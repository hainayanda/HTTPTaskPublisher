//
//  HTTPDataTaskPublisherSpec.swift
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

class HTTPDataTaskPublisherSpec: AsyncSpec {
    // swiftlint:disable function_body_length
    override class func spec() {
        var factory: DataTaskFactoryMock!
        var publisher: URLSession.HTTPDataTaskPublisher!
        context("failing") {
            beforeEach {
                factory = await DataTaskFactoryMock(result: .failure(.init(.unknown)))
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy, adapter: nil, duplicationHandler: .alwaysCreateNew)
            }
            it("should sink with error") {
                let result = try waitForResponse(to: publisher)
                expectToBeDefaultError(for: result)
            }
            it("should adapt with new request") {
                let adapter = MockAdapter()
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy, adapter: adapter, duplicationHandler: .alwaysCreateNew)
                let newRequest = URLRequest(url: URL(string: "http://www.adapt.com")!)
                adapter.result = .success(newRequest)
                
                let result = try waitForResponse(to: publisher)
                
                expect(adapter.adapterCalled).to(beTrue())
                expectToBeDefaultError(for: result)
            }
            it("should not with new request") {
                let adapter = MockAdapter()
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy, adapter: adapter, duplicationHandler: .alwaysCreateNew)
                adapter.result = .failure(.expectedError)
                
                let result = try waitForResponse(to: publisher)
                
                expect(adapter.adapterCalled).to(beTrue())
                expectToBeExpectedError(for: result)
            }
        }
        context("succeed") {
            beforeEach {
                factory = await DataTaskFactoryMock(result: .success((Data(), HTTPURLResponse())))
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy, adapter: nil, duplicationHandler: .alwaysCreateNew)
            }
            it("should sink with value") {
                let result = try waitForResponse(to: publisher)
                expectToBeDefaultSuccess(for: result)
            }
            it("should adapt with new request") {
                let adapter = MockAdapter()
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy, adapter: adapter, duplicationHandler: .alwaysCreateNew)
                let newRequest = URLRequest(url: URL(string: "http://www.adapt.com")!)
                adapter.result = .success(newRequest)
                
                let result = try waitForResponse(to: publisher)
                
                expect(adapter.adapterCalled).to(beTrue())
                expectToBeDefaultSuccess(for: result)
            }
            it("should not adapt with new request") {
                let adapter = MockAdapter()
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy, adapter: adapter, duplicationHandler: .alwaysCreateNew)
                adapter.result = .failure(.expectedError)
                
                let result = try waitForResponse(to: publisher)
                
                expect(adapter.adapterCalled).to(beTrue())
                expectToBeExpectedError(for: result)
            }
        }
    }
    // swiftlint:enable function_body_length
}

// MARK: Test

private func sendRequest(using publisher: URLSession.HTTPDataTaskPublisher) throws -> Result<URLResponseOutput, HTTPURLError> {
    var result: Result<URLResponseOutput, HTTPURLError>?
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

private func expectToBeDefaultSuccess(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        return
    case .failure(let error):
        fail("result should not be an error: \(String(describing: error))")
    }
}

private func expectToBeDefaultError(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .urlError(let uRLError) = error else {
            fail("result should produce URLError")
            return
        }
        expect(uRLError.code).to(equal(.unknown))
    }
}

private func expectToBeExpectedError(for result: Result<URLResponseOutput, HTTPURLError>) {
    switch result {
    case .success:
        fail("result should fail")
    case .failure(let error):
        guard case .failWhileAdapt = error else {
            fail("result should produce expected error but produce \(String(describing: error))")
            return
        }
        return
    }
}

// MARK: MockAdapter

private class MockAdapter: HTTPDataTaskAdapter {
    
    var result: Result<URLRequest, TestError> = .failure(.initialError)
    var request: URLRequest?
    var adapterCalled: Bool { adapterCalledCount > 0 }
    var adapterCalledCount: Int = 0
    
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest {
        adapterCalledCount += 1
        self.request = request
        switch result {
        case .success(let adaptRequest):
            return adaptRequest
        case .failure(let error):
            throw error
        }
    }
}
