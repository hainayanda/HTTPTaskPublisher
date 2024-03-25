//
//  URLSession+Extensions.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation

extension URLSession {
    
    public func httpTaskPublisher(
        for urlRequest: URLRequest, adapter: HTTPDataTaskAdapter? = nil,
        whenDuplicated handle: DuplicationHandling = .alwaysCreateNew) -> HTTPDataTaskPublisher {
            HTTPDataTaskPublisher(
                dataTaskFactory: self, urlRequest: urlRequest,
                adapter: adapter, duplicationHandler: handle
            )
        }
    
}
