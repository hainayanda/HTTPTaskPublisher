//
//  HTTPRetry.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public final class HTTPRetry: HTTPDataTaskDemandable, Subscriber {

        public typealias Input = HTTPURLResponseOutput
        
        let retrier: HTTPDataTaskRetrier
        let retryDelay: TimeInterval
        let resultSubject: PassthroughSubject<Output, Failure> = .init()
        
        var subscription: Subscription?
        
        init(retrier: HTTPDataTaskRetrier, retryDelay: TimeInterval = 0.1) {
            self.retrier = retrier
            self.retryDelay = retryDelay
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public func receive(subscription: any Subscription) {
            self.subscription = subscription
        }
        
        public func receive(_ input: HTTPURLResponseOutput) -> Subscribers.Demand {
            resultSubject.send(input)
            return .none
        }
        
        public func receive(completion: Subscribers.Completion<HTTPURLError>) {
            switch completion {
            case .finished:
                resultSubject.send(completion: completion)
                return
            case .failure(let error):
                guard let subscription else {
                    resultSubject.send(completion: .failure(error))
                    return
                }
                let retrier = self.retrier
                Task {
                    let retryDecision = try await retrier.httpDataTaskShouldRetry(for: error)
                    switch retryDecision {
                    case .retry:
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        subscription.request(.max(1))
                    case .dropWithReason(let reason):
                        resultSubject.send(completion: .failure(HTTPURLError.failToRetry(reason: reason, originalError: error)))
                    case .drop:
                        resultSubject.send(completion: .failure(error))
                    }
                }
            }
        }
        
        public func demand(_ resultConsumer: @escaping (Result<HTTPURLResponseOutput, HTTPURLError>) -> Void) -> AnyCancellable {
            defer {
                subscription?.request(.max(1))
            }
            return resultSubject.sink { completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    resultConsumer(.failure(error))
                }
            } receiveValue: { response in
                resultConsumer(.success(response))
            }
        }
    }
}

// MARK: Publisher + Extensions

extension Publisher where Self: HTTPDataTaskDemandable, Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func retrying(using retrier: HTTPDataTaskRetrier, retryDelay: TimeInterval = 0.1) -> URLSession.HTTPRetry {
        let retrier = URLSession.HTTPRetry(retrier: retrier, retryDelay: retryDelay)
        self.subscribe(retrier)
        return retrier
    }
}
