//
//  HTTPDataTaskValidator.swift
//  CombineAsync
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation

// MARK: HTTPDataTaskValidation

public enum HTTPDataTaskValidation: Equatable {
    case valid
    case invalid(reason: String)
}

// MARK: HTTPDataTaskValidator

public protocol HTTPDataTaskValidator {
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation
}
