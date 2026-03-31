import Foundation

struct HTTPResponse: Sendable {
  let data: Data
  let response: HTTPURLResponse
}

protocol HTTPClient: Sendable {
  func send(_ request: URLRequest) async throws -> HTTPResponse
}

struct URLSessionHTTPClient: HTTPClient {
  func send(_ request: URLRequest) async throws -> HTTPResponse {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }
    return HTTPResponse(data: data, response: httpResponse)
  }
}
