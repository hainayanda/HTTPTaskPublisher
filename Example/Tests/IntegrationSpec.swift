//
//  IntegrationSpec.swift
//  HTTPTaskPublisher_Tests
//
//  Created by Nayanda Haberty on 15/6/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import Foundation
import Quick
import Nimble
import HTTPTaskPublisher
import Combine

class IntegrationSpec: QuickSpec {
    override class func spec() {
        var cancellable: AnyCancellable?
        afterEach {
            cancellable?.cancel()
            cancellable = nil
        }
        it("should get successfully") {
            let url = URL(string: "https://reqres.in/api/users?page=2")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            var httpUrlError: HTTPURLError?
            var result: MockResult?
            var response: HTTPURLResponse?
            waitUntil(timeout: .seconds(30)) { done in
                cancellable = URLSession.shared.httpTaskPublisher(for: request)
                    .allowed(statusCode: 200)
                    .validate { _, _ in .valid }
                    .retryDecision { _ in .drop }
                    .decode(type: MockResult.self, decoder: JSONDecoder())
                    .retry(3)
                    .sink { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            httpUrlError = error
                        }
                        done()
                    } receiveValue: { value in
                        result = value.decoded
                        response = value.response
                    }
            }
            expect(httpUrlError).to(beNil())
            guard let result, let response else {
                fail("by this time result and response should not be nil")
                return
            }
            expect(response.statusCode).to(equal(200))
            expect(result.data.count).to(equal(result.perPage))

        }
    }
}

// MARK: - MockResult
struct MockResult: Codable {
    let page, perPage, total, totalPages: Int
    let data: [User]
    let support: Support

    enum CodingKeys: String, CodingKey {
        case page, total, data, support
        case perPage = "per_page"
        case totalPages = "total_pages"
    }
}

// MARK: - Datum
struct User: Codable {
    let id: Int
    let email, firstName, lastName, avatar: String

    enum CodingKeys: String, CodingKey {
        case id, email, avatar
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

// MARK: - Support
struct Support: Codable {
    let url, text: String
}
