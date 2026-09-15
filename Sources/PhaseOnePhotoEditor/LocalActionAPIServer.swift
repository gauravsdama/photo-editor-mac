import Foundation
import Network

final class LocalActionAPIServer: @unchecked Sendable {
    private let port: UInt16
    private let handler: @Sendable (ActionAPIRequest) async -> ActionAPIResponse
    private let queue = DispatchQueue(label: "phase-one-photo-editor.action-api")
    private var listener: NWListener?

    init(port: UInt16, handler: @escaping @Sendable (ActionAPIRequest) async -> ActionAPIResponse) {
        self.port = port
        self.handler = handler
    }

    func start() {
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
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            fputs("PhotoEditorMac action API failed to start: \(error)\n", stderr)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }

            guard error == nil, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let responseTask = Task {
                let response: ActionAPIResponse
                do {
                    let request = try ActionAPIParser.parse(data: data)
                    if request.method == "OPTIONS" {
                        response = .empty()
                    } else {
                        response = await self.handler(request)
                    }
                } catch {
                    response = .error(
                        statusCode: 400,
                        message: "Could not parse action API request.",
                        suggestion: "Send a valid HTTP request with JSON body and Content-Type: application/json."
                    )
                }

                connection.send(content: response.httpData(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }

            _ = responseTask
        }
    }
}
