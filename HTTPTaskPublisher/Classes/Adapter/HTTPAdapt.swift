//
//  HTTPAdapt.swift
//  CombineAsync
//
//  Created by Nayanda Haberty on 15/6/23.
//

import Foundation
import Combine

extension URLSession {
    
    public struct HTTPAdapt<Sender: URLRequestSender>: Publisher, URLRequestSender where Sender.Response == (data: Data, response: HTTPURLResponse) {
        
        public typealias Response = Sender.Response
        public typealias Output = Response
        public typealias Failure = HTTPURLError
        
        var sender: Sender
        let adapter: HTTPDataTaskAdapter
        public var urlRequest: URLRequest { sender.urlRequest }
        
        init(sender: Sender, adapter: HTTPDataTaskAdapter) {
            self.sender = sender
            self.adapter = adapter
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, HTTPURLError == S.Failure, Response == S.Input {
            let subscription = HTTPDataTaskSubscription(sender: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public mutating func send(request: URLRequest) async throws -> Response {
            do {
                let adaptationRequest = try await adapter.httpDataTaskAdapt(for: request)
                return try await sender.send(request: adaptationRequest)
            } catch {
                guard let error = error as? HTTPURLError else {
                    throw HTTPURLError.failWhileAdapt(request: request, originalError: error)
                }
                throw error
            }
        }
    }
}

// MARK: URLRequestSender + Extensions

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func adapt(using adapter: HTTPDataTaskAdapter) -> URLSession.HTTPAdapt<Self> {
        URLSession.HTTPAdapt(sender: self, adapter: adapter)
    }
}
