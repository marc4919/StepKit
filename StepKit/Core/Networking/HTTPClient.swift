//
//  HTTPClient.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import Foundation

/// Actor base para realizar peticiones HTTP crudas
actor HTTPClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Realiza una petición HTTP y decodifica la respuesta
    /// - Parameter request: URLRequest configurado
    /// - Returns: Modelo decodificado
    func request<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Debug: imprimir respuesta si hay error o en debug
        #if DEBUG
        if !(200...299).contains(httpResponse.statusCode) {
             if let jsonString = String(data: data, encoding: .utf8) {
                 print("❌ HTTP Error \(httpResponse.statusCode): \(jsonString)")
             }
        }
        #endif
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Mapeo específico de códigos de error comunes
            switch httpResponse.statusCode {
            case 401: throw APIError.notAuthenticated
            case 402: throw APIError.premiumRequired
            case 429: throw APIError.quotaExceeded
            default: throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Intentar ISO8601 estándar primero
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            // Intentar varios formatos de fecha
            let formatters = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd"
            ]
            
            for format in formatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Decoding Error: \(error)")
            #endif
            throw APIError.decodingError(error)
        }
    }
}
