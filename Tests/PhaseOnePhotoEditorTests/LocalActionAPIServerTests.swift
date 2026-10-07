import Foundation
import Testing
@testable import PhaseOnePhotoEditor

@Suite("Local action API server")
struct LocalActionAPIServerTests {
    @Test("Serves one request and stops cleanly")
    func servesRequest() async throws {
        let port = UInt16.random(in: 49_152...59_999)
        let server = LocalActionAPIServer(port: port) { request in
            .json(["ok": true, "path": .string(request.path)])
        }
        server.start()
        defer { server.stop() }

        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        var lastError: Error?
        for _ in 0..<10 {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 1
                let (data, response) = try await URLSession.shared.data(for: request)
                let httpResponse = try #require(response as? HTTPURLResponse)
                let payload = try #require(
                    JSONSerialization.jsonObject(with: data) as? [String: Any]
                )
                #expect(httpResponse.statusCode == 200)
                #expect(payload["ok"] as? Bool == true)
                #expect(payload["path"] as? String == "/health")
                return
            } catch {
                lastError = error
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        if let lastError {
            throw lastError
        }
        Issue.record("Action API server did not become ready")
    }

    @Test("Bearer token protects actions while health remains public")
    func bearerAuthentication() async throws {
        let port = UInt16.random(in: 40_000...49_151)
        let token = "test-token"
        let server = LocalActionAPIServer(port: port, bearerToken: token) { request in
            .json(["ok": true, "path": .string(request.path)])
        }
        server.start()
        defer { server.stop() }

        let health = try await send(path: "/health", port: port)
        #expect(health.statusCode == 200)

        let unauthorized = try await send(path: "/api/state", port: port)
        #expect(unauthorized.statusCode == 401)

        let authorized = try await send(
            path: "/api/state",
            port: port,
            authorization: "Bearer \(token)"
        )
        #expect(authorized.statusCode == 200)

        let preflight = try await send(path: "/api/state", port: port, method: "OPTIONS")
        #expect(preflight.statusCode == 204)
    }

    @Test("Handles concurrent requests and cancels an active request on shutdown")
    func concurrentRequestsAndActiveShutdown() async throws {
        let port = UInt16.random(in: 30_000...39_999)
        let server = LocalActionAPIServer(port: port) { request in
            if request.path == "/slow" {
                try? await Task.sleep(for: .seconds(5))
            }
            return .json(["ok": true, "path": .string(request.path)])
        }
        server.start()
        defer { server.stop() }

        _ = try await send(path: "/health", port: port)
        try await withThrowingTaskGroup(of: Int.self) { group in
            for index in 0..<8 {
                group.addTask {
                    let response = try await send(path: "/request-\(index)", port: port)
                    return response.statusCode
                }
            }
            for try await statusCode in group {
                #expect(statusCode == 200)
            }
        }

        let slowURL = URL(string: "http://127.0.0.1:\(port)/slow")!
        let activeRequest = Task {
            var request = URLRequest(url: slowURL)
            request.timeoutInterval = 10
            return try await URLSession.shared.data(for: request)
        }
        try await Task.sleep(for: .milliseconds(100))
        server.stop()

        var requestWasCancelled = false
        do {
            _ = try await activeRequest.value
        } catch {
            requestWasCancelled = true
        }
        #expect(requestWasCancelled)
    }

    private func send(
        path: String,
        port: UInt16,
        method: String = "GET",
        authorization: String? = nil
    ) async throws -> HTTPURLResponse {
        let url = URL(string: "http://127.0.0.1:\(port)\(path)")!
        var lastError: Error?
        for _ in 0..<10 {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = method
                request.timeoutInterval = 1
                if let authorization {
                    request.setValue(authorization, forHTTPHeaderField: "Authorization")
                }
                let (_, response) = try await URLSession.shared.data(for: request)
                return try #require(response as? HTTPURLResponse)
            } catch {
                lastError = error
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        throw try #require(lastError)
    }
}
