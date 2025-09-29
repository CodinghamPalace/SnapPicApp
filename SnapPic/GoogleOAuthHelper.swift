//  GoogleOAuthHelper.swift
//  SnapPic
//  Lightweight Google OAuth via ASWebAuthenticationSession to obtain an ID token.

import Foundation
@preconcurrency import AuthenticationServices
import FirebaseCore
import UIKit

enum GoogleOAuthError: Error, LocalizedError {
    case missingClientID
    case missingReversedClientID
    case userCancelled
    case invalidRedirect
    case missingIDToken
    case schemeNotRegistered(String)

    var errorDescription: String? {
        switch self {
        case .missingClientID: return "Missing Google client ID"
        case .missingReversedClientID: return "Missing REVERSED_CLIENT_ID in GoogleService-Info.plist"
        case .userCancelled: return "Sign-in cancelled"
        case .invalidRedirect: return "Invalid redirect URL"
        case .missingIDToken: return "No Google ID token returned"
        case .schemeNotRegistered(let scheme):
            return "URL scheme not registered: \(scheme). Add it under Info.plist > CFBundleURLTypes."
        }
    }
}

final class GoogleOAuthHelper: NSObject {
    // Keep a strong reference to the session so it isn't deallocated during auth
    private static var currentSession: ASWebAuthenticationSession?

    private static func findReversedClientID() -> String? {
        // 1) Prefer URL Types in Info.plist
        if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
            for entry in urlTypes {
                if let schemes = entry["CFBundleURLSchemes"] as? [String] {
                    if let s = schemes.first(where: { $0.hasPrefix("com.googleusercontent.apps.") }) { return s }
                }
            }
        }
        // 2) Info.plist explicit override (optional)
        if let override = Bundle.main.object(forInfoDictionaryKey: "GoogleReversedClientID") as? String, !override.isEmpty {
            return override
        }
        // 3) Scan all GoogleService-Info*.plist in bundle for REVERSED_CLIENT_ID
        let allPlists = Bundle.main.paths(forResourcesOfType: "plist", inDirectory: nil)
        for path in allPlists where path.localizedCaseInsensitiveContains("GoogleService-Info") {
            if let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
               let reversed = dict["REVERSED_CLIENT_ID"] as? String, !reversed.isEmpty {
                return reversed
            }
        }
        // 4) Last chance: the canonical file name
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let reversed = dict["REVERSED_CLIENT_ID"] as? String, !reversed.isEmpty { return reversed }
        return nil
    }

    private static func findClientID() -> String? {
        // 1) Firebase options
        if let cid = FirebaseApp.app()?.options.clientID, !cid.isEmpty { return cid }
        // 2) Info.plist explicit override (optional)
        if let cid = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String, !cid.isEmpty { return cid }
        // 3) Scan all GoogleService-Info*.plist for CLIENT_ID
        let allPlists = Bundle.main.paths(forResourcesOfType: "plist", inDirectory: nil)
        for path in allPlists where path.localizedCaseInsensitiveContains("GoogleService-Info") {
            if let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
               let cid = dict["CLIENT_ID"] as? String, !cid.isEmpty {
                return cid
            }
        }
        // 4) Canonical file name
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let cid = dict["CLIENT_ID"] as? String, !cid.isEmpty { return cid }
        return nil
    }

    private static func reversedFromClientID(_ clientID: String) -> String? {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else { return nil }
        let prefix = String(clientID.dropLast(suffix.count))
        return "com.googleusercontent.apps.\(prefix)"
    }

    private static func isSchemeRegistered(_ scheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else { return false }
        for entry in urlTypes {
            if let schemes = entry["CFBundleURLSchemes"] as? [String], schemes.contains(scheme) { return true }
        }
        return false
    }

    @MainActor
    static func getIDToken() async throws -> String {
        // Get clientID and reversed client ID
        guard let clientID = findClientID(), !clientID.isEmpty else { throw GoogleOAuthError.missingClientID }
        // Try to find reversed; if not present, derive from CLIENT_ID
        var reversed = findReversedClientID()
        if reversed == nil {
            reversed = reversedFromClientID(clientID)
        }
        guard let reversedScheme = reversed, !reversedScheme.isEmpty else { throw GoogleOAuthError.missingReversedClientID }
        // Ensure the scheme is registered in Info.plist so the session can callback
        guard isSchemeRegistered(reversedScheme) else { throw GoogleOAuthError.schemeNotRegistered(reversedScheme) }

        // Build OAuth URL (implicit flow returning id_token)
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "\(reversedScheme):/oauthredirect"),
            URLQueryItem(name: "response_type", value: "id_token"),
            URLQueryItem(name: "response_mode", value: "fragment"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "include_granted_scopes", value: "true"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "nonce", value: UUID().uuidString)
        ]
        let authURL = comps.url!

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            Task { @MainActor in
                let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: reversedScheme) { callbackURL, error in
                    defer { Self.currentSession = nil }
                    if let err = error as? ASWebAuthenticationSessionError {
                        switch err.code {
                        case .canceledLogin:
                            continuation.resume(throwing: GoogleOAuthError.userCancelled)
                            return
                        case .presentationContextInvalid, .presentationContextNotProvided:
                            continuation.resume(throwing: NSError(domain: "GoogleOAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to present Google Sign-In UI. Ensure a visible window exists."]))
                            return
                        default: break
                        }
                    }
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: GoogleOAuthError.invalidRedirect)
                        return
                    }
                    // Attempt to parse id_token from fragment, then query, then raw string
                    func parseIdToken(from url: URL) -> String? {
                        if let fragment = url.fragment, let token = Self.extractIdToken(from: fragment) { return token }
                        if let query = url.query, let token = Self.extractIdToken(from: query) { return token }
                        let raw = url.absoluteString
                        if let hashRange = raw.range(of: "#") {
                            let frag = String(raw[hashRange.upperBound...])
                            if let token = Self.extractIdToken(from: frag) { return token }
                        }
                        return nil
                    }
                    if let idToken = parseIdToken(from: callbackURL), !idToken.isEmpty {
                        continuation.resume(returning: idToken)
                        return
                    }
                    continuation.resume(throwing: GoogleOAuthError.missingIDToken)
                }
                if #available(iOS 13.0, *) {
                    session.presentationContextProvider = PresentationAnchorProvider()
                    session.prefersEphemeralWebBrowserSession = true
                }
                // Keep a strong ref and start on main actor
                Self.currentSession = session
                _ = session.start()
            }
        }
    }

    private static func extractIdToken(from urlEncodedPairs: String) -> String? {
        for pair in urlEncodedPairs.components(separatedBy: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[0] == "id_token" {
                return parts[1].removingPercentEncoding
            }
        }
        return nil
    }
}

@available(iOS 13.0, *)
@MainActor
private final class PresentationAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Prefer a key window in a foreground-active scene
        if let window = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow && !$0.isHidden }) {
            return window
        }
        // Fallback to the first available window
        if let any = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return any
        }
        return ASPresentationAnchor()
    }
}
