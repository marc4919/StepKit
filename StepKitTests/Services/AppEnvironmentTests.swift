//
//  AppEnvironmentTests.swift
//  StepKitTests
//

import Foundation
import Testing
@testable import StepKit

@Suite("App environment")
@MainActor
struct AppEnvironmentTests {
    #if DEBUG
    @Test("Debug app bundle resolves to the local endpoint")
    func debugBundleResolvesToLocalEndpoint() {
        #expect(AppEnvironment.current.buildConfiguration == .debug)
        #expect(AppEnvironment.current.apiBaseURL == URL(string: "http://localhost:8080"))
    }
    #endif

    @Test("Debug uses localhost by default")
    func debugUsesLocalhostByDefault() throws {
        let environment = try AppEnvironment.configured(
            buildConfiguration: .debug,
            configuredBaseURL: "http://localhost:8080"
        )

        #expect(environment.buildConfiguration == .debug)
        #expect(environment.apiBaseURL == URL(string: "http://localhost:8080"))
    }

    @Test("Debug accepts an explicit HTTP or HTTPS override")
    func debugAcceptsExplicitOverride() throws {
        let environment = try AppEnvironment.configured(
            buildConfiguration: .debug,
            configuredBaseURL: "http://localhost:8080",
            debugOverride: "https://staging.example.com/"
        )

        #expect(environment.apiBaseURL == URL(string: "https://staging.example.com"))
    }

    @Test("API paths are derived from the shared base URL")
    func apiPathsUseSharedBaseURL() throws {
        let environment = try AppEnvironment.configured(
            buildConfiguration: .debug,
            configuredBaseURL: "http://localhost:8080"
        )
        let client = APIClient(environment: environment)

        let request = client.authenticatedRequest(path: "/me", token: "test-token")

        #expect(request.url == URL(string: "http://localhost:8080/me"))
    }

    @Test("Release accepts a public HTTPS origin")
    func releaseAcceptsPublicHTTPSOrigin() throws {
        let environment = try AppEnvironment.configured(
            buildConfiguration: .release,
            configuredBaseURL: "https://fcloud.example.com"
        )

        #expect(environment.buildConfiguration == .release)
        #expect(environment.apiBaseURL == URL(string: "https://fcloud.example.com"))
    }

    @Test("Release rejects process overrides")
    func releaseRejectsOverride() {
        #expect(throws: AppEnvironment.ConfigurationError.releaseRejectsOverride) {
            try AppEnvironment.configured(
                buildConfiguration: .release,
                configuredBaseURL: "https://api.example.com",
                debugOverride: "https://another.example.com"
            )
        }
    }

    @Test("Release rejects HTTP")
    func releaseRejectsHTTP() {
        #expect(throws: AppEnvironment.ConfigurationError.releaseRequiresHTTPS) {
            try AppEnvironment.configured(
                buildConfiguration: .release,
                configuredBaseURL: "http://api.example.com"
            )
        }
    }

    @Test(
        "Release rejects local hosts",
        arguments: [
            "https://localhost:8080",
            "https://127.0.0.1",
            "https://192.168.1.4",
            "https://[::1]",
            "https://[fd00::1]",
            "https://service.local"
        ]
    )
    func releaseRejectsLocalHosts(baseURL: String) {
        #expect(throws: AppEnvironment.ConfigurationError.releaseRejectsLocalHost) {
            try AppEnvironment.configured(
                buildConfiguration: .release,
                configuredBaseURL: baseURL
            )
        }
    }

    @Test("Base URL rejects credentials, paths, queries and fragments")
    func baseURLMustBeAnOrigin() {
        for baseURL in [
            "https://user:password@example.com",
            "https://example.com/api",
            "https://example.com?token=value",
            "https://example.com#fragment"
        ] {
            #expect(throws: AppEnvironment.ConfigurationError.baseURLMustBeAnOrigin) {
                try AppEnvironment.configured(
                    buildConfiguration: .debug,
                    configuredBaseURL: baseURL
                )
            }
        }
    }

    #if DEBUG
    @Test("Debug launch argument is parsed once")
    func debugLaunchArgumentIsParsedOnce() throws {
        let value = try AppEnvironment.debugBaseURLOverride(
            from: ["StepKit", "-StepKitAPIBaseURL", "http://localhost:9090"]
        )

        #expect(value == "http://localhost:9090")
        #expect(throws: AppEnvironment.ConfigurationError.duplicateOverride) {
            try AppEnvironment.debugBaseURLOverride(
                from: [
                    "StepKit",
                    "-StepKitAPIBaseURL", "http://localhost:8080",
                    "-StepKitAPIBaseURL", "http://localhost:9090"
                ]
            )
        }
    }
    #endif

    @Test("Server errors redact their response body")
    func serverErrorsRedactBody() {
        let sensitiveBody = "private-response-body"
        let error = APIError.serverError(500, sensitiveBody)

        #expect(!error.localizedDescription.contains(sensitiveBody))
        #expect(!String(describing: error).contains(sensitiveBody))
    }
}
