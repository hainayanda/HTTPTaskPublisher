# HTTPTaskPublisher

HTTPTaskPublisher does not aim to recreate the `DataTaskPublisher`, but as an extension of it. In fact, HTTPTaskPublisher is using `DataTaskPublisher` behind it. What it did do is, it will do the hard work to ensure your HTTP request works smoothly.

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/b10d43146b114ad4a98882ba9e8f96be)](https://app.codacy.com/gh/hainayanda/HTTPTaskPublisher/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
![build](https://github.com/hainayanda/HTTPTaskPublisher/workflows/build/badge.svg)
![test](https://github.com/hainayanda/HTTPTaskPublisher/workflows/test/badge.svg)
[![Version](https://img.shields.io/cocoapods/v/HTTPTaskPublisher.svg?style=flat)](https://cocoapods.org/pods/HTTPTaskPublisher)
[![License](https://img.shields.io/cocoapods/l/HTTPTaskPublisher.svg?style=flat)](https://cocoapods.org/pods/HTTPTaskPublisher)
[![Platform](https://img.shields.io/cocoapods/p/HTTPTaskPublisher.svg?style=flat)](https://cocoapods.org/pods/HTTPTaskPublisher)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

- Swift 5.5 or higher
- iOS 13.0 or higher
- MacOS 10.15 or higher
- TVOS 13.0 or higher
- watchOS 8.0 or higher
- XCode 13 or higher

### Cocoapods

HTTPTaskPublisher is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'HTTPTaskPublisher', '~> 1.0'
```

### Swift Package Manager from XCode

- Add it using XCode menu **File > Swift Package > Add Package Dependency**
- Add **<https://github.com/hainayanda/HTTPTaskPublisher.git>** as Swift Package URL
- Set rules at **version**, with **Up to Next Major** option and put **1.0.0** as its version
- Click next and wait

### Swift Package Manager from Package.swift

Add as your target dependency in **Package.swift**

```swift
dependencies: [
    .package(url: "https://github.com/hainayanda/HTTPTaskPublisher.git", .upToNextMajor(from: "1.0.0"))
]
```

Use it in your target as a `HTTPTaskPublisher`

```swift
 .target(
    name: "MyModule",
    dependencies: ["HTTPTaskPublisher"]
)
```

## Author

hainayanda, hainayanda@outlook.com

## License

HTTPTaskPublisher is available under the MIT license. See the LICENSE file for more info.

## Basic Usage

To do an HTTP request, it will be similar to how to do with `DataTaskPublisher`:

```swift
var myRequest: URLRequest(url: url)

...
...

let cancellable = URLSession.shared.httpTaskPublisher(for: myRequest)
    .sink { completion in
        // do something after complete
    } receiveValue: { response in
        // do something with response
    }
```

The response is a tuple like this:

```swift
(data: Data, response: HTTPURLResponse)
```

and it will emit an error type of `HTTPURLError`:

```swift
public indirect enum HTTPURLError: Error {
    case failWhileRetry(error: Error, request: URLRequest, orignalError: HTTPURLError)
    case failToRetry(reason: String, request: URLRequest, orignalError: HTTPURLError)
    case failWhileAdapt(request: URLRequest, originalError: Error)
    case failDecode(data: Data, response: HTTPURLResponse, decodeError: Error)
    case failValidation(reason: String, data: Data, response: HTTPURLResponse)
    case expectHTTPResponse(data: Data, response: URLResponse)
    case urlError(URLError)
    case error(Error)
}
```

You can decode the Data to the type you want like this:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .decode(type: MyObject.self, decoder: JSONDecoder())
    .sink { ... }
```

then it will generate a tuple like this:

```swift
(decoded: MyObject, response: HTTPURLResponse)
```

### Validation

You can add a validation to the request to make it throw an error whenever the response is failing the validation:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .validate { data, httpUrlResponse in
        // validating
        return .invalid(reason: "no reason")
    }
    .sink { ... }
```

The closure will be called after the request is successful and produces `Data` and `HTTPURLResponse`. You can validate the result and return `HTTPDataTaskValidation` as the validation result. It will then be used to determine that the request should be passed to the subscriber or throw `HTTPURLError.failValidation(reason:data:response:)`.
`HTTPDataTaskValidation` is an enumeration that is declared like this:

```swift
public enum HTTPDataTaskValidation: Equatable {
    case valid
    case invalid(reason: String)
}
```

If you just want to validate the statusCode, you can do it like this:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .allowed(statusCode: 200)
    .sink { ... }

// or like this
URLSession.shared.httpTaskPublisher(for: myRequest)
    .allowed(statusCodes: 200..<300)
    .sink { ... }

// or like this
URLSession.shared.httpTaskPublisher(for: myRequest)
    .allowed(statusCodes: 200, 201)
    .sink { ... }

// or using array like this
URLSession.shared.httpTaskPublisher(for: myRequest)
    .allowed(statusCodes: [200, 201])
    .sink { ... }
```

In case you need more complex validation, just implement `HTTPDataTaskValidator`:

```swift
struct MyValidator: HTTPDataTaskValidator { 
    func httpDataTaskIsValid(for data: Data, response: HTTPURLResponse) -> HTTPDataTaskValidation {
        // validating
        return .invalid(reason: "no reason")
    }
}
```

and pass it:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .validate(using: MyValidator())
    .sink { ... }
```

### Retry

To control when to do a retry can be done like this:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .retryDecision { error, request in
        // deciding
        return .drop
     }
    .sink { ... }
```

The closure will be called when the request is failing and producing `HTTPURLError`. You can decide based on this and return `HTTPDataTaskRetryDecision` as the retry decision result. It will then be used to determine whether the request should be retried or not.
`HTTPDataTaskRetryDecision` is an enumeration that is declared like this:

```swift
public enum HTTPDataTaskRetryDecision: Equatable {
    case retryWithNewRequest(URLRequest)
    case retry
    case dropWithReason(reason: String)
    case drop
}
```

If you want to do a more complex retry then you can implement `HTTPDataTaskRetrier`:

```swift
struct MyRetrier: HTTPDataTaskRetrier {
    
    func httpDataTaskShouldRetry(for error: HTTPURLError, request: URLRequest) async throws -> HTTPDataTaskRetryDecision {
        guard let code = error.statusCode, code == 401 else { 
            return .drop
        }
        let token = try await refreshToken()

        // create new request with token
        ...
        ...
        
        return .retryWithNewRequest(newRequest)
    }
}
```

and pass it:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .retrier(using: MyRetrier())
    .sink { ... }
```

### Adapt

You can adapt your request before sending it like this:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .adapt { request in
        // modify the request
        return request
    }
    .sink { ... }
```

The closure will be called right before it is sent. It will then use the new request provided by the adaptation or throw an `HTTPURLErrorfailWhileAdapt(request:originalError:)` even before the request has been made.
If you want to do a more complex adaptation then you can implement `HTTPDataTaskAdapter`:

```swift
struct MyAdapter: HTTPDataTaskAdapter {
    
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest {
        let myToken = getTokenFromCache() ?? try await refreshToken()

        // create new request with token
        ...
        ...
            
        return newRequest
    }
}
```

and pass it:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .adapt(using: MyAdapter())
    .sink { ... }
```

### Interceptor

Sometimes you will need both a retrier and adapter like when you are using a refresh token mechanism. We can create one instance that implements `HTTPDataTaskInterceptor` that is actually just a typealias of `HTTPDataTaskAdapter` and `HTTPDataTaskRetrier`:

```swift
struct MyInterceptor: HTTPDataTaskInterceptor {
    
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest {
        try await applyToken(to: request)
    }

    func httpDataTaskShouldRetry(for error: HTTPURLError, request: URLRequest) async throws -> HTTPDataTaskRetryDecision {
        guard let code = error.statusCode, code == 401 else { 
            return .drop
        }
        let tokenizedRequest = try await applyToken(to: request)
        return .retryWithNewRequest(tokenizedRequest)
    }

    private func applyToken(to request: URLRequest) async throws -> URLRequest { 
        ...
        ...
    }
}
```

and pass it:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .intercept(using: MyInterceptor())
    .sink { ... }
```

### Combine

Since HTTPTaskPublisher is created using the Combine framework, you can do anything that is allowed by Combine like this:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest)
    .intercept(using: MyInterceptor())
    .decode(type: Result.self, decoder: JSONDecoder())
    .retry(2)
    .map { $0.decoded.payloads }
    .sink { ... }
```

## Contribute

You know how, just clone and do a pull request
