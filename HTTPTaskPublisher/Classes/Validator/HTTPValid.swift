//
//  HTTPValid.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public final class HTTPValid: HTTPDataTaskDemandable, Publisher, Subscriber {
        
        public typealias Input = HTTPURLResponseOutput
        
        let validator: HTTPDataTaskValidator
        let resultSubject: PassthroughSubject<Output, Failure> = .init()
        
        var subscription: Subscription?
        
        init(validator: HTTPDataTaskValidator) {
            self.validator = validator
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public func receive(subscription: any Subscription) {
            self.subscription = subscription
        }
        
        public func receive(_ input: HTTPURLResponseOutput) -> Subscribers.Demand {
            switch validator.httpDataTaskIsValid(for: input.data, response: input.response) {
            case .valid:
                resultSubject.send(input)
            case .invalid(let reason):
                resultSubject.send(completion: .failure( HTTPURLError.failValidation(reason: reason, data: input.data, response: input.response)))
            }
            return .none
        }
        
        public func receive(completion: Subscribers.Completion<HTTPURLError>) {
            resultSubject.send(completion: completion)
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
    
    public func validate(using validator: HTTPDataTaskValidator) -> URLSession.HTTPValid {
        let httpValidator = URLSession.HTTPValid(validator: validator)
        self.subscribe(httpValidator)
        return httpValidator
    }
}
