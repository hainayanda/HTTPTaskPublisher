//
//  HTTPTaskPublisher.swift
//  HTTPDataTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

protocol HTTPDataTaskDemandable: AnyObject, Publisher<HTTPURLResponseOutput, HTTPURLError> {
    func demand(_ resultConsumer: @escaping (Result<Output, HTTPURLError>) -> Void) -> AnyCancellable
}

protocol HTTPDataTaskDemandableSubscriber: HTTPDataTaskDemandable, Subscriber<HTTPURLResponseOutput, HTTPURLError> {
    func demand(_ resultConsumer: @escaping (Result<Output, HTTPURLError>) -> Void) -> AnyCancellable
}

extension URLSession {
    
    public final class HTTPDataTaskPublisher: HTTPDataTaskDemandable {
        
        private let dataTaskFactory: DataTaskPublisherFactory
        private let duplicationHandler: DuplicationHandling
        private let adapter: HTTPDataTaskAdapter?
        private let urlRequest: URLRequest
        
        init(
            dataTaskFactory: DataTaskPublisherFactory,
            urlRequest: URLRequest,
            adapter: HTTPDataTaskAdapter?,
            duplicationHandler: DuplicationHandling) {
                self.dataTaskFactory = dataTaskFactory
                self.urlRequest = urlRequest
                self.duplicationHandler = duplicationHandler
                self.adapter = adapter
            }
        
        public func receive<S>(subscriber: S)
        where S: Subscriber, HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        func demand(
            _ resultConsumer: @escaping (Result<HTTPURLResponseOutput, HTTPURLError>) -> Void) -> AnyCancellable {
                Future<AnyPublisher<HTTPURLResponseOutput, HTTPURLError>, HTTPURLError> { promise in
                    Task(priority: .userInitiated) {
                        await promise(.success(self.requestPublisher()))
                    }
                }
                .flatMap { $0 }
                .sink { completion in
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
        
        @HTTPDataTaskActor
        private func requestPublisher() -> AnyPublisher<HTTPURLResponseOutput, HTTPURLError> {
            let originalRequest = self.urlRequest
            guard let adapter else {
                return dataTaskFactory
                    .anyDataTaskPublisher(for: originalRequest, duplicationHandler: duplicationHandler)
                    .httpResponseOnly()
                    .eraseToAnyPublisher()
            }
            let duplicationHandling = self.duplicationHandler
            let factory = self.dataTaskFactory
            return Future { promise in
                Task(priority: .userInitiated) {
                    do {
                        let result = try await adapter.httpDataTaskAdapt(for: originalRequest)
                        promise(.success(result))
                    } catch {
                        promise(.failure(HTTPURLError.failWhileAdapt(request: originalRequest, originalError: error)))
                    }
                }
            }
            .flatMap { adaptedRequest in
                factory.anyDataTaskPublisher(for: adaptedRequest, duplicationHandler: duplicationHandling)
                    .httpResponseOnly()
            }
            .eraseToAnyPublisher()
        }
        
    }
    
    actor HTTPDataTaskSubscription<S: Subscriber, P: HTTPDataTaskDemandable>: Subscription
    where S.Input == P.Output, S.Failure == P.Failure {
        
        private var publisher: P?
        private var subscriber: S?
        private var ongoingDemand: AnyCancellable?
        
        init(publisher: P, subscriber: S) {
            self.publisher = publisher
            self.subscriber = subscriber
        }
        
        nonisolated public func request(_ demand: Subscribers.Demand) {
            Task(priority: .userInitiated) {
                await demandToPublisher()
            }
        }
        
        nonisolated public func cancel() {
            Task(priority: .userInitiated) {
                await cancelling()
            }
        }
        
        private func demandToPublisher() {
            guard ongoingDemand == nil, let subscriber = self.subscriber else { return }
            self.ongoingDemand = publisher?.demand { [weak self] result in
                switch result {
                case .success(let success):
                    _ = subscriber.receive(success)
                    subscriber.receive(completion: .finished)
                case .failure(let failure):
                    subscriber.receive(completion: .failure(failure))
                }
                guard let self else { return }
                Task {
                    await self.clearDemand()
                }
            }
        }
        
        private func cancelling() {
            subscriber?.receive(completion: .finished)
            publisher = nil
            subscriber = nil
        }
        
        private func clearDemand() {
            ongoingDemand?.cancel()
            ongoingDemand = nil
        }
    }
}
