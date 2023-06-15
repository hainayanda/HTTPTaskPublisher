//
//  HTTPDataTaskInterceptor.swift
//  CombineAsync
//
//  Created by Nayanda Haberty on 15/6/23.
//

import Foundation

public typealias HTTPDataTaskInterceptor = HTTPDataTaskAdapter & HTTPDataTaskRetrier

// MARK: URLRequestSender + HTTPDataTaskInterceptor

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public typealias HTTPIntercept = URLSession.HTTPRetry<URLSession.HTTPAdapt<Self>>
    
    public func intercept(using interceptor: HTTPDataTaskInterceptor) -> HTTPIntercept {
        adapt(using: interceptor).retrying(using: interceptor)
    }
}
