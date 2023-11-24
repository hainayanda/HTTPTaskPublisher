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
    
    typealias Output = HTTPURLResponseOutput
    typealias Failure = HTTPURLError
    
    let result: Result<HTTPURLResponseOutput, HTTPURLError>
    
    init(_ result: Result<HTTPURLResponseOutput, HTTPURLError>) {
        self.result = result
    }
    
    func receive<S>(subscriber: S) where S: Subscriber, HTTPTaskPublisher.HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
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
    
    let result: Result<URLResponseOutput, URLError>
    var request: URLRequest?
    
    init(result: Result<URLResponseOutput, URLError>) {
        self.result = result
    }
    
    func anyDataTaskPublisher(for request: URLRequest, duplicationHandling: DuplicationHandling) -> Future<URLResponseOutput, URLError> {
        self.request = request
        let result = self.result
        return Future { promise in
            promise(result)
        }
    }
}
