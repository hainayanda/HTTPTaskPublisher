//
//  HTTPTaskPublisher.swift
//  HTTPDataTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

public protocol HTTPDataTaskReceiver: CustomCombineIdentifierConvertible {
    func acceptResponse(data: Data, response: HTTPURLResponse)
    func acceptError(error: HTTPURLError)
    func acceptTermination()
}

public protocol HTTPDataTaskDemandable: AnyObject {
    func demandOutput(from receiver: HTTPDataTaskReceiver)
}

public typealias HTTPURLResponseOutput = (data: Data, response: HTTPURLResponse)

extension URLSession {
    
    public typealias HTTPURLResponseOutput = (data: Data, response: HTTPURLResponse)
    
    public class HTTPDataTaskPublisher: Publisher, AtomicSubscribeable, HTTPDataTaskDemandable {
        
        public typealias Output = HTTPURLResponseOutput
        public typealias Failure = HTTPURLError
        
        let dataTaskFactory: DataTaskPublisherFactory
        let duplicationHandling: DuplicationHandling
        let adapter: HTTPDataTaskAdapter?
        let atomicQueue: DispatchQueue = .init(label: UUID().uuidString, qos: .background)
        var urlRequest: URLRequest
        weak var ongoingRequest: AnyCancellable?
        var subscribers: [CombineIdentifier: CustomCombineIdentifierConvertible] = [:]
        
        init(dataTaskFactory: DataTaskPublisherFactory, urlRequest: URLRequest, adapter: HTTPDataTaskAdapter?, duplicationHandling: DuplicationHandling) {
            self.dataTaskFactory = dataTaskFactory
            self.urlRequest = urlRequest
            self.duplicationHandling = duplicationHandling
            self.adapter = adapter
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, S.Failure == HTTPURLError, S.Input == Output {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public func demandOutput(from receiver: HTTPDataTaskReceiver) {
            subscribers[receiver.combineIdentifier] = receiver
            guard let adapter else {
                demandOutput(using: urlRequest)
                return
            }
            Task {
                do {
                    let adaptedRequest = try await adapter.httpDataTaskAdapt(for: urlRequest)
                    demandOutput(using: adaptedRequest)
                } catch {
                    dequeueSubscriber(with: HTTPURLError.failWhileAdapt(request: urlRequest, originalError: error))
                }
            }
        }
        
        public func demandOutput(using urlRequest: URLRequest) {
            guard ongoingRequest == nil else { return }
            var cancellable: AnyCancellable?
            cancellable = dataTaskFactory
                .anyDataTaskPublisher(for: urlRequest, duplicationHandling: duplicationHandling)
                .httpResponseOnly()
                .sink { [weak self] completion in
                    defer { cancellable = nil }
                    guard case .failure(let error) = completion else {
                        self?.terminateAllSubscribers()
                        return
                    }
                    self?.dequeueSubscriber(with: error)
                } receiveValue: { [weak self] response in
                    self?.dequeueSubscriber(with: response.data, response: response.response)
                    cancellable?.cancel()
                    cancellable = nil
                }
            ongoingRequest = cancellable
        }
    }
    
    class HTTPDataTaskSubscription<S: Subscriber>: Subscription, HTTPDataTaskReceiver where S.Failure == HTTPURLError, S.Input == HTTPURLResponseOutput {
        
        var publisher: HTTPDataTaskDemandable?
        var subscriber: S?
        var demand: Subscribers.Demand = .none
        
        init(publisher: HTTPDataTaskDemandable, subscriber: S) {
            self.publisher = publisher
            self.subscriber = subscriber
        }
        
        func request(_ demand: Subscribers.Demand) {
            publisher?.demandOutput(from: self)
        }
        
        func cancel() {
            publisher = nil
            subscriber = nil
        }
        
        func acceptResponse(data: Data, response: HTTPURLResponse) {
            guard let subscriber else { return }
            _ = subscriber.receive((data, response))
        }
        
        func acceptError(error: HTTPURLError) {
            guard let subscriber else { return }
            subscriber.receive(completion: .failure(error))
        }
        
        func acceptTermination() {
            guard let subscriber else { return }
            subscriber.receive(completion: .finished)
        }
    }
}

private extension AtomicSubscribeable {
    
    func dequeueSubscriber(with data: Data, response: HTTPURLResponse) {
        dequeueAllSubscriber(tryCastTo: HTTPDataTaskReceiver.self) { subscriber in
            subscriber.acceptResponse(data: data, response: response)
            subscriber.acceptTermination()
        }
    }
    
    func dequeueSubscriber(with error: HTTPURLError) {
        dequeueAllSubscriber(tryCastTo: HTTPDataTaskReceiver.self) { subscriber in
            subscriber.acceptError(error: error)
        }
    }
    
    func terminateAllSubscribers() {
        dequeueAllSubscriber(tryCastTo: HTTPDataTaskReceiver.self) { subscriber in
            subscriber.acceptTermination()
        }
    }
}
