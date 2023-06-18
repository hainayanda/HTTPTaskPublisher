//
//  DataTaskPublisherFactory.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 16/6/23.
//

import Foundation
import Combine

protocol DataTaskPublisherFactory {
    func anyDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError>
}

extension URLSession: DataTaskPublisherFactory {
    func anyDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        dataTaskPublisher(for: request).eraseToAnyPublisher()
    }
}
