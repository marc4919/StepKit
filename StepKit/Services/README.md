# Services - Protocolos y Mocks

Este directorio contiene los servicios principales de la app con soporte para protocolos y mocks para testing.

## Arquitectura

### Protocolos

- **`APIClientProtocol`**: Protocolo para el cliente de API
- **`AuthManaging`**: Protocolo para gestión de autenticación

### Implementaciones Reales

- **`APIClient`**: Cliente HTTP real para comunicarse con el backend
- **`AuthManager`**: Gestor de autenticación real usando Keychain

### Mocks

- **`MockAPIClient`**: Mock del cliente API para tests y previews
- **`MockAuthManager`**: Mock del gestor de autenticación para tests y previews

## Uso en Previews

### Preview con Mock API

```swift
#Preview("Login Success") {
    let mockAPI = MockAPIClient()
    mockAPI.shouldFailLogin = false
    mockAPI.simulatedDelay = 0.1
    
    return SignInView()
        .environment(AuthManager())
        .environment(\.apiClient, mockAPI)
}

#Preview("Login Error") {
    let mockAPI = MockAPIClient()
    mockAPI.shouldFailLogin = true
    
    return SignInView()
        .environment(AuthManager())
        .environment(\.apiClient, mockAPI)
}
```

### Preview con Mock Auth

```swift
#Preview("Authenticated User") {
    let mockAuth = MockAuthManager(
        isAuthenticated: true,
        user: UserInfo(
            id: UUID().uuidString,
            tier: "premium",
            monthlyTokensUsed: 2500,
            monthlyTokenQuota: 10000
        ),
        token: "mock-token"
    )
    
    return ProfileView()
        .environment(mockAuth)
}
```

## Uso en Tests

### Test Unitario con Mock API

```swift
@Test("Should handle login success")
func loginSuccess() async throws {
    let mockClient = MockAPIClient()
    mockClient.shouldFailLogin = false
    mockClient.simulatedDelay = 0.01
    
    let response = try await mockClient.signInWithApple(identityToken: "test")
    #expect(response.token.starts(with: "mock-jwt-token"))
}
```

### Test Unitario con Mock Auth

```swift
@Test("Should save auth correctly")
func savesAuth() {
    let mockAuth = MockAuthManager()
    let user = UserInfo(id: "123", tier: "premium", monthlyTokensUsed: 0, monthlyTokenQuota: 10000)
    
    mockAuth.saveAuth(token: "test-token", user: user)
    
    #expect(mockAuth.isAuthenticated == true)
    #expect(mockAuth.currentUser?.id == "123")
}
```

## Configuración de Mocks

### MockAPIClient

- `shouldFailLogin: Bool` - Si es `true`, el login siempre fallará
- `loginError: Error?` - Error personalizado para el login
- `mockAuthResponse: AuthResponse?` - Respuesta mock personalizada
- `simulatedDelay: TimeInterval` - Delay simulado para latencia de red (default: 0.5s)

### MockAuthManager

- `isAuthenticated: Bool` - Estado inicial de autenticación
- `currentUser: UserInfo?` - Usuario inicial
- `token: String?` - Token inicial

## Inyección de Dependencias

Los servicios se inyectan usando `@Environment`:

```swift
struct MyView: View {
    @Environment(\.apiClient) private var apiClient
    @Environment(AuthManager.self) private var authManager
}
```

En la app principal:

```swift
.environment(\.apiClient, APIClient()) // Real
.environment(\.apiClient, MockAPIClient()) // Mock
```


