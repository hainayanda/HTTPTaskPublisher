//
//  HTTPValid.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public class HTTPValid<Upstream: Publisher & HTTPDataTaskDemandable>: HTTPDataTaskSubscribable, Publisher, Subscriber
    where Upstream.Output == HTTPURLResponseOutput, Upstream.Failure == HTTPURLError {
        
        public typealias Input = HTTPURLResponseOutput
        public typealias Output = HTTPURLResponseOutput
        public typealias Failure = HTTPURLError
        
        let validator: HTTPDataTaskValidator
        @HTTPDataTaskActor var subscription: Subscription?
        @HTTPDataTaskActor var subscribers: [CombineIdentifier: HTTPDataTaskReceiver] = [:]
        @HTTPDataTaskActor var isWaitingUpstream: Bool = false
        
        init(upstream: Upstream, validator: HTTPDataTaskValidator) {
            self.validator = validator
            upstream.subscribe(self)
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, HTTPURLResponseOutput == S.Input {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
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
                    dequeueSubscriber(with: failure)
                }
            }
        }
        
        public func receive(_ input: HTTPURLResponseOutput) -> Subscribers.Demand {
            Task { @HTTPDataTaskActor in
                isWaitingUpstream = false
                let validation = validator.httpDataTaskIsValid(for: input.data, response: input.response)
                switch validation {
                case .valid:
                    dequeueSubscriber(with: input.data, response: input.response)
                case .invalid(let reason):
                    dequeueSubscriber(with: HTTPURLError.failValidation(reason: reason, data: input.data, response: input.response))
                }
            }
            return .none
        }
        
        @HTTPDataTaskActor
        public func demandOutput(from receiver: HTTPDataTaskReceiver) {
            subscribers[receiver.combineIdentifier] = receiver
            demandToUpstreamIfNeeded()
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
    
    public func validate(using validator: HTTPDataTaskValidator) -> URLSession.HTTPValid<Self> {
        URLSession.HTTPValid(upstream: self, validator: validator)
    }
}
