//
//  DownloadTaskPublisherFactory.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 25/12/23.
//

import Foundation
import Combine
import Retain

public enum DownloadResponseOutput {
    case downloading(progress: Double)
    case downloaded(file: URL, response: URLResponse)
    case cancelled(resumeData: Data)
}

public protocol DownloadTaskPublisherFactory {
    func anyDownloadTaskPublisherPairs(for request: DownloadRequest, duplicationHandling: DuplicationHandling) -> DownloadTaskPairs
}

public struct DownloadTaskPairs {
    let publisher: AnyPublisher<DownloadResponseOutput, URLError>
    let task: URLSessionDownloadTask?
    
    static func failedDownloadTask(code: URLError.Code) -> DownloadTaskPairs {
        .init(publisher: Fail<DownloadResponseOutput, URLError>(error: URLError(code)).eraseToAnyPublisher(), task: nil)
    }
}

public enum DownloadRequest: Hashable {
    case resumeData(Data)
    case urlRequest(URLRequest)
}

private var ongoingDownloadKey: UnsafeMutableRawPointer = malloc(1)

extension URLSession: DownloadTaskPublisherFactory {
    
    private var ongoingDownload: [DownloadRequest: WeakDownloadWrapper] {
        get {
            objc_getAssociatedObject(self, &ongoingDownloadKey) as? [DownloadRequest: WeakDownloadWrapper] ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &ongoingDownloadKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    public func anyDownloadTaskPublisherPairs(for request: DownloadRequest, duplicationHandling: DuplicationHandling) -> DownloadTaskPairs {
        switch duplicationHandling {
        case .useCurrentIfPossible:
            return getPublisher(of: request)
        case .dropIfDuplicated:
            guard ongoingDownload[request]?.downloadTaskPairs == nil else {
                return .failedDownloadTask(code: .cancelled)
            }
        case .alwaysCreateNew:
            break
        }
        return createNewPublisher(for: request)
    }
    
    private func getPublisher(of request: DownloadRequest) -> DownloadTaskPairs {
        guard let currentPublisher = ongoingDownload[request]?.downloadTaskPairs else {
            return createNewPublisher(for: request)
        }
        return currentPublisher
    }
    
    private func createNewPublisher(for request: DownloadRequest) -> DownloadTaskPairs {
        var downloadTask: URLSessionDownloadTask?
        let future: Future<(file: URL, response: URLResponse), URLError> = .init { promise in
            let task = self.downloadTask(for: request) { fileUrl, response, error in
                if let error {
                    promise(.failure(error.asUrlError))
                    return
                }
                guard let fileUrl else {
                    promise(.failure(.init(.zeroByteResource)))
                    return
                }
                guard let response else {
                    promise(.failure(.init(.cannotParseResponse)))
                    return
                }
                promise(.success((fileUrl, response)))
            }
            downloadTask = task
            task.resume()
        }
        guard let downloadTask else { return .failedDownloadTask(code: .unknown) }
        let wrapper = WeakDownloadWrapper(downloadTask: downloadTask, future: future)
        self.ongoingDownload[request] = wrapper
        return wrapper.downloadTaskPairs ?? .failedDownloadTask(code: .unknown)
    }
    
    private func downloadTask(for request: DownloadRequest, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        switch request {
        case .resumeData(let data):
            return downloadTask(withResumeData: data, completionHandler: completionHandler)
        case .urlRequest(let urlRequest):
            return downloadTask(with: urlRequest, completionHandler: completionHandler)
        }
    }
}


private class WeakDownloadWrapper: NSObject {
    private var downloadTask: URLSessionDownloadTask?
    private var future: Future<(file: URL, response: URLResponse), URLError>?
    private var observation: NSKeyValueObservation?
    private var publisher: AnyPublisher<DownloadResponseOutput, URLError>?
    
    var downloadTaskPairs: DownloadTaskPairs? {
        guard let publisher = publisher, let task = downloadTask else { return nil }
        return .init(publisher: publisher, task: task)
    }
    
    init(downloadTask: URLSessionDownloadTask, future: Future<(file: URL, response: URLResponse), URLError>) {
        self.downloadTask = downloadTask
        self.future = future
        let progressPublisher: CurrentValueSubject<Double, Never> = CurrentValueSubject(0)
        self.observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
            progressPublisher.send(progress.fractionCompleted)
        }
        self.publisher = Publishers.CombineLatest(
            future.prependWithOptional(),
            progressPublisher.setFailureType(to: URLError.self)
        )
        .map { result, progress in
            guard let result else {
                return .downloading(progress: progress)
            }
            return .downloaded(file: result.file, response: result.response)
        }
        .eraseToAnyPublisher()
        super.init()
        self.autoRelease(for: future)
    }
    
    private func autoRelease(for future: Future<(file: URL, response: URLResponse), URLError>) {
        var cancellable: AnyCancellable?
        cancellable = future.sink { [weak self] _ in
            self?.publisher = nil
            self?.downloadTask = nil
            self?.future = nil
            self?.observation = nil
            cancellable?.cancel()
            cancellable = nil
        } receiveValue: { _ in }
    }
}

private extension Future {
    func prependWithOptional() -> AnyPublisher<Output?, Failure> {
        map { $0 }.prepend(nil).eraseToAnyPublisher()
    }
}
