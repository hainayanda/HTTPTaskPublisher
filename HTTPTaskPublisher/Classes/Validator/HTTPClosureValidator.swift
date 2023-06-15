//
//  HTTPClosureValidator.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

// MARK: HTTPClosureValidator

struct HTTPClosureValidator: HTTPDataTaskValidator {
    
    typealias ValidatorClosure = (Data, HTTPURLResponse) -> HTTPDataTaskValidation
    let validator: ValidatorClosure
    
    init(validator: @escaping ValidatorClosure) {
        self.validator = validator
    }
    
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation {
        validator(data, response)
    }
}

// MARK: HTTPDataRequestable + HTTPStatusCodeValidator

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func validate(_ validator: @escaping (Data, HTTPURLResponse) -> HTTPDataTaskValidation) -> URLSession.HTTPValid<Self> {
        validate(using: HTTPClosureValidator(validator: validator))
    }
}
