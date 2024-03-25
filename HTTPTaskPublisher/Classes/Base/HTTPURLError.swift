//
//  HTTPURLError.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

public indirect enum HTTPURLError: Error {
    case failWhileRetry(error: Error, originalError: HTTPURLError)
    case failToRetry(reason: String, originalError: HTTPURLError)
    case failWhileAdapt(request: URLRequest, originalError: Error)
    case failDecode(data: Data, response: HTTPURLResponse, decodeError: Error)
    case failValidation(reason: String, data: Data, response: HTTPURLResponse)
    case expectHTTPResponse(data: Data, response: URLResponse)
    case urlError(URLError)
    case error(Error)
}

extension HTTPURLError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .failWhileRetry(let error, let originalError):
            return "HTTPTaskPublisher fail while retrying with statusCode: \(statusCode ?? -1), error: \(error)\nOriginal Error: \(originalError)"
        case .failToRetry(let reason, let originalError):
            return "HTTPTaskPublisher fail to retry with statusCode: \(statusCode ?? -1), reason: \(reason)\nOriginal Error: \(originalError)"
        case .failWhileAdapt(let request, let originalError):
            return "HTTPTaskPublisher fail while adapting request with statusCode: \(statusCode ?? -1), url: \(request.url?.absoluteString ?? "none")\nOriginal Error: \(originalError)"
        case .failDecode(_, let response, let decodeError):
            return "HTTPTaskPublisher fail decoding data from response: \(response.url?.absoluteString ?? "none")\nOriginal Error: \(decodeError)"
        case .failValidation(let reason, let data, let response):
            return "HTTPTaskPublisher fail validating response with statusCode: \(statusCode ?? -1), url: \(response.url?.absoluteString ?? "none"), reason: \(reason)"
        case .expectHTTPResponse(_, let response):
            return "HTTPTaskPublisher fail because response is not http response: \(response.url?.absoluteString ?? "none")"
        case .urlError(let urlError):
            return "HTTPTaskPublisher fail with URLError: \(urlError)"
        case .error(let error):
            return "HTTPTaskPublisher fail with statusCode: \(statusCode ?? -1), Error: \(error)"
        }
    }
}

extension HTTPURLError {
    public var statusCode: Int? {
        switch self {
        case .failWhileRetry(let error, let orignalError):
            return error.asHTTPURLError().statusCode ?? orignalError.statusCode
        case .failToRetry(_, let orignalError):
            return orignalError.statusCode
        case .failValidation(_, _, let response), .failDecode(_, let response, _):
            return response.statusCode
        case .failWhileAdapt(_, let error):
            return error.asHTTPURLError().statusCode
        case .error(let error):
            return (error as? HTTPURLError)?.statusCode
        default:
            return nil
        }
    }
}

extension Error {
    func asHTTPURLError() -> HTTPURLError {
        if let httpError = self as? HTTPURLError {
            return httpError
        } else if let urlError = self as? URLError {
            return .urlError(urlError)
        } else {
            return .error(self)
        }
    }
}

extension Publisher {
    func mapErrorToHTTPURLError() -> Publishers.MapError<Self, HTTPURLError> {
        mapError { $0.asHTTPURLError() }
    }
}
