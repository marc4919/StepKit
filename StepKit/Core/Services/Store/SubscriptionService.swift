//
//  SubscriptionService.swift
//  StepKit
//
//  Created by StepKit Refactoring Agent
//

import Foundation

/// Servicio encargado de la validación de suscripciones
struct SubscriptionService {
    private let client: HTTPClient
    private let baseURL: String
    
    init(client: HTTPClient, baseURL: String) {
        self.client = client
        self.baseURL = baseURL
    }
    
    /// Verifica una transacción de StoreKit con el backend
    func verifySubscription(transactionId: String, token: String) async throws -> VerifySubscriptionResponse {
        guard let url = URL(string: "\(baseURL)/subscription/verify") else {
             throw APIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["transactionId": transactionId]
        urlRequest.httpBody = try JSONEncoder().encode(body)
        
        return try await client.request(urlRequest)
    }
}
