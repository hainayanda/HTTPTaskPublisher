//
//  HTTPClosureRetrier.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 27/5/23.
//

import Foundation
import Combine

struct HTTPClosureRetrier: HTTPDataTaskRetrier {
    
    let retryClosure: (HTTPURLError) async throws -> HTTPDataTaskRetryDecision
    
    init(_ retryClosure: @Sendable @escaping (HTTPURLError) async throws -> HTTPDataTaskRetryDecision) {
        self.retryClosure = retryClosure
    }
    
    func httpDataTaskShouldRetry(for error: HTTPURLError) async throws -> HTTPDataTaskRetryDecision {
        try await retryClosure(error)
    }
}

// MARK: Publisher + HTTPClosureAdapter

extension Publisher where Self: HTTPDataTaskDemandable, Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func retryDecision(for retrier: @Sendable @escaping (HTTPURLError) async throws -> HTTPDataTaskRetryDecision) -> URLSession.HTTPRetry {
        retrying(using: HTTPClosureRetrier(retrier))
    }
    
}
