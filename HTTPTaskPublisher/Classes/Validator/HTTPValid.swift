//
//  HTTPValid.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

extension URLSession {
    
    public final class HTTPValid: HTTPDataTaskDemandableSubscriber {
        
        let validator: HTTPDataTaskValidator
        let resultSubject: PassthroughSubject<Output, Failure> = .init()
        
        var subscription: Subscription?
        
        init(validator: HTTPDataTaskValidator) {
            self.validator = validator
        }
        
        public func receive<S>(subscriber: S)
        where S: Subscriber, HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
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
                resultSubject.send(
                    completion: .failure(
                        HTTPURLError.failValidation(
                            reason: reason,
                            data: input.data,
                            response: input.response
                        )
                    )
                )
            }
            return .none
        }
        
        public func receive(completion: Subscribers.Completion<HTTPURLError>) {
            resultSubject.send(completion: completion)
        }
        
        func demand(
            _ outputConsumer: @escaping ((data: Data, response: HTTPURLResponse)) -> Void,
            cleanUp: @escaping (HTTPURLError?) -> Void) -> AnyCancellable {
                defer {
                    subscription?.request(.max(1))
                }
                return resultSubject.sink { completion in
                    switch completion {
                    case .finished:
                        cleanUp(nil)
                    case .failure(let error):
                        cleanUp(error)
                    }
                } receiveValue: { response in
                    outputConsumer(response)
                }
            }
    }
}

// MARK: Publisher + Extensions

extension Publisher where Output == HTTPURLResponseOutput, Failure == HTTPURLError {
    
    public func validate(using validator: HTTPDataTaskValidator) -> URLSession.HTTPValid {
        let httpValidator = URLSession.HTTPValid(validator: validator)
        self.subscribe(httpValidator)
        return httpValidator
    }
}
