import Foundation

/// The one networking call the API clients need. `URLSession` conforms, and
/// tests pass a fake, so each test gets its own responses without shared state.
public protocol HTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
