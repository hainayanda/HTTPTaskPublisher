//
//  HTTPClosureAdapter.swift
//  CombineAsync
//
//  Created by Nayanda Haberty on 15/6/23.
//

import Foundation

struct HTTPClosureAdapter: HTTPDataTaskAdapter {
    
    typealias AdapterClosure = (URLRequest) async throws -> URLRequest
    
    let adaptClosure: AdapterClosure
    
    init(_ adaptClosure: @escaping AdapterClosure) {
        self.adaptClosure = adaptClosure
    }
    
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest {
        try await self.adaptClosure(request)
    }
}

// MARK: URLRequestSender + HTTPClosureAdapter

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func adapt(for adapter: @escaping (URLRequest) async throws -> URLRequest) -> URLSession.HTTPAdapt<Self> {
        adapt(using: HTTPClosureAdapter(adapter))
    }
    
}
