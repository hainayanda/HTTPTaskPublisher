//
//  HTTPRetry.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public class HTTPRetry<Upstream: Publisher & HTTPDataTaskDemandable>: HTTPDataTaskSubscribable, Publisher, Subscriber
    where Upstream.Output == HTTPURLResponseOutput, Upstream.Failure == HTTPURLError {
        
        public typealias Input = HTTPURLResponseOutput
        public typealias Output = HTTPURLResponseOutput
        public typealias Failure = HTTPURLError
        
        let retrier: HTTPDataTaskRetrier
        let retryDelay: TimeInterval
        
        @HTTPDataTaskActor var subscription: Subscription?
        @HTTPDataTaskActor var subscribers: [CombineIdentifier: HTTPDataTaskReceiver] = [:]
        @HTTPDataTaskActor var isWaitingUpstream: Bool = false
        
        init(upstream: Upstream, retrier: HTTPDataTaskRetrier, retryDelay: TimeInterval = 0.1) {
            self.retrier = retrier
            self.retryDelay = retryDelay
            upstream.subscribe(self)
        }
        
        // MARK: Publisher
        
        public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, HTTPURLResponseOutput == S.Input {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        // MARK: Subscriber
        
        public func receive(subscription: Subscription) {
            Task { @HTTPDataTaskActor in
                self.subscription = subscription
                demandToUpstreamIfNeeded()
            }
        }
        
        public func receive(completion: Subscribers.Completion<Failure>) {
            Task { @HTTPDataTaskActor in
                isWaitingUpstream = false
                switch completion {
                case .finished:
                    terminateAllSubscribers()
                case .failure(let failure):
                    do {
                        try await tryToRetry(from: failure)
                    } catch {
                        dequeueSubscriber(with: HTTPURLError.failWhileRetry(error: error, originalError: failure))
                    }
                }
            }
        }
        
        public func receive(_ input: HTTPURLResponseOutput) -> Subscribers.Demand {
            Task { @HTTPDataTaskActor in
                isWaitingUpstream = false
                dequeueSubscriber(with: input.data, response: input.response)
            }
            return .none
        }
        
        @HTTPDataTaskActor
        public func demandOutput(from receiver: HTTPDataTaskReceiver) {
            subscribers[receiver.combineIdentifier] = receiver
            demandToUpstreamIfNeeded()
        }
        
        @HTTPDataTaskActor
        func tryToRetry(from failure: HTTPURLError) async throws {
            let retryDecision = try await retrier.httpDataTaskShouldRetry(for: failure)
            switch retryDecision {
            case .retry:
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                subscription?.request(.max(1))
            case .dropWithReason(let reason):
                dequeueSubscriber(with: HTTPURLError.failToRetry(reason: reason, originalError: failure))
            case .drop:
                dequeueSubscriber(with: failure)
            }
        }
        
        @HTTPDataTaskActor
        func demandToUpstreamIfNeeded() {
            guard !isWaitingUpstream, let subscription else {
                return
            }
            subscription.request(.max(1))
        }
    }
}

// MARK: Publisher + Extensions

extension Publisher where Self: HTTPDataTaskDemandable, Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func retrying(using retrier: HTTPDataTaskRetrier, retryDelay: TimeInterval = 0.1) -> URLSession.HTTPRetry<Self> {
        URLSession.HTTPRetry(upstream: self, retrier: retrier, retryDelay: retryDelay)
    }
}
