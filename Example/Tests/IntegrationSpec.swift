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
            let url = URL(string: "https://api.publicapis.org/entries?category=Animals")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            var httpUrlError: HTTPURLError?
            var result: Result?
            var response: HTTPURLResponse?
            waitUntil(timeout: .seconds(30)) { done in
                cancellable = URLSession.shared.httpTaskPublisher(for: request)
                    .adapt { $0 }
                    .allowed(statusCode: 200)
                    .validate { _, _ in .valid }
                    .retryDecision { _, _ in .drop }
                    .decode(type: Result.self, decoder: JSONDecoder())
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
            expect(result.entries.count).to(equal(result.count))

        }
    }
}

// MARK: - Result

private struct Result: Codable {
    let count: Int
    let entries: [Entry]
}

// MARK: - Entry
private struct Entry: Codable {
    let api, auth, category, entryDescription, link: String
    let cors: Cors
    let https: Bool

    enum CodingKeys: String, CodingKey {
        case api = "API"
        case auth = "Auth"
        case category = "Category"
        case cors = "Cors"
        case entryDescription = "Description"
        case https = "HTTPS"
        case link = "Link"
    }
}

private enum Cors: String, Codable {
    case yes = "yes"
    case no = "no"
    case unknown = "unknown"
}


