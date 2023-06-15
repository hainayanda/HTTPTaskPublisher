//
//  HTTPDataTaskSubscription.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/5/23.
//

import Foundation
import Combine

class HTTPDataTaskSubscription<S: Subscriber, P: URLRequestSender>: Subscription
where S.Failure == HTTPURLError, S.Input == URLSession.HTTPDataTaskPublisher.Response,
      P.Response == URLSession.HTTPDataTaskPublisher.Response {
    
    var subscriber: S?
    var sender: P
    
    init(sender: P, subscriber: S) {
        self.sender = sender
        self.subscriber = subscriber
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard subscriber != nil, demand > 0 else {
            subscriber?.receive(completion: .finished)
            return
        }
        Task { [weak self] in
            await self?.requestToPublisher()
        }
    }
    
    func cancel() {
        subscriber = nil
    }
    
    private func requestToPublisher() async {
        do {
            let output = try await sender.send()
            let nextDemand = subscriber?.receive(output)
            guard let nextDemand else {
                subscriber?.receive(completion: .finished)
                return
            }
            request(nextDemand)
        } catch {
            subscriber?.receive(completion: .failure(error.asHTTPURLError()))
        }
    }
}
