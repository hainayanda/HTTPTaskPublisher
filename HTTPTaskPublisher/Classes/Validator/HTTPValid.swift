//
//  HTTPValid.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public struct HTTPValid<Sender: URLRequestSender>: Publisher, URLRequestSender where Sender.Response == (data: Data, response: HTTPURLResponse) {
        
        public typealias Response = Sender.Response
        public typealias Output = Response
        public typealias Failure = HTTPURLError
        
        var sender: Sender
        let validator: HTTPDataTaskValidator
        public var urlRequest: URLRequest { sender.urlRequest }
        
        init(sender: Sender, validator: HTTPDataTaskValidator) {
            self.sender = sender
            self.validator = validator
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, HTTPURLError == S.Failure, Response == S.Input {
            let subscription = HTTPDataTaskSubscription(sender: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public mutating func send(request: URLRequest) async throws -> Response {
            do {
                let output = try await sender.send(request: request)
                switch validator.httpDataTaskIsValid(for: output.data, response: output.response) {
                case .valid:
                    return output
                case .invalid(let reason):
                    throw HTTPURLError.failValidation(reason: reason, data: output.data, response: output.response)
                }
            } catch {
                throw error.asHTTPURLError()
            }
        }
    }
}

// MARK: URLRequestSender + Extensions

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func validate(using validator: HTTPDataTaskValidator) -> URLSession.HTTPValid<Self> {
        URLSession.HTTPValid(sender: self, validator: validator)
    }
}
