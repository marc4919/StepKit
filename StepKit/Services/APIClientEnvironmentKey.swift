//
//  APIClientEnvironmentKey.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import SwiftUI

/// Environment key para inyectar el cliente API
private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClientProtocol = APIClient()
}

extension EnvironmentValues {
    /// Cliente API inyectado en el environment
    var apiClient: APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}


