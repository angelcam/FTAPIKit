//
//  APIAdapterTests.swift
//  FTAPIKit
//
//  Created by Matěj Kašpar Jirásek on 03/09/2018.
//  Copyright © 2018 The Funtasty. All rights reserved.
//

// swiftlint:disable nesting

import XCTest
import FTAPIKit

final class APIAdapterTests: XCTestCase {

    private func apiAdapter() -> URLSessionAPIAdapter {
        return URLSessionAPIAdapter(baseUrl: URL(string: "http://httpbin.org/")!)
    }

    private let timeout: TimeInterval = 30.0

    func testGet() {
        struct Endpoint: APIEndpoint {
            let path = "get"
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            if case let .error(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testClientError() {
        struct Endpoint: APIEndpoint {
            let path = "status/404"
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            switch result {
            case .value:
                XCTFail("404 endpoint must return error")
            case .error(StandardAPIError.client):
                XCTAssert(true)
            case .error:
                XCTFail("404 endpoint must return client error")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testServerError() {
        struct Endpoint: APIEndpoint {
            let path = "status/500"
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            switch result {
            case .value:
                XCTFail("500 endpoint must return error")
            case .error(StandardAPIError.server):
                XCTAssert(true)
            case .error:
                XCTFail("500 endpoint must return server error")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testConnectionError() {
        struct Endpoint: APIEndpoint {
            let path = "some-failing-path"
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = URLSessionAPIAdapter(baseUrl: URL(string: "https://www.tato-stranka-urcite-neexistuje.cz/")!)
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            switch result {
            case .value:
                XCTFail("Non-existing domain must fail")
            case .error(StandardAPIError.connection):
                XCTAssert(true)
            case .error:
                XCTFail("Non-existing domain must throw connection error")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testEmptyResult() {
        struct Endpoint: APIEndpoint {
            let path = "status/204"
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            if case let .error(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testCustomError() {
        struct Endpoint: APIEndpoint {
            let path = "get"
        }

        struct CustomError: APIError {
            private init() {}

            init?(data: Data?, response: URLResponse?, error: Error?, decoder: JSONDecoder) {
                self = CustomError()
            }
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = URLSessionAPIAdapter(baseUrl: URL(string: "http://httpbin.org/")!, errorType: CustomError.self)
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            if case let .error(error) = result {
                XCTAssertTrue(error is CustomError)
            } else {
                XCTFail("Custom error must be returned")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testURLEncodedPost() {
        struct Endpoint: APIEndpoint {
            let data: RequestType = .urlEncoded
            let parameters: HTTPParameters = [
                "someParameter": "someValue",
                "anotherParameter": "anotherValue"
            ]
            let path = "post"
            let method: HTTPMethod = .post
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            if case let .error(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testValidJSONResponse() {
        struct TopLevel: Codable {
            let slideshow: Slideshow
        }

        struct Slideshow: Codable {
            let author, date: String
            let slides: [Slide]
            let title: String
        }

        struct Slide: Codable {
            let title, type: String
            let items: [String]?
        }

        struct Endpoint: APIResponseEndpoint {
            typealias Response = TopLevel

            let path = "json"
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(response: Endpoint()) { result in
            if case let .error(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testTaskCancellation() {
        struct TopLevel: Codable {
            let slideshow: Slideshow
        }

        struct Slideshow: Codable {
            let author, date: String
            let slides: [Slide]
            let title: String
        }

        struct Slide: Codable {
            let title, type: String
            let items: [String]?
        }

        struct Endpoint: APIResponseEndpoint {
            typealias Response = TopLevel

            let path = "json"
        }

        let delegate = MockupAPIAdapterDelegate()
        let adapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.dataTask(response: Endpoint(), creation: { $0.cancel() }, completion: { result in
            if case .error(StandardAPIError.cancelled) = result {
                XCTAssert(true)
            } else {
                XCTFail("Task not cancelled")
            }
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: timeout)
    }

    func testValidJSONRequestResponse() {
        struct User: Codable, Equatable {
            let uuid: UUID
            let name: String
            let age: UInt
        }

        struct TopLevel: Decodable {
            let json: User
        }

        struct Endpoint: APIRequestResponseEndpoint {

            typealias Response = TopLevel

            let body: User
            let path = "anything"
        }

        let user = User(uuid: UUID(), name: "Some Name", age: .random(in: 0...120))
        let endpoint = Endpoint(body: user)
        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(response: endpoint) { result in
            switch result {
            case .value(let response):
                XCTAssertEqual(user, response.json)
            case .error(let error):
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testInvalidJSONRequestResponse() {
        struct User: Codable, Equatable {
            let uuid: UUID
            let name: String
            let age: UInt
        }

        struct Endpoint: APIRequestResponseEndpoint {
            typealias Response = User

            let body: User
            let path = "anything"
        }

        let user = User(uuid: UUID(), name: "Some Name", age: .random(in: 0...120))
        let endpoint = Endpoint(body: user)
        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(response: endpoint) { result in
            if case .value = result {
                XCTFail("Received valid value, decoding must fail")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testAuthorization() {
        struct Endpoint: APIEndpoint {
            let path = "bearer"
            let authorized = true
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate

        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            if case let .error(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testMultipartData() {
        struct MockupUrl {
            let url: URL = Bundle(for: APIAdapterTests.self).url(forResource: "MockupBodyPart", withExtension: "jpg")!
            let headers: [String: String] = [
                "Content-Disposition": "form-data; name=jpegFile",
                "Content-Type": "image/jpeg"
            ]
        }
        struct Endpoint: APIEndpoint {
            let type: RequestType = .multipart([
                MultipartBodyPart(name: "anotherParameter", value: "valueForParameter"),
                try! MultipartBodyPart(name: "urlImage", url: MockupUrl().url),
                MultipartBodyPart(headers: MockupUrl().headers, data: try! Data(contentsOf: MockupUrl().url)),
                MultipartBodyPart(headers: MockupUrl().headers, inputStream: InputStream(url: MockupUrl().url)!)
            ])
            let parameters: HTTPParameters = [
                "someParameter": "someValue"
            ]
            let path = "post"
            let method: HTTPMethod = .post
        }

        let delegate = MockupAPIAdapterDelegate()
        var adapter: APIAdapter = apiAdapter()
        adapter.delegate = delegate
        let expectation = self.expectation(description: "Result")
        adapter.request(data: Endpoint()) { result in
            if case let .error(error) = result {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    static var allTests = [
        ("testGet", testGet),
        ("testClientError", testClientError),
        ("testServerError", testServerError),
        ("testConnectionError", testConnectionError),
        ("testEmptyResult", testEmptyResult),
        ("testCustomError", testCustomError),
        ("testURLEncodedPost", testURLEncodedPost),
        ("testValidJSONResponse", testValidJSONResponse),
        ("testValidJSONRequestResponse", testValidJSONRequestResponse),
        ("testInvalidJSONRequestResponse", testInvalidJSONRequestResponse),
        ("testAuthorization", testAuthorization),
        ("testMultipartData", testMultipartData)
    ]
}
