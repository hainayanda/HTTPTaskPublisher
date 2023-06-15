//
//  HTTPClosureRetrier.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 27/5/23.
//

import Foundation

struct HTTPClosureRetrier: HTTPDataTaskRetrier {
    
    typealias RetrierClosure = (HTTPURLError, URLRequest) async throws -> HTTPDataTaskRetryDecision
    
    let retryClosure: RetrierClosure
    
    init(_ retryClosure: @escaping RetrierClosure) {
        self.retryClosure = retryClosure
    }
    
    func httpDataTaskShouldRetry(for error: HTTPURLError, request: URLRequest) async throws -> HTTPDataTaskRetryDecision {
        try await retryClosure(error, request)
    }
}

// MARK: URLRequestSender + HTTPClosureAdapter

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func retryDecision(for retrier: @escaping (HTTPURLError, URLRequest) async throws -> HTTPDataTaskRetryDecision) -> URLSession.HTTPRetry<Self> {
        retrying(using: HTTPClosureRetrier(retrier))
    }
    
}
