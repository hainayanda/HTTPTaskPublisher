//
//  MockablePublisher.swift
//  HTTPTaskPublisher_Tests
//
//  Created by Nayanda Haberty on 16/6/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import Combine
@testable import HTTPTaskPublisher

class MockablePublisher: Publisher, HTTPDataTaskDemandable {
    
    typealias Output = (data: Data, response: HTTPURLResponse)
    typealias Failure = HTTPURLError
    
    let result: Result<(data: Data, response: HTTPURLResponse), HTTPURLError>
    
    init(_ result: Result<(data: Data, response: HTTPURLResponse), HTTPURLError>) {
        self.result = result
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, HTTPTaskPublisher.HTTPURLError == S.Failure, (data: Data, response: HTTPURLResponse) == S.Input {
        let subscription = URLSession.HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
    
    func demandOutput(from receiver: HTTPTaskPublisher.HTTPDataTaskReceiver) {
        switch result {
        case .success(let output):
            receiver.acceptResponse(data: output.data, response: output.response)
        case .failure(let error):
            receiver.acceptError(error: error)
        }
    }
    
}

extension URLRequest {
    static var dummy: URLRequest {
        URLRequest(url: URL(string: "http://www.dummy.com")!)
    }
}

// MARK: DataTaskFactoryMock

class DataTaskFactoryMock: DataTaskPublisherFactory {
    
    let result: Result<(data: Data, response: URLResponse), URLError>
    var request: URLRequest?
    
    init(result: Result<(data: Data, response: URLResponse), URLError>) {
        self.result = result
    }
    
    func anyDataTaskPublisher(for request: URLRequest, duplicationHandling: DuplicationHandling) -> Future<(data: Data, response: URLResponse), URLError> {
        self.request = request
        let result = self.result
        return Future { promise in
            promise(result)
        }
    }
}
