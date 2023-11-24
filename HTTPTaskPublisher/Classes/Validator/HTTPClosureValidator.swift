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

// MARK: Publisher + HTTPClosureValidator

extension Publisher where Self: HTTPDataTaskDemandable, Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func validate(_ validator: @escaping (Data, HTTPURLResponse) -> HTTPDataTaskValidation) -> URLSession.HTTPValid<Self> {
        validate(using: HTTPClosureValidator(validator: validator))
    }
}
