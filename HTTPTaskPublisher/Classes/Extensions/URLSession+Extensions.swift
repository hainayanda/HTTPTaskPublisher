//
//  URLSession+Extensions.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation

extension URLSession {
    
    public func httpTaskPublisher(for urlRequest: URLRequest, adapter: HTTPDataTaskAdapter? = nil, whenDuplicated handle: DuplicationHandling = .alwaysCreateNew) -> HTTPDataTaskPublisher {
        HTTPDataTaskPublisher(dataTaskFactory: self, urlRequest: urlRequest, adapter: adapter, duplicationHandling: handle)
    }
    
    public func downloadTaskPublisher(for urlRequest: URLRequest, adapter: HTTPDataTaskAdapter? = nil, whenDuplicated handle: DuplicationHandling = .alwaysCreateNew) -> URLDownloadTaskPublisher {
        URLDownloadTaskPublisher(downloadTaskFactory: self, downloadRequest: .urlRequest(urlRequest), adapter: adapter, duplicationHandling: handle)
    }
    
    public func downloadTaskPublisher(with resumeData: Data, adapter: HTTPDataTaskAdapter? = nil, whenDuplicated handle: DuplicationHandling = .alwaysCreateNew) -> URLDownloadTaskPublisher {
        URLDownloadTaskPublisher(downloadTaskFactory: self, downloadRequest: .resumeData(resumeData), adapter: adapter, duplicationHandling: handle)
    }
}
