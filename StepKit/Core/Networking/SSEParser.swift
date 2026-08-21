//
//  SSEParser.swift
//  StepKit
//
//  Parser para Server-Sent Events (SSE).
//

import Foundation

/// Parser de eventos SSE (Server-Sent Events)
enum SSEParser {

    /// Parsea un stream de bytes SSE y emite eventos decodificados
    /// - Parameters:
    ///   - bytes: AsyncSequence de bytes del stream
    ///   - decoder: Decodificador a usar (default: JSONDecoder)
    /// - Returns: AsyncThrowingStream de eventos decodificados
    static func parse<T: Decodable, S: AsyncSequence>(
        _ bytes: S,
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) -> AsyncThrowingStream<T, Error> where S.Element == UInt8 {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                let newline: UInt8 = 0x0A
                let doubleNewline = Data([newline, newline])

                do {
                    for try await byte in bytes {
                        buffer.append(byte)

                        // Buscar doble newline (fin de evento SSE)
                        while buffer.count >= 2 {
                            guard let range = buffer.range(of: doubleNewline) else {
                                break
                            }

                            let eventData = buffer[..<range.lowerBound]
                            buffer = buffer[range.upperBound...]

                            if let eventString = String(data: eventData, encoding: .utf8),
                               eventString.hasPrefix("data: ") {
                                let jsonString = String(eventString.dropFirst(6))

                                #if DEBUG
                                NetworkDiagnostics.logRequest(
                                    operation: "SSE frame received",
                                    byteCount: jsonString.utf8.count
                                )
                                #endif

                                if let jsonData = jsonString.data(using: .utf8) {
                                    do {
                                        let event = try decoder.decode(T.self, from: jsonData)
                                        continuation.yield(event)
                                    } catch {
                                        #if DEBUG
                                        Self.logDecodingError(error)
                                        #endif
                                    }
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    #if DEBUG
    private nonisolated static func logDecodingError(_ error: Error) {
        NetworkDiagnostics.logDecodingError(error, operation: "SSE frame")
    }
    #endif
}
