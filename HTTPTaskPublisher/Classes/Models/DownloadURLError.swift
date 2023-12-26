//
//  DownloadURLError.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 25/12/23.
//

import Foundation
import Combine

public enum DownloadURLError: Error {
    case failWhileAdapt(request: URLRequest, originalError: Error)
    case urlError(URLError)
}
