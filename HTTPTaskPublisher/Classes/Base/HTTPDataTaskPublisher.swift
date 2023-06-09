//
//  HTTPTaskPublisher.swift
//  HTTPDataTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine
import CombineAsync

public protocol URLRequestSender {
    associatedtype Response
    var urlRequest: URLRequest { get }
    mutating func send() async throws -> Response
    mutating func send(request: URLRequest) async throws -> Response
}

extension URLRequestSender {
    public mutating func send() async throws -> Response {
        try await send(request: urlRequest)
    }
}

extension URLSession {
    
    public struct HTTPDataTaskPublisher: Publisher, URLRequestSender {
        public typealias Response = (data: Data, response: HTTPURLResponse)
        public typealias Output = Response
        public typealias Failure = HTTPURLError
        
        let dataTaskFactory: DataTaskPublisherFactory
        let duplicationHandling: DuplicationHandling
        public internal(set) var urlRequest: URLRequest
        
        init(dataTaskFactory: DataTaskPublisherFactory, urlRequest: URLRequest, duplicationHandling: DuplicationHandling) {
            self.dataTaskFactory = dataTaskFactory
            self.urlRequest = urlRequest
            self.duplicationHandling = duplicationHandling
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, HTTPURLError == S.Failure, Response == S.Input {
            let subscription = HTTPDataTaskSubscription(sender: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        mutating public func send(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
            self.urlRequest = request
            return try await dataTaskFactory
                .anyDataTaskPublisher(for: request, duplicationHandling: duplicationHandling)
                .httpResponseOnly()
                .sinkAsynchronously(timeout: request.timeoutInterval)
        }
    }
}
