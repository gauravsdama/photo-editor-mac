import Foundation

struct ActionAPIRequest: @unchecked Sendable {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: [String: Any]
}

struct ActionAPIResponse: @unchecked Sendable {
    let statusCode: Int
    let body: Any?

    static func json(statusCode: Int = 200, _ body: Any) -> ActionAPIResponse {
        ActionAPIResponse(statusCode: statusCode, body: body)
    }

    static func empty(statusCode: Int = 204) -> ActionAPIResponse {
        ActionAPIResponse(statusCode: statusCode, body: nil)
    }

    static func error(statusCode: Int, message: String, suggestion: String? = nil) -> ActionAPIResponse {
        var payload: [String: Any] = [
            "ok": false,
            "error": message
        ]
        if let suggestion {
            payload["suggestion"] = suggestion
        }
        return ActionAPIResponse(statusCode: statusCode, body: payload)
    }

    func httpData() -> Data {
        let reason = HTTPStatus.reasonPhrase(for: statusCode)
        let bodyData: Data

        if let body {
            bodyData = (try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        } else {
            bodyData = Data()
        }

        let headers = [
            "HTTP/1.1 \(statusCode) \(reason)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: http://127.0.0.1",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var data = Data(headers.utf8)
        data.append(bodyData)
        return data
    }
}

enum HTTPStatus {
    static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: "OK"
        case 204: "No Content"
        case 400: "Bad Request"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "OK"
        }
    }
}

enum ActionAPIParser {
    static func parse(data: Data) throws -> ActionAPIRequest {
        guard let raw = String(data: data, encoding: .utf8) else {
            throw ActionAPIParserError.invalidEncoding
        }

        let parts = raw.components(separatedBy: "\r\n\r\n")
        guard let headerBlock = parts.first else {
            throw ActionAPIParserError.invalidRequest
        }

        let headerLines = headerBlock.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else {
            throw ActionAPIParserError.invalidRequest
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count >= 2 else {
            throw ActionAPIParserError.invalidRequest
        }

        let method = requestParts[0].uppercased()
        let target = requestParts[1]
        let components = URLComponents(string: target)
        let path = components?.path.isEmpty == false ? components?.path ?? target : target
        let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                headers[parts[0].lowercased()] = parts[1]
            }
        }

        let bodyString = parts.dropFirst().joined(separator: "\r\n\r\n")
        let bodyData = Data(bodyString.utf8)
        let body: [String: Any]
        if bodyData.isEmpty {
            body = [:]
        } else {
            body = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any] ?? [:]
        }

        return ActionAPIRequest(method: method, path: path, query: query, headers: headers, body: body)
    }
}

enum ActionAPIParserError: Error {
    case invalidEncoding
    case invalidRequest
}
