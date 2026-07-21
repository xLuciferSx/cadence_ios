import Foundation
import XCTest

@testable import Transcription

final class BackendClientTests: XCTestCase {

  override func tearDown() {
    MockURLProtocol.handler = nil
    super.tearDown()
  }

  private func client() -> BackendClient {
    BackendClient(baseURL: URL(string: "https://api.example.com")!, token: "device-token", session: MockURLProtocol.session())
  }

  func testTranscribePostsMultipartWithBearer() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/transcribe")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer device-token")
      XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") ?? false)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"text":"hello there"}"#.utf8))
    }
    let text = try await client().transcribe(audio: Data([0x01, 0x02]))
    XCTAssertEqual(text, "hello there")
  }

  func testCleanUpPostsJSON() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/cleanup")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer device-token")
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"text":"Hello there."}"#.utf8))
    }
    let text = try await client().cleanUp("hello there")
    XCTAssertEqual(text, "Hello there.")
  }

  func testTonePostsJSON() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/tone")
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"text":"Kindly note."}"#.utf8))
    }
    let text = try await client().tone("note", "formal")
    XCTAssertEqual(text, "Kindly note.")
  }

  func testHTTPErrorSurfacesMessage() async {
    MockURLProtocol.handler = { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"error":{"message":"Unauthorized"}}"#.utf8))
    }
    do {
      _ = try await client().cleanUp("x")
      XCTFail("expected http error")
    } catch let error as BackendClient.Failure {
      XCTAssertEqual(error, .http(401, "Unauthorized"))
    } catch {
      XCTFail("unexpected error: \(error)")
    }
  }
}
