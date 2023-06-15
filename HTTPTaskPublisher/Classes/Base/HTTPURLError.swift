//
//  HTTPURLError.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

public indirect enum HTTPURLError: Error {
    case failProduceFormData(reason: String)
    case failWhileAdapt(error: Error, request: URLRequest, orignalError: HTTPURLError)
    case failToAdapt(reason: String, request: URLRequest, orignalError: HTTPURLError)
    case failDecode(data: Data, response: HTTPURLResponse, decodeError: Error)
    case failValidation(reason: String, data: Data, response: HTTPURLResponse)
    case expectHTTPResponse(data: Data, response: URLResponse)
    case urlError(URLError)
    case error(Error)
}

extension HTTPURLError {
    public var statusCode: Int? {
        switch self {
        case .failWhileAdapt(let error, _, let orignalError):
            return error.asHTTPURLError().statusCode ?? orignalError.statusCode
        case .failToAdapt(_, _, let orignalError):
            return orignalError.statusCode
        case .failValidation(_, _, let response), .failDecode(_, let response, _):
            return response.statusCode
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
