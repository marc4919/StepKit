//
//  NetworkDiagnostics.swift
//  StepKit
//

import Foundation

/// Diagnóstico de red deliberadamente limitado a metadatos no sensibles.
enum NetworkDiagnostics {
    #if DEBUG
    nonisolated static func logEnvironment(_ environment: AppEnvironment) {
        print(
            "🌐 Network environment: \(environment.buildConfiguration.rawValue), " +
            "host=\(environment.apiBaseURL.host ?? "unknown")"
        )
    }

    nonisolated static func logRequest(
        operation: String,
        byteCount: Int,
        itemCount: Int? = nil
    ) {
        if let itemCount {
            print("📤 \(operation): bytes=\(byteCount), items=\(itemCount)")
        } else {
            print("📤 \(operation): bytes=\(byteCount)")
        }
    }

    nonisolated static func logResponse(
        operation: String,
        statusCode: Int,
        byteCount: Int
    ) {
        print("📥 \(operation): status=\(statusCode), bytes=\(byteCount)")
    }

    nonisolated static func logError(_ error: Error, operation: String) {
        if case let APIError.serverError(statusCode, _) = error {
            print("❌ \(operation): server status=\(statusCode)")
        } else {
            print("❌ \(operation): type=\(String(describing: type(of: error)))")
        }
    }

    nonisolated static func logDecodingError(_ error: Error, operation: String) {
        guard let decodingError = error as? DecodingError else {
            print("❌ \(operation): decoding error")
            return
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            print("❌ \(operation): missing key=\(key.stringValue), path=\(path(context.codingPath))")
        case .typeMismatch(let expectedType, let context):
            print(
                "❌ \(operation): type mismatch=\(String(describing: expectedType)), " +
                "path=\(path(context.codingPath))"
            )
        case .valueNotFound(let expectedType, let context):
            print(
                "❌ \(operation): missing value=\(String(describing: expectedType)), " +
                "path=\(path(context.codingPath))"
            )
        case .dataCorrupted(let context):
            print("❌ \(operation): corrupted data, path=\(path(context.codingPath))")
        @unknown default:
            print("❌ \(operation): unknown decoding error")
        }
    }

    private nonisolated static func path(_ codingPath: [any CodingKey]) -> String {
        let value = codingPath.map(\.stringValue).joined(separator: ".")
        return value.isEmpty ? "root" : value
    }
    #endif
}
