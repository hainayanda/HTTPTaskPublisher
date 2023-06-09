//
//  HTTPDataTaskPublisher+Validator.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

// MARK: HTTPStatusCodeValidator

struct HTTPStatusCodeValidator: HTTPDataTaskValidator {
    
    let allowedStatusCodes: [Int]
    
    init(allowedStatusCodes: [Int]) {
        self.allowedStatusCodes = allowedStatusCodes
    }
    
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation {
        allowedStatusCodes.contains(response.statusCode)
        ? .valid
        : .invalid(reason: "Unexpected status code: \(response.statusCode)")
    }
}

// MARK: URLRequestSender + HTTPStatusCodeValidator

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func allowed(statusCodes: [Int]) -> URLSession.HTTPValid<Self> {
        validate(using: HTTPStatusCodeValidator(allowedStatusCodes: statusCodes))
    }
    
    public func allowed(statusCode: Int) -> URLSession.HTTPValid<Self> {
        allowed(statusCodes: [statusCode])
    }
    
    public func allowed(statusCodes: Int...) -> URLSession.HTTPValid<Self> {
        allowed(statusCodes: statusCodes)
    }
    
    public func allowed(statusCodes: Range<Int>) -> URLSession.HTTPValid<Self> {
        allowed(statusCodes: Array(statusCodes))
    }
    
    public func allowed(statusCodes: ClosedRange<Int>) -> URLSession.HTTPValid<Self> {
        allowed(statusCodes: Array(statusCodes))
    }
}
