import Foundation

struct ActionAPIRequest: Sendable {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: JSONObject
}

struct ActionAPIResponse: Sendable, Equatable {
    let statusCode: Int
    let body: JSONValue?

    static func json(statusCode: Int = 200, _ body: JSONObject) -> ActionAPIResponse {
        ActionAPIResponse(statusCode: statusCode, body: .object(body))
    }

    static func json(statusCode: Int = 200, _ body: JSONValue) -> ActionAPIResponse {
        ActionAPIResponse(statusCode: statusCode, body: body)
    }

    static func empty(statusCode: Int = 204) -> ActionAPIResponse {
        ActionAPIResponse(statusCode: statusCode, body: nil)
    }

    static func error(statusCode: Int, message: String, suggestion: String? = nil) -> ActionAPIResponse {
        var payload: JSONObject = [
            "ok": .bool(false),
            "error": .string(message)
        ]
        if let suggestion {
            payload["suggestion"] = .string(suggestion)
        }
        return ActionAPIResponse(statusCode: statusCode, body: .object(payload))
    }

    func httpData() -> Data {
        let reason = HTTPStatus.reasonPhrase(for: statusCode)
        let bodyData: Data

        if let body {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            bodyData = (try? encoder.encode(body)) ?? Data()
        } else {
            bodyData = Data()
        }

        let headers = [
            "HTTP/1.1 \(statusCode) \(reason)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: http://127.0.0.1",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type, Authorization",
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
        case 401: "Unauthorized"
        case 408: "Request Timeout"
        case 413: "Content Too Large"
        case 415: "Unsupported Media Type"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 431: "Request Header Fields Too Large"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "OK"
        }
    }
}

enum ActionAPIParser {
    static let maximumHeaderBytes = 16 * 1_024
    static let maximumBodyBytes = 1_024 * 1_024
    private static let headerTerminator = Data([13, 10, 13, 10])

    static func expectedRequestLength(in data: Data) throws -> Int? {
        guard let headerRange = data.range(of: headerTerminator) else {
            if data.count > maximumHeaderBytes {
                throw ActionAPIParserError.headersTooLarge
            }
            return nil
        }

        let headerByteCount = headerRange.lowerBound
        guard headerByteCount <= maximumHeaderBytes else {
            throw ActionAPIParserError.headersTooLarge
        }
        let headerData = data[..<headerByteCount]
        guard let headerBlock = String(data: headerData, encoding: .utf8) else {
            throw ActionAPIParserError.invalidEncoding
        }
        let (_, headers) = try parseHead(headerBlock)

        if headers["transfer-encoding"] != nil {
            throw ActionAPIParserError.unsupportedTransferEncoding
        }
        let bodyLength = try contentLength(from: headers)
        guard bodyLength <= maximumBodyBytes else {
            throw ActionAPIParserError.bodyTooLarge
        }
        return headerRange.upperBound + bodyLength
    }

    static func parse(data: Data) throws -> ActionAPIRequest {
        guard let expectedLength = try expectedRequestLength(in: data) else {
            throw ActionAPIParserError.incompleteRequest
        }
        guard data.count >= expectedLength else {
            throw ActionAPIParserError.incompleteRequest
        }
        guard data.count == expectedLength,
              let headerRange = data.range(of: headerTerminator) else {
            throw ActionAPIParserError.invalidRequest
        }
        let headerData = data[..<headerRange.lowerBound]
        guard let headerBlock = String(data: headerData, encoding: .utf8) else {
            throw ActionAPIParserError.invalidEncoding
        }
        let (requestParts, headers) = try parseHead(headerBlock)
        let method = requestParts.method
        let target = requestParts.target
        guard target.hasPrefix("/"), let components = URLComponents(string: target) else {
            throw ActionAPIParserError.invalidRequestTarget
        }
        let path = components.path.isEmpty ? "/" : components.path
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value {
                query[item.name] = value
            }
        }

        let bodyData = data[headerRange.upperBound...]
        let body: JSONObject
        if bodyData.isEmpty {
            body = [:]
        } else {
            let mediaType = headers["content-type"]?
                .split(separator: ";", maxSplits: 1)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard mediaType == "application/json" else {
                throw ActionAPIParserError.unsupportedMediaType
            }
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: Data(bodyData)),
                  let dictionary = value.objectValue else {
                throw ActionAPIParserError.invalidJSONBody
            }
            body = dictionary
        }

        return ActionAPIRequest(method: method, path: path, query: query, headers: headers, body: body)
    }

    private static func parseHead(_ headerBlock: String) throws -> (
        request: (method: String, target: String),
        headers: [String: String]
    ) {
        let headerLines = headerBlock.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else {
            throw ActionAPIParserError.invalidRequest
        }
        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard requestParts.count == 3,
              requestParts[2] == "HTTP/1.1",
              !requestParts[0].isEmpty else {
            throw ActionAPIParserError.invalidRequest
        }

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            guard !line.isEmpty,
                  let separator = line.firstIndex(of: ":") else {
                throw ActionAPIParserError.invalidRequest
            }
            let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, headers[name] == nil else {
                throw ActionAPIParserError.invalidRequest
            }
            headers[name] = value
        }
        return ((requestParts[0].uppercased(), requestParts[1]), headers)
    }

    private static func contentLength(from headers: [String: String]) throws -> Int {
        guard let rawValue = headers["content-length"] else {
            return 0
        }
        guard !rawValue.isEmpty,
              rawValue.allSatisfy(\.isNumber),
              let length = Int(rawValue) else {
            throw ActionAPIParserError.invalidContentLength
        }
        return length
    }
}

enum ActionAPIParserError: Error, Equatable {
    case invalidEncoding
    case invalidRequest
    case invalidRequestTarget
    case invalidContentLength
    case incompleteRequest
    case invalidJSONBody
    case unsupportedMediaType
    case unsupportedTransferEncoding
    case headersTooLarge
    case bodyTooLarge

    var statusCode: Int {
        switch self {
        case .headersTooLarge:
            431
        case .bodyTooLarge:
            413
        case .unsupportedMediaType:
            415
        default:
            400
        }
    }
}
