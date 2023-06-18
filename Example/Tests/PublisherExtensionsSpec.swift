//
//  PublisherExtensionsSpec.swift
//  HTTPTaskPublisher_Example
//
//  Created by Nayanda Haberty on 17/6/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import Quick
import Nimble
import Combine
@testable import HTTPTaskPublisher

class PublisherExtensionsSpec: QuickSpec {
    override class func spec() {
        var publisher: PassthroughSubject<URLSession.HTTPDataTaskPublisher.Output, HTTPURLError>!
        beforeEach {
            publisher = .init()
        }
        it("should decode the data") {
            let data = "{\"number\":1,\"string\":\"some string\",\"bool\":true}".data(using: .utf8)!
            let result = try waitToDecode(using: publisher, for: data)
            let expected = ToDecode(number: 1, string: "some string", bool: true)
            expect(result).to(equal(expected))
        }
        it("should fail decode the data") {
            let data = "{\"notANumber\":\"1\",\"string\":\"some string\",\"bool\":true}".data(using: .utf8)!
            do {
                _ = try waitToDecode(using: publisher, for: data)
                fail("this decode should be failing")
            } catch {
                guard let httpError = error as? HTTPURLError,
                      case .failDecode(let decodeData, _, _) = httpError else {
                    fail("get unexpected error: \(String(describing: error))")
                    return
                }
                expect(decodeData).to(equal(data))
            }
        }
    }
}

// MARK: Test

private func waitToDecode(using publisher: PassthroughSubject<URLSession.HTTPDataTaskPublisher.Output, HTTPURLError>, for data: Data) throws -> ToDecode? {
    var result: ToDecode?
    var error: HTTPURLError?
    var cancellable: AnyCancellable?
    waitUntil { done in
        cancellable = publisher
            .decode(type: ToDecode.self, decoder: JSONDecoder())
            .sink { completion in
            switch completion {
            case .finished:
                break
            case .failure(let err):
                error = err
            }
            done()
        } receiveValue: { value in
            result = value.decoded
        }
        publisher.send((data, HTTPURLResponse()))
        publisher.send(completion: .finished)
    }
    cancellable?.cancel()
    cancellable = nil
    guard let result else {
        throw error ?? TestError.unexpectedError
    }
    return result
}

// MARK: Model

private struct ToDecode: Decodable, Equatable {
    let number: Int
    let string: String
    let bool: Bool
}
