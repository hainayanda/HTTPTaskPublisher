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

class HTTPDataTaskPublisherSpec: QuickSpec {
    override class func spec() {
        var factory: DataTaskFactoryMock!
        var publisher: URLSession.HTTPDataTaskPublisher!
        context("failing") {
            beforeEach {
                factory = DataTaskFactoryMock(result: .failure(.init(.unknown)))
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy)
            }
            it("should sink with error") {
                let result = try sendRequest(using: publisher)
                expectToBeDefaultError(for: result)
            }
        }
        context("succeed") {
            beforeEach {
                factory = DataTaskFactoryMock(result: .success((Data(), HTTPURLResponse())))
                publisher = .init(dataTaskFactory: factory, urlRequest: .dummy)
            }
            it("should sink with value") {
                let result = try sendRequest(using: publisher)
                expectToBeDefaultSuccess(for: result)
            }
        }
    }
}

// MARK: Test

private func sendRequest(using publisher: URLSession.HTTPDataTaskPublisher) throws -> Result<(data: Data, response: URLResponse), HTTPURLError> {
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

private func expectToBeDefaultError(for result: Result<(data: Data, response: URLResponse), HTTPURLError>) {
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

// MARK: DataTaskFactoryMock

private class DataTaskFactoryMock: DataTaskPublisherFactory {
    let result: Result<(data: Data, response: URLResponse), URLError>
    var request: URLRequest?
    
    init(result: Result<(data: Data, response: URLResponse), URLError>) {
        self.result = result
    }
    
    func anyDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        self.request = request
        let result = self.result
        return Future { promise in
            promise(result)
        }
        .eraseToAnyPublisher()
    }
}
