import Foundation
import Network

final class LocalActionAPIServer: @unchecked Sendable {
    private final class PendingRequest: @unchecked Sendable {
        var data = Data()
    }

    private static let receiveChunkBytes = 64 * 1_024
    private static let requestReadTimeout: DispatchTimeInterval = .seconds(5)

    private let port: UInt16
    private let bearerToken: String?
    private let handler: @Sendable (ActionAPIRequest) async -> ActionAPIResponse
    private let readinessHandler: @Sendable (Bool) -> Void
    private let queue = DispatchQueue(label: "phase-one-photo-editor.action-api")
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var responseTasks: [UUID: Task<Void, Never>] = [:]
    private var readTimeouts: [UUID: DispatchWorkItem] = [:]
    private var respondingConnections: Set<UUID> = []

    init(
        port: UInt16,
        bearerToken: String? = nil,
        readinessHandler: @escaping @Sendable (Bool) -> Void = { _ in },
        handler: @escaping @Sendable (ActionAPIRequest) async -> ActionAPIResponse
    ) {
        self.port = port
        self.bearerToken = bearerToken
        self.readinessHandler = readinessHandler
        self.handler = handler
    }

    func start() {
        queue.sync {
            guard listener == nil else {
                return
            }

            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true
                guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                    fputs("PhotoEditorMac action API has invalid port: \(port)\n", stderr)
                    return
                }
                parameters.requiredLocalEndpoint = .hostPort(
                    host: NWEndpoint.Host("127.0.0.1"),
                    port: endpointPort
                )
                let listener = try NWListener(using: parameters)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                listener.stateUpdateHandler = { [weak self] state in
                    self?.handleListenerState(state)
                }
                self.listener = listener
                listener.start(queue: queue)
            } catch {
                fputs("PhotoEditorMac action API failed to start: \(error)\n", stderr)
            }
        }
    }

    func stop() {
        queue.sync {
            stopLocked()
        }
    }

    private func accept(_ connection: NWConnection) {
        dispatchPrecondition(condition: .onQueue(queue))
        let id = UUID()
        connections[id] = connection
        let timeout = DispatchWorkItem { [weak self] in
            self?.send(
                .error(statusCode: 408, message: "Action API request timed out."),
                to: id
            )
        }
        readTimeouts[id] = timeout
        queue.asyncAfter(deadline: .now() + Self.requestReadTimeout, execute: timeout)

        connection.start(queue: queue)
        receiveNext(id: id, pending: PendingRequest())
    }

    private func receiveNext(id: UUID, pending: PendingRequest) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let connection = connections[id] else {
            return
        }
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: Self.receiveChunkBytes
        ) { [weak self] data, _, isComplete, error in
            guard let self,
                  self.connections[id] != nil,
                  !self.respondingConnections.contains(id) else {
                return
            }
            if error != nil {
                self.closeConnection(id)
                return
            }
            if let data, !data.isEmpty {
                pending.data.append(data)
            }

            do {
                guard let expectedLength = try ActionAPIParser.expectedRequestLength(in: pending.data) else {
                    if isComplete {
                        throw ActionAPIParserError.incompleteRequest
                    }
                    self.receiveNext(id: id, pending: pending)
                    return
                }
                guard pending.data.count == expectedLength else {
                    if pending.data.count > expectedLength || isComplete {
                        throw ActionAPIParserError.invalidRequest
                    }
                    self.receiveNext(id: id, pending: pending)
                    return
                }
                self.readTimeouts.removeValue(forKey: id)?.cancel()
                let request = try ActionAPIParser.parse(data: pending.data)
                self.handle(request, on: id)
            } catch let parserError as ActionAPIParserError {
                self.sendParseError(parserError, to: id)
            } catch {
                self.sendParseError(.invalidRequest, to: id)
            }
        }
    }

    private func handle(_ request: ActionAPIRequest, on id: UUID) {
        dispatchPrecondition(condition: .onQueue(queue))
        if request.method != "OPTIONS",
           request.path != "/health",
           let bearerToken,
           request.headers["authorization"] != "Bearer \(bearerToken)" {
            send(
                .error(
                    statusCode: 401,
                    message: "Action API authorization is required.",
                    suggestion: "Send the per-launch bearer token in the Authorization header."
                ),
                to: id
            )
            return
        }
        let responseTask = Task { [weak self] in
            guard let self else {
                return
            }
            let response: ActionAPIResponse
            if request.method == "OPTIONS" {
                response = .empty()
            } else {
                response = await self.handler(request)
            }
            self.queue.async { [weak self] in
                self?.responseTasks[id] = nil
                self?.send(response, to: id)
            }
        }
        responseTasks[id] = responseTask
    }

    private func sendParseError(_ error: ActionAPIParserError, to id: UUID) {
        dispatchPrecondition(condition: .onQueue(queue))
        readTimeouts.removeValue(forKey: id)?.cancel()
        send(
            .error(
                statusCode: error.statusCode,
                message: "Could not parse action API request.",
                suggestion: "Send one complete HTTP/1.1 request with a JSON object body and Content-Type: application/json."
            ),
            to: id
        )
    }

    private func send(_ response: ActionAPIResponse, to id: UUID) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let connection = connections[id], respondingConnections.insert(id).inserted else {
            return
        }
        readTimeouts.removeValue(forKey: id)?.cancel()
        connection.send(content: response.httpData(), completion: .contentProcessed { [weak self] _ in
            self?.closeConnection(id)
        })
    }

    private func handleListenerState(_ state: NWListener.State) {
        dispatchPrecondition(condition: .onQueue(queue))
        switch state {
        case .ready:
            readinessHandler(true)
        case let .failed(error):
            fputs("PhotoEditorMac action API listener failed: \(error)\n", stderr)
            readinessHandler(false)
            stopLocked()
        case .cancelled:
            readinessHandler(false)
        default:
            break
        }
    }

    private func closeConnection(_ id: UUID) {
        dispatchPrecondition(condition: .onQueue(queue))
        readTimeouts.removeValue(forKey: id)?.cancel()
        responseTasks.removeValue(forKey: id)?.cancel()
        respondingConnections.remove(id)
        connections.removeValue(forKey: id)?.cancel()
    }

    private func stopLocked() {
        dispatchPrecondition(condition: .onQueue(queue))
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        for id in Array(connections.keys) {
            closeConnection(id)
        }
    }
}
