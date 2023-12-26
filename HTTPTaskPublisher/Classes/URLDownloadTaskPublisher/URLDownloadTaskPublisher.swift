//
//  URLDownloadTask+Extensions.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 25/12/23.
//

import Foundation
import Combine

public protocol URLDownloadTaskReceiver: CustomCombineIdentifierConvertible {
    func acceptResponse(_ response: DownloadResponseOutput)
    func acceptError(error: DownloadURLError)
    func acceptTermination()
}

public protocol URLDownloadTaskDemandable: AnyObject {
    func demandOutput(from receiver: URLDownloadTaskReceiver)
}

public typealias DownloadURLResponseOutput = (fileUrl: URL, response: URLResponse)

extension URLSession {
    
    public class URLDownloadTaskPublisher: Publisher, AtomicSubscribeable, URLDownloadTaskDemandable {
        
        public typealias Output = DownloadResponseOutput
        public typealias Failure = DownloadURLError
        
        let downloadTaskFactory: DownloadTaskPublisherFactory
        let duplicationHandling: DuplicationHandling
        let adapter: HTTPDataTaskAdapter?
        let atomicQueue: DispatchQueue = .init(label: UUID().uuidString, qos: .background)
        var downloadRequest: DownloadRequest
        weak var ongoingRequest: AnyCancellable?
        weak var ongoingDownloadTask: URLSessionDownloadTask?
        var subscribers: [CombineIdentifier: CustomCombineIdentifierConvertible] = [:]
        
        init(downloadTaskFactory: DownloadTaskPublisherFactory, downloadRequest: DownloadRequest, adapter: HTTPDataTaskAdapter?, duplicationHandling: DuplicationHandling) {
            self.downloadTaskFactory = downloadTaskFactory
            self.downloadRequest = downloadRequest
            self.duplicationHandling = duplicationHandling
            self.adapter = adapter
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, DownloadURLError == S.Failure, DownloadResponseOutput == S.Input {
            let subscription = URLDownloadTaskSubscription(publisher: self, subscriber: subscriber)
            subscriber.receive(subscription: subscription)
        }
        
        public func demandOutput(from receiver: URLDownloadTaskReceiver) {
            subscribers[receiver.combineIdentifier] = receiver
            guard let adapter else {
                demandOutput(using: downloadRequest)
                return
            }
            switch downloadRequest {
            case .resumeData:
                demandOutput(using: downloadRequest)
            case .urlRequest(let urlRequest):
                Task {
                    do {
                        let adaptedRequest = try await adapter.httpDataTaskAdapt(for: urlRequest)
                        demandOutput(using: .urlRequest(urlRequest))
                    } catch {
                        dequeueSubscriber(with: .failWhileAdapt(request: urlRequest, originalError: error))
                    }
                }
            }
        }
        
        public func cancelEmitingResumeData() {
            guard let ongoingDownloadTask else { return }
            ongoingDownloadTask.cancel { data in
                guard let data else {
                    self.terminateAllSubscribers()
                    return
                }
                self.dequeueSubscriberIfNeeded(with: .cancelled(resumeData: data))
            }
        }
        
        public func demandOutput(using downloadRequest: DownloadRequest) {
            guard ongoingRequest == nil, ongoingDownloadTask == nil else { return }
            var cancellable: AnyCancellable?
            let pairs = downloadTaskFactory
                .anyDownloadTaskPublisherPairs(for: downloadRequest, duplicationHandling: duplicationHandling)
            cancellable = pairs.publisher
                .sink { [weak self] completion in
                    defer { cancellable = nil }
                    guard case .failure(let error) = completion else {
                        self?.terminateAllSubscribers()
                        return
                    }
                    self?.dequeueSubscriber(with: .urlError(error))
                } receiveValue: { [weak self] output in
                    self?.dequeueSubscriberIfNeeded(with: output)
                    cancellable?.cancel()
                    cancellable = nil
                }
            ongoingDownloadTask = pairs.task
            ongoingRequest = cancellable
        }
    }
    
    class URLDownloadTaskSubscription<S: Subscriber>: Subscription, URLDownloadTaskReceiver where S.Failure == DownloadURLError, S.Input == DownloadResponseOutput {
        
        var publisher: URLDownloadTaskDemandable?
        var subscriber: S?
        var demand: Subscribers.Demand = .none
        
        init(publisher: URLDownloadTaskDemandable, subscriber: S) {
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
        
        func acceptResponse(_ response: DownloadResponseOutput) {
            guard let subscriber else { return }
            _ = subscriber.receive(response)
        }
        
        func acceptError(error: DownloadURLError) {
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
    
    func dequeueSubscriberIfNeeded(with response: DownloadResponseOutput) {
        switch response {
        case .downloading:
            forEachSubscriber(tryCastTo: URLDownloadTaskReceiver.self) { subscriber in
                subscriber.acceptResponse(response)
            }
        default:
            dequeueAllSubscriber(tryCastTo: URLDownloadTaskReceiver.self) { subscriber in
                subscriber.acceptResponse(response)
                subscriber.acceptTermination()
            }
        }
    }
    
    func dequeueSubscriber(with error: DownloadURLError) {
        dequeueAllSubscriber(tryCastTo: URLDownloadTaskReceiver.self) { subscriber in
            subscriber.acceptError(error: error)
        }
    }
    
    func terminateAllSubscribers() {
        dequeueAllSubscriber(tryCastTo: URLDownloadTaskReceiver.self) { subscriber in
            subscriber.acceptTermination()
        }
    }
}
