//
//  File.swift
//  
//
//  Created by Nayanda Haberty on 30/10/23.
//

import Foundation
import Quick
import Nimble
import Combine
@testable import HTTPTaskPublisher

func waitForResponse<P: Publisher>(to publisher: P) throws -> Result<(data: Data, response: URLResponse), HTTPURLError> where P.Output == (data: Data, response: HTTPURLResponse), P.Failure == HTTPURLError {
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
