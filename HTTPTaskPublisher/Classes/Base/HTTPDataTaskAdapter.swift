//
//  HTTPDataTaskAdapter.swift
//  CombineAsync
//
//  Created by Nayanda Haberty on 15/6/23.
//

import Foundation

public protocol HTTPDataTaskAdapter {
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest
}
