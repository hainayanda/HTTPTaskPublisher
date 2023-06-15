//
//  HTTPRetry.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public struct HTTPRetry<Sender: URLRequestSender>: Publisher, URLRequestSender where Sender.Response == (data: Data, response: HTTPURLResponse) {
        
        public typealias Response = Sender.Response
        public typealias Output = Response
        public typealias Failure = HTTPURLError
        
        var sender: Sender
        let retrier: HTTPDataTaskRetrier
        public var urlRequest: URLRequest { sender.urlRequest }
        
        init(sender: Sender, retrier: HTTPDataTaskRetrier) {
            self.sender = sender
            self.retrier = retrier
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, HTTPURLError == S.Failure, Response == S.Input {
            let subscription = HTTPDataTaskSubscription(sender: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public mutating func send(request: URLRequest) async throws -> Response {
            do {
                return try await sender.send(request: request)
            } catch {
                return try await tryToRetry(from: error.asHTTPURLError())
            }
        }
        
        mutating func tryToRetry(from originalError: HTTPURLError) async throws -> Response {
            var isDropping: Bool = false
            do {
                let adaptation = try await retrier.httpDataTaskShouldRetry(for: originalError, request: urlRequest)
                switch adaptation {
                case .retryWithNewRequest(let urlRequest):
                    return try await send(request: urlRequest)
                case .retry:
                    return try await send()
                case .dropWithReason(let reason):
                    isDropping = true
                    throw HTTPURLError.failToAdapt(
                        reason: reason,
                        request: urlRequest,
                        orignalError: originalError.asHTTPURLError()
                    )
                case .drop:
                    isDropping = true
                    throw originalError
                }
            } catch {
                guard !isDropping else {
                    throw error
                }
                throw HTTPURLError.failWhileRetry(
                    error: error,
                    request: urlRequest,
                    orignalError: originalError
                )
            }
        }
    }
}

// MARK: HTTPDataTaskPublisher + Extensions

extension URLRequestSender where Response == URLSession.HTTPDataTaskPublisher.Response {
    
    public func adapt(using adaptor: HTTPDataTaskRetrier) -> URLSession.HTTPRetry<Self> {
        URLSession.HTTPRetry(sender: self, retrier: adaptor)
    }
}

