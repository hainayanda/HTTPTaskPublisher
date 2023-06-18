//
//  URLSession+Extensions.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation

extension URLSession {
    
    public func httpTaskPublisher(for urlRequest: URLRequest) -> HTTPDataTaskPublisher {
        HTTPDataTaskPublisher(dataTaskFactory: self, urlRequest: urlRequest)
    }
    
}
