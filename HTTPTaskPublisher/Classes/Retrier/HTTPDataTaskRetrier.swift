//
//  HTTPDataTaskRetrier.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation

// MARK: HTTPDataTaskRetryDecision

public enum HTTPDataTaskRetryDecision: Equatable {
    case retry
    case dropWithReason(reason: String)
    case drop
}

// MARK: HTTPDataTaskRetrier

public protocol HTTPDataTaskRetrier {
    func httpDataTaskShouldRetry(for error: HTTPURLError) async throws -> HTTPDataTaskRetryDecision
}
