//
//  DataTaskPublisherFactory.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 16/6/23.
//

import Foundation
import Combine

protocol DataTaskPublisherFactory {
    func anyDataTaskPublisher(for request: URLRequest, duplicationHandling: DuplicationHandling) -> Future<(data: Data, response: URLResponse), URLError>
}

public enum DuplicationHandling {
    /// always create a new data task request no matter what
    case alwaysCreateNew
    /// subscribe to the current ongoing identical task if have any, otherwise, create a new data task
    case useCurrentIfPossible
    /// cancel the request if there is an ongoing identical task, otherwise, create a new data task
    case dropIfDuplicated
}

private var ongoingRequestKey: String = "ongoingRequestKey"

extension URLSession: DataTaskPublisherFactory {
    
    private var ongoingRequest: [URLRequest: WeakFutureWrapper] {
        get {
            objc_getAssociatedObject(self, &ongoingRequestKey) as? [URLRequest: WeakFutureWrapper] ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &ongoingRequestKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func anyDataTaskPublisher(for request: URLRequest, duplicationHandling: DuplicationHandling) -> Future<(data: Data, response: URLResponse), URLError> {
        switch duplicationHandling {
        case .useCurrentIfPossible:
            return getPublisher(of: request)
        case .dropIfDuplicated:
            guard ongoingRequest[request]?.future == nil else {
                return Future { $0(.failure(URLError(.cancelled))) }
            }
        case .alwaysCreateNew:
            break
        }
        return createNewPublisher(for: request)
    }
    
    private func getPublisher(of request: URLRequest) -> Future<(data: Data, response: URLResponse), URLError> {
        guard let currentPublisher = ongoingRequest[request]?.future else {
            return createNewPublisher(for: request)
        }
        return currentPublisher
    }
    
    private func createNewPublisher(for request: URLRequest) -> Future<(data: Data, response: URLResponse), URLError> {
        let future: Future<(data: Data, response: URLResponse), URLError> = .init { promise in
            self.dataTask(with: request) { data, response, error in
                if let error {
                    promise(.failure(error.asUrlError))
                    return
                }
                guard let data, let response else {
                    promise(.failure(.init(.zeroByteResource)))
                    return
                }
                promise(.success((data, response)))
            }
            .resume()
        }
        ongoingRequest[request] = WeakFutureWrapper(future: future)
        return future
    }
}

struct WeakFutureWrapper {
    weak var future: Future<(data: Data, response: URLResponse), URLError>?
    
    init(future: Future<(data: Data, response: URLResponse), URLError>? = nil) {
        self.future = future
    }
}

extension Error {
    var asUrlError: URLError {
        guard let urlError = self as? URLError else {
            return .init(.unknown)
        }
        return urlError
    }
}
