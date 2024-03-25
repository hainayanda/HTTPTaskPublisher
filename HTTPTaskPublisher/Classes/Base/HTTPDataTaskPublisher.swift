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

extension URLSession {
    public final class HTTPDataTaskPublisher: HTTPDataTaskDemandable {
        
        private let dataTaskFactory: DataTaskPublisherFactory
        private let duplicationHandler: DuplicationHandling
        private let adapter: HTTPDataTaskAdapter?
        private let urlRequest: URLRequest
        
        init(dataTaskFactory: DataTaskPublisherFactory, urlRequest: URLRequest, adapter: HTTPDataTaskAdapter?, duplicationHandler: DuplicationHandling) {
            self.dataTaskFactory = dataTaskFactory
            self.urlRequest = urlRequest
            self.duplicationHandler = duplicationHandler
            self.adapter = adapter
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
            let subscription = HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public func demand(_ resultConsumer: @escaping (Result<HTTPURLResponseOutput, HTTPURLError>) -> Void) -> AnyCancellable {
            requestPublisher()
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
    
    final class HTTPDataTaskSubscription<S: Subscriber, P: HTTPDataTaskDemandable>: Subscription where S.Input == P.Output, S.Failure == P.Failure {
        
        private var publisher: P?
        private var subscriber: S?
        private var ongoingDemand: AnyCancellable?
        
        init(publisher: P, subscriber: S) {
            self.publisher = publisher
            self.subscriber = subscriber
        }
        
        public func request(_ demand: Subscribers.Demand) {
            guard let subscriber = self.subscriber else { return }
            demandToPublisher(for: subscriber)
        }
        
        public func cancel() {
            subscriber?.receive(completion: .finished)
            publisher = nil
            subscriber = nil
        }
        
        private func demandToPublisher(for subscriber: S) {
            guard ongoingDemand == nil else { return }
            self.ongoingDemand = publisher?.demand { [weak self] result in
                switch result {
                case .success(let success):
                    _ = subscriber.receive(success)
                    subscriber.receive(completion: .finished)
                case .failure(let failure):
                    subscriber.receive(completion: .failure(failure))
                }
                self?.ongoingDemand = nil
            }
        }
    }
}
