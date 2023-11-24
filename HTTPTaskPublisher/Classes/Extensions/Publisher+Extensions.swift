//
//  Publisher+Extensions.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

public typealias HTTPURLResponseOutput = (data: Data, response: HTTPURLResponse)

extension Publisher where Output == URLResponseOutput, Failure == URLError {
    
    func httpResponseOnly() -> AnyPublisher<HTTPURLResponseOutput, HTTPURLError> {
        tryMap { output in
            guard let response = output.response as? HTTPURLResponse else {
                throw HTTPURLError.expectHTTPResponse(data: output.data, response: output.response)
            }
            return (output.data, response)
        }
        .mapErrorToHTTPURLError()
        .eraseToAnyPublisher()
    }
}

extension Publisher where Output == URLSession.HTTPDataTaskPublisher.Output, Failure == HTTPURLError {
    
    public typealias DecodedOutput<Decoded> = (decoded: Decoded, response: HTTPURLResponse)
    
    public func decode<Decoded: Decodable, Decoder: TopLevelDecoder>(type: Decoded.Type, decoder: Decoder) -> AnyPublisher<DecodedOutput<Decoded>, HTTPURLError> where Decoder.Input == Data {
        tryMap { output in
            do {
                let decoded = try decoder.decode(type, from: output.data)
                return (decoded, output.response)
            } catch {
                throw HTTPURLError.failDecode(data: output.data, response: output.response, decodeError: error)
            }
        }
        .mapError { $0.asHTTPURLError() }
        .eraseToAnyPublisher()
    }
}
