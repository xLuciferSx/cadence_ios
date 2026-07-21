import Foundation
import KeyboardFoundation

struct BackendClient: Sendable {
  var baseURL: URL
  var token: String
  var session: URLSession = .shared

  enum Failure: LocalizedError, Equatable {
    case notConfigured
    case http(Int, String)
    case decoding

    var errorDescription: String? {
      switch self {
      case .notConfigured: return "Set your backend URL and access token in the Voice Keyboard app."
      case let .http(code, message): return message.isEmpty ? "Backend error (\(code))" : message
      case .decoding: return "Unexpected response from the backend."
      }
    }
  }

  private struct TextResponse: Decodable { let text: String }

  func transcribe(audio: Data, filename: String = "audio.m4a", language: String? = nil) async throws -> String {
    let boundary = "Boundary-\(UUID().uuidString)"
    var request = makeRequest(path: "v1/transcribe")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    if let language {
      body.append("--\(boundary)\r\n")
      body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
      body.append("\(language)\r\n")
    }
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
    body.append("Content-Type: audio/m4a\r\n\r\n")
    body.append(audio)
    body.append("\r\n")
    body.append("--\(boundary)--\r\n")
    request.httpBody = body

    return try await send(request)
  }

  func cleanUp(_ text: String) async throws -> String {
    guard !text.isEmpty else { return text }
    return try await postJSON(path: "v1/cleanup", payload: ["text": text])
  }

  func tone(_ text: String, _ tone: String) async throws -> String {
    guard !text.isEmpty else { return text }
    return try await postJSON(path: "v1/tone", payload: ["text": text, "tone": tone])
  }

  // MARK: - Helpers

  private func makeRequest(path: String) -> URLRequest {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
  }

  private func postJSON(path: String, payload: [String: String]) async throws -> String {
    var request = makeRequest(path: path)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    return try await send(request)
  }

  private func send(_ request: URLRequest) async throws -> String {
    let (data, response) = try await session.data(for: request)
    if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
      let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String } ?? ""
      throw Failure.http(http.statusCode, message)
    }
    guard let decoded = try? JSONDecoder().decode(TextResponse.self, from: data) else {
      throw Failure.decoding
    }
    return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private extension Data {
  mutating func append(_ string: String) {
    append(Data(string.utf8))
  }
}
