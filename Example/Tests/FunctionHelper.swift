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

func waitForResponse<P: Publisher>(to publisher: P) throws -> Result<URLResponseOutput, HTTPURLError> where P.Output == HTTPURLResponseOutput, P.Failure == HTTPURLError {
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
