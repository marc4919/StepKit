//
//  KitService.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import Foundation

/// Servicio encargado de la generación de kits con IA
struct KitService {
    private let client: HTTPClient
    private let baseURL: String
    
    init(client: HTTPClient, baseURL: String) {
        self.client = client
        self.baseURL = baseURL
    }
    
    /// Genera un kit usando IA (síncrono)
    func generateKit(from request: AIGenerateKitRequest, token: String) async throws -> AIGenerateKitResponse {
        guard let url = URL(string: "\(baseURL)/ai/chat-sync") else {
            throw APIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        return try await client.request(urlRequest)
    }
    
    /// Genera un kit usando IA con streaming SSE
    func streamKitGeneration(from request: AIGenerateKitRequest, token: String) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
        let baseURL = self.baseURL
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(baseURL)/ai/chat") else {
                        continuation.finish(throwing: APIError.invalidResponse)
                        return
                    }
                    
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    
                    let encoder = JSONEncoder()
                    urlRequest.httpBody = try encoder.encode(request)
                    
                    // Nota: HTTPClient actual no soporta streaming de bytes fácilmente, usamos URLSession directo aquí por ahora
                    // Idealmente HTTPClient debería soportar streaming o exponer la session.
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.invalidResponse)
                        return
                    }
                    
                    switch httpResponse.statusCode {
                    case 200...299: break
                    case 401: throw APIError.notAuthenticated
                    case 402: throw APIError.premiumRequired
                    case 429: throw APIError.quotaExceeded
                    default: throw APIError.serverError(httpResponse.statusCode, "Stream error")
                    }
                    
                    var buffer = Data()
                    let newline: UInt8 = 0x0A
                    
                    for try await byte in bytes {
                        buffer.append(byte)
                        while buffer.count >= 2 {
                            let doubleNewline = Data([newline, newline])
                            guard let range = buffer.range(of: doubleNewline) else { break }
                            
                            let eventData = buffer[..<range.lowerBound]
                            buffer = buffer[range.upperBound...]
                            
                            if let eventString = String(data: eventData, encoding: .utf8),
                               eventString.hasPrefix("data: ") {
                                let jsonString = String(eventString.dropFirst(6))
                                if let jsonData = jsonString.data(using: .utf8) {
                                    do {
                                        let event = try JSONDecoder().decode(AIChatStreamEvent.self, from: jsonData)
                                        continuation.yield(event)
                                    } catch {
                                        print("❌ SSE Decode error: \(error)")
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
}
