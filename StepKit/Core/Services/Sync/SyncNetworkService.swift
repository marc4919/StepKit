//
//  SyncNetworkService.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import Foundation

protocol SyncNetworkServicing {
    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse
}

/// Servicio encargado de la comunicación de red para la sincronización
struct SyncNetworkService: SyncNetworkServicing {
    private let client: HTTPClient
    private let baseURL: String
    
    init(client: HTTPClient, baseURL: String) {
        self.client = client
        self.baseURL = baseURL
    }
    
    /// Sincroniza datos locales con el servidor
    func syncBatch(_ request: SyncBatchRequest, token: String) async throws -> SyncBatchResponse {
        guard let url = URL(string: "\(baseURL)/sync/batch") else {
            throw APIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        return try await client.request(urlRequest)
    }
}
