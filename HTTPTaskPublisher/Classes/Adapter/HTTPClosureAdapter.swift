//
//  HTTPClosureAdapter.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 27/5/23.
//

import Foundation

struct HTTPClosureAdapter: HTTPDataTaskAdapter {
    
    typealias AdapterClosure = (HTTPURLError, URLRequest) async throws -> HTTPDataTaskAdaptation
    
    let adaptClosure: AdapterClosure
    
    init(_ adaptClosure: @escaping AdapterClosure) {
        self.adaptClosure = adaptClosure
    }
    
    func httpDataTaskShouldAdapt(for error: HTTPURLError, request: URLRequest) async throws -> HTTPDataTaskAdaptation {
        try await adaptClosure(error, request)
    }
}

// MARK: HTTPDataRequestable + HTTPClosureAdapter

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func adapt(_ adapter: @escaping (HTTPURLError, URLRequest) async throws -> HTTPDataTaskAdaptation) -> URLSession.HTTPAdapt<Self> {
        adapt(using: HTTPClosureAdapter(adapter))
    }
    
}
