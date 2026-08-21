//
//  APIClientEnvironmentKey.swift
//  StepKit
//
//  Created by Marc Garcia Teodoro on [Date]
//

import SwiftUI

private enum APIClientEnvironmentDefault {
    static let client: any APIClientProtocol = APIClient()
}

extension EnvironmentValues {
    /// Cliente API inyectado en el environment
    @Entry var apiClient: any APIClientProtocol = APIClientEnvironmentDefault.client
}
