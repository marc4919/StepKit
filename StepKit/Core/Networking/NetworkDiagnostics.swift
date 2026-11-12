//
//  NetworkDiagnostics.swift
//  StepKit
//

import Foundation
import os

/// Diagnóstico de red deliberadamente limitado a metadatos no sensibles.
enum NetworkDiagnostics {
    #if DEBUG
    nonisolated static func logEnvironment(_ environment: AppEnvironment) {
        AppLog.network.debug(
            "Network environment: \(environment.buildConfiguration.rawValue, privacy: .public), host=\(environment.apiBaseURL.host ?? "unknown", privacy: .public)"
        )
    }

    nonisolated static func logRequest(
        operation: String,
        byteCount: Int,
        itemCount: Int? = nil
    ) {
        if let itemCount {
            AppLog.network.debug("\(operation, privacy: .public) request: bytes=\(byteCount), items=\(itemCount)")
        } else {
            AppLog.network.debug("\(operation, privacy: .public) request: bytes=\(byteCount)")
        }
    }

    nonisolated static func logResponse(
        operation: String,
        statusCode: Int,
        byteCount: Int
    ) {
        AppLog.network.debug("\(operation, privacy: .public) response: status=\(statusCode), bytes=\(byteCount)")
    }

    nonisolated static func logError(_ error: Error, operation: String) {
        if case let APIError.serverError(statusCode, _) = error {
            AppLog.network.error("\(operation, privacy: .public): server status=\(statusCode)")
        } else {
            AppLog.network.error("\(operation, privacy: .public): type=\(String(describing: type(of: error)), privacy: .public)")
        }
    }

    nonisolated static func logDecodingError(_ error: Error, operation: String) {
        guard let decodingError = error as? DecodingError else {
            AppLog.network.error("\(operation, privacy: .public): decoding error")
            return
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            AppLog.network.error("\(operation, privacy: .public): missing key=\(key.stringValue, privacy: .public), path=\(path(context.codingPath), privacy: .public)")
        case .typeMismatch(let expectedType, let context):
            AppLog.network.error(
                "\(operation, privacy: .public): type mismatch=\(String(describing: expectedType), privacy: .public), path=\(path(context.codingPath), privacy: .public)"
            )
        case .valueNotFound(let expectedType, let context):
            AppLog.network.error(
                "\(operation, privacy: .public): missing value=\(String(describing: expectedType), privacy: .public), path=\(path(context.codingPath), privacy: .public)"
            )
        case .dataCorrupted(let context):
            AppLog.network.error("\(operation, privacy: .public): corrupted data, path=\(path(context.codingPath), privacy: .public)")
        @unknown default:
            AppLog.network.error("\(operation, privacy: .public): unknown decoding error")
        }
    }

    private nonisolated static func path(_ codingPath: [any CodingKey]) -> String {
        let value = codingPath.map(\.stringValue).joined(separator: ".")
        return value.isEmpty ? "root" : value
    }
    #endif
}
