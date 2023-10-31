# Swift HTTP Task Publisher

Swift HTTP Task Publisher is a powerful extension of the DataTaskPublisher, designed to simplify and enhance HTTP request handling in your Swift projects.

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/b10d43146b114ad4a98882ba9e8f96be)](https://app.codacy.com/gh/hainayanda/HTTPTaskPublisher/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
![build](https://github.com/hainayanda/HTTPTaskPublisher/workflows/build/badge.svg)
![test](https://github.com/hainayanda/HTTPTaskPublisher/workflows/test/badge.svg)
[![Version](https://img.shields.io/cocoapods/v/HTTPTaskPublisher.svg?style=flat)](https://cocoapods.org/pods/HTTPTaskPublisher)
[![License](https://img.shields.io/cocoapods/l/HTTPTaskPublisher.svg?style=flat)](https://cocoapods.org/pods/HTTPTaskPublisher)
[![Platform](https://img.shields.io/cocoapods/p/HTTPTaskPublisher.svg?style=flat)](https://cocoapods.org/pods/HTTPTaskPublisher)

## Example Project

To run the example project, follow these steps:

1. Clone the repository.
2. Navigate to the "Example" directory.
3. Run `pod install`.
4. Open the Xcode workspace and run the example app.

## Requirements

- Swift 5.5 or higher
- iOS 13.0 or higher
- MacOS 10.15 or higher
- TVOS 13.0 or higher
- watchOS 8.0 or higher
- Xcode 13 or higher

## Installation

### Installation with CocoaPods

To install Swift HTTP Task Publisher via CocoaPods, add the following line to your Podfile:

```ruby
pod 'HTTPTaskPublisher', '~> 2.0'
```

### Installation with Swift Package Manager (Xcode)

- Go to Xcode menu **File > Swift Package > Add Package Dependency**
- Add **<https://github.com/hainayanda/HTTPTaskPublisher.git>** as Swift Package URL
- Set rules to **version**, with the **Up to Next Major** option option and use **2.0.0** as the version.
- Click "Next" and wait for the package to be fetched.

### Swift Package Manager from Package.swift

To use `Swift HTTP Task Publisher` as a dependency in your Swift Package Manager project, add it to your `Package.swift` file's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/hainayanda/HTTPTaskPublisher.git", .upToNextMajor(from: "2.0.0"))
]
```

Then, in your target's dependencies, add `HTTPTaskPublisher`:

```swift
 .target(
    name: "YourTargetName",
    dependencies: [
        .product(name: "HTTPTaskPublisher", package: "HTTPTaskPublisher"),
    ]
)
```

## Author

HTTPTaskPublisher is developed by Nayanda Haberty. You can contact the author at hainayanda@outlook.com

## License

HTTPTaskPublisher is released under the MIT license. For more details, please refer to the LICENSE file.

## Basic Usage

To do an HTTP request, it will be similar to how to do with `DataTaskPublisher`:

```swift
var myRequest: URLRequest(url: url)

// ...

let cancellable = URLSession.shared.httpTaskPublisher(for: myRequest)
    .sink { completion in
        // do something after complete
    } receiveValue: { response in
        // do something with the response
    }
```

The response is a tuple like this:

```swift
(data: Data, response: HTTPURLResponse)
```

and it will emit an error type of `HTTPURLError`:

```swift
public indirect enum HTTPURLError: Error {
    case failWhileRetry(error: Error, orignalError: HTTPURLError)
    case failToRetry(reason: String, orignalError: HTTPURLError)
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

### Duplication Handling

Swift HTTP Task Publisher will store any ongoing request in the `URLSession` until it's done. You can control how you want to do the request when an identical request is still ongoing by passing `DuplicationHandling` enum when creating a new `HTTPDataTaskPublisher`:

```swift
URLSession.shared.httpTaskPublisher(for: myRequest, whenDuplicated: .useCurrentIfPossible)
    .sink { ... }
```

The `DuplicationHandling` is an enumeration that is declared like this:

```swift
public enum DuplicationHandling {
    case alwaysCreateNew
    case useCurrentIfPossible
    case dropIfDuplicated
}
```

The default one is `alwaysCreateNew`.

### Validation

You can add validation to the request to make it throw an error whenever the response is failing the validation:

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

        // create a new request with token
        // ...
        // ...

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
URLSession.shared.httpTaskPublisher(for: myRequest, adapter: myAdapter)
    .sink { ... }
```

with `HTTPDataTaskAdapter` that implemented like this:

```swift
struct MyAdapter: HTTPDataTaskAdapter {
    
    func httpDataTaskAdapt(for request: URLRequest) async throws -> URLRequest {
        let myToken = getTokenFromCache() ?? try await refreshToken()

        // create a new request with token
        // ...
        // ...
            
        return newRequest
    }
}
```

### Combine

Since HTTPTaskPublisher is created using the [Combine](https://developer.apple.com/documentation/combine) framework, you can do anything that is allowed by Combine like this:

```swift
import Combine

let payloads = try await URLSession.shared.httpTaskPublisher(for: myRequest)
    .retry(2)
    .map { $0.decoded.payloads }
    .sink { ... }
```
## Contribute

You know how, just clone and do a pull request
