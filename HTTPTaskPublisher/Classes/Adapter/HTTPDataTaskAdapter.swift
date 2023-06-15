//
//  HTTPDataTaskAdapter.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation

// MARK: HTTPDataTaskAdaptation

public enum HTTPDataTaskAdaptation: Equatable {
    case retryWithNewRequest(URLRequest)
    case retry
    case dropWithReason(reason: String)
    case drop
}

// MARK: HTTPDataTaskAdapter

public protocol HTTPDataTaskAdapter {
    func httpDataTaskShouldAdapt(for error: HTTPURLError, request: URLRequest) async throws -> HTTPDataTaskAdaptation
}
