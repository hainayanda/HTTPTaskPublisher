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

final class MockablePublisher: HTTPDataTaskDemandable {
    
    @Published var result: Result<HTTPURLResponseOutput, HTTPURLError>
    
    init(_ result: Result<HTTPURLResponseOutput, HTTPURLError>) {
        self.result = result
    }
    
    func receive<S>(subscriber: S)
    where S: Subscriber, HTTPTaskPublisher.HTTPURLError == S.Failure, HTTPURLResponseOutput == S.Input {
        let subscription = URLSession.HTTPDataTaskSubscription(publisher: self, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
    
    func demand(_ resultConsumer: @escaping (Result<HTTPURLResponseOutput, HTTPURLError>) -> Void) -> AnyCancellable {
        $result
            .delay(for: .microseconds(1), scheduler: RunLoop.main)
            .sink(receiveValue: resultConsumer)
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
    
    func anyDataTaskPublisher(
        for request: URLRequest,
        duplicationHandler duplicationHandling: DuplicationHandling) -> Future<URLResponseOutput, URLError> {
            self.request = request
            let result = self.result
            return Future { promise in
                promise(result)
            }
        }
}
