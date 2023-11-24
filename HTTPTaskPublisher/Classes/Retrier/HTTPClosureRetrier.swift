//
//  HTTPClosureRetrier.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 27/5/23.
//

import Foundation
import Combine

struct HTTPClosureRetrier: HTTPDataTaskRetrier {
    
    typealias RetrierClosure = (HTTPURLError) async throws -> HTTPDataTaskRetryDecision
    
    let retryClosure: RetrierClosure
    
    init(_ retryClosure: @escaping RetrierClosure) {
        self.retryClosure = retryClosure
    }
    
    func httpDataTaskShouldRetry(for error: HTTPURLError) async throws -> HTTPDataTaskRetryDecision {
        try await retryClosure(error)
    }
}

// MARK: Publisher + HTTPClosureAdapter

extension Publisher where Self: HTTPDataTaskDemandable, Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func retryDecision(for retrier: @escaping (HTTPURLError) async throws -> HTTPDataTaskRetryDecision) -> URLSession.HTTPRetry<Self> {
        retrying(using: HTTPClosureRetrier(retrier))
    }
    
}
