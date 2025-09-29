//  AuthService.swift
//  SnapPic
//  Firebase Auth (REST) email/password signup, login, and password reset.

import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth

struct FirebaseAuthError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct AuthUser: Codable { let idToken: String; let refreshToken: String; let localId: String; let email: String }

final class AuthService {
    static let shared = AuthService()
    private init() {}

    private var apiKey: String {
        // Prefer Firebase configured options (GoogleService-Info.plist), then Info.plist override, then env var
        if let key = FirebaseApp.app()?.options.apiKey, !key.isEmpty { return key }
        if let key = Bundle.main.object(forInfoDictionaryKey: "FirebaseAPIKey") as? String, !key.isEmpty { return key }
        if let env = ProcessInfo.processInfo.environment["FIREBASE_API_KEY"], !env.isEmpty { return env }
        return ""
    }

    // MARK: - Public API
    func signUp(email: String, password: String, displayName: String?) async throws -> AuthUser {
        struct Req: Encodable { let email: String; let password: String; let returnSecureToken = true }
        let req = Req(email: email, password: password)
        let data = try await post(path: "/v1/accounts:signUp", body: req)
        let user = try parseAuthUser(data)
        // Optionally set display name
        if let name = displayName, !name.isEmpty {
            try? await updateProfile(idToken: user.idToken, displayName: name)
        }
        return user
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        struct Req: Encodable { let email: String; let password: String; let returnSecureToken = true }
        let req = Req(email: email, password: password)
        let data = try await post(path: "/v1/accounts:signInWithPassword", body: req)
        return try parseAuthUser(data)
    }

    // Exchange Google tokens for Firebase credentials using REST
    func signInWithGoogle(idToken: String?, accessToken: String?) async throws -> AuthUser {
        struct Req: Encodable {
            let postBody: String
            let requestUri: String = "http://localhost"
            let returnSecureToken: Bool = true
            let returnIdpCredential: Bool = true
        }
        func enc(_ s: String) -> String {
            s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
        }
        // Build postBody using either id_token or access_token
        var bodyParts: [String] = []
        if let idt = idToken, !idt.isEmpty { bodyParts.append("id_token=\(enc(idt))") }
        if let at = accessToken, !at.isEmpty { bodyParts.append("access_token=\(enc(at))") }
        bodyParts.append("providerId=google.com")
        let postBody = bodyParts.joined(separator: "&")
        let req = Req(postBody: postBody)
        let data = try await post(path: "/v1/accounts:signInWithIdp", body: req)
        return try parseAuthUser(data)
    }

    func sendPasswordReset(email: String) async throws {
        // Prefer FirebaseAuth SDK to send reset email
        Auth.auth().languageCode = Locale.preferredLanguages.first
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let nsError = error as NSError? {
                    let message: String
                    if let authErr = AuthErrorCode(_bridgedNSError: nsError) {
                        switch authErr.code {
                        case .invalidEmail: message = "Enter a valid email address"
                        case .userNotFound: message = "Email not found"
                        case .userDisabled: message = "Account disabled"
                        case .networkError: message = "Network error. Try again"
                        default: message = nsError.localizedDescription
                        }
                    } else {
                        message = nsError.localizedDescription
                    }
                    continuation.resume(throwing: FirebaseAuthError(message: message))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Helpers
    private func updateProfile(idToken: String, displayName: String) async throws {
        struct Req: Encodable { let idToken: String; let displayName: String; let returnSecureToken = false }
        _ = try await post(path: "/v1/accounts:update", body: Req(idToken: idToken, displayName: displayName))
    }

    private func baseURL(_ path: String) throws -> URL {
        guard !apiKey.isEmpty else {
            throw FirebaseAuthError(message: "Missing Firebase API key. Ensure GoogleService-Info.plist is added to the target, or set Info.plist 'FirebaseAPIKey', or env 'FIREBASE_API_KEY'.")
        }
        var comps = URLComponents(string: "https://identitytoolkit.googleapis.com\(path)")!
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return comps.url!
    }

    private func post<T: Encodable>(path: String, body: T) async throws -> Data {
        let url = try baseURL(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FirebaseAuthError(message: "No HTTP response") }
        if (200..<300).contains(http.statusCode) { return data }
        // Try decode Firebase error
        if let fbMsg = try? decodeFirebaseError(data) { throw FirebaseAuthError(message: fbMsg) }
        throw FirebaseAuthError(message: "HTTP \(http.statusCode)")
    }

    private func parseAuthUser(_ data: Data) throws -> AuthUser {
        struct Res: Decodable { let idToken: String; let refreshToken: String; let localId: String; let email: String }
        let r = try JSONDecoder().decode(Res.self, from: data)
        return AuthUser(idToken: r.idToken, refreshToken: r.refreshToken, localId: r.localId, email: r.email)
    }

    private func decodeFirebaseError(_ data: Data) throws -> String {
        struct E: Decodable { struct ErrorInfo: Decodable { let message: String }; let error: ErrorInfo }
        let e = try JSONDecoder().decode(E.self, from: data)
        // Map common codes
        switch e.error.message {
        case "EMAIL_EXISTS": return "Email already in use"
        case "OPERATION_NOT_ALLOWED": return "Operation not allowed"
        case "TOO_MANY_ATTEMPTS_TRY_LATER": return "Too many attempts. Try later"
        case "EMAIL_NOT_FOUND": return "Email not found"
        case "INVALID_PASSWORD": return "Invalid password"
        case "USER_DISABLED": return "Account disabled"
        default: return e.error.message.replacingOccurrences(of: "_", with: " ")
        }
    }
}
