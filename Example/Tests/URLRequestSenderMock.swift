//
//  URLRequestSenderMock.swift
//  HTTPTaskPublisher_Tests
//
//  Created by Nayanda Haberty on 16/6/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import HTTPTaskPublisher

class URLRequestSenderMock: URLRequestSender {
    
    typealias Response = URLSession.HTTPDataTaskPublisher.Response
    
    let result: Result<Response, TestError>
    let urlRequest: URLRequest = .dummy
    var sentRequest: URLRequest?
    
    init(result: Result<Response, TestError>) {
        self.result = result
    }
    
    func send() async throws -> Response {
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
    
    func send(request: URLRequest) async throws -> Response {
        self.sentRequest = request
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
    
}

extension URLRequest {
    static var dummy: URLRequest {
        URLRequest(url: URL(string: "http://www.dummy.com")!)
    }
}
