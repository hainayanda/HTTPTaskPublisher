//
//  HTTPURLError.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine
import CombineAsync

public indirect enum HTTPURLError: Error {
    case failWhileRetry(error: Error, request: URLRequest, orignalError: HTTPURLError)
    case failToRetry(reason: String, request: URLRequest, orignalError: HTTPURLError)
    case failWhileAdapt(request: URLRequest, originalError: Error)
    case failDecode(data: Data, response: HTTPURLResponse, decodeError: Error)
    case failValidation(reason: String, data: Data, response: HTTPURLResponse)
    case expectHTTPResponse(data: Data, response: URLResponse)
    case urlError(URLError)
    case error(Error)
}

extension HTTPURLError {
    public var statusCode: Int? {
        switch self {
        case .failWhileRetry(let error, _, let orignalError):
            return error.asHTTPURLError().statusCode ?? orignalError.statusCode
        case .failToRetry(_, _, let orignalError):
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
        } else if self is PublisherToAsyncError {
            return HTTPURLError.urlError(URLError(.timedOut))
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
