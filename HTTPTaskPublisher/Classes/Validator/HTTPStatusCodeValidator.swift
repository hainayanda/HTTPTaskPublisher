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
    
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation {
        allowedStatusCodes.contains(response.statusCode)
        ? .valid
        : .invalid(reason: "Unexpected status code: \(response.statusCode)")
    }
}

// MARK: Publisher + HTTPStatusCodeValidator

extension Publisher where Self: HTTPDataTaskDemandable, Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func allowed(statusCodes: [Int]) -> URLSession.HTTPValid {
        validate(using: HTTPStatusCodeValidator(allowedStatusCodes: statusCodes))
    }
    
    public func allowed(statusCode: Int) -> URLSession.HTTPValid {
        allowed(statusCodes: [statusCode])
    }
    
    public func allowed(statusCodes: Int...) -> URLSession.HTTPValid {
        allowed(statusCodes: statusCodes)
    }
    
    public func allowed(statusCodes: Range<Int>) -> URLSession.HTTPValid {
        allowed(statusCodes: Array(statusCodes))
    }
    
    public func allowed(statusCodes: ClosedRange<Int>) -> URLSession.HTTPValid {
        allowed(statusCodes: Array(statusCodes))
    }
}
