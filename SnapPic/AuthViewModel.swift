//  AuthViewModel.swift
//  SnapPic
//  NOTE: Backend-enabled auth using Firebase REST via AuthService.

import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    // Persist simple login state for routing only (token lives in Keychain)
    @AppStorage("isLoggedIn") private var storedIsLoggedIn: Bool = false
    @Published var isLoggedIn: Bool = false

    // Form fields
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var name: String = ""

    // UI state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var infoMessage: String? = nil
    @Published var showSignUp: Bool = false

    init() {
        // Restore session if a token exists
        if let _ = KeychainHelper.readString(KeychainHelper.Key.idToken) {
            isLoggedIn = true
            storedIsLoggedIn = true
        } else {
            isLoggedIn = storedIsLoggedIn
        }
    }

    func signIn() {
        errorMessage = nil
        infoMessage = nil
        guard validateEmail(email) else { errorMessage = "Enter a valid email address"; return }
        guard !password.isEmpty else { errorMessage = "Password can't be empty"; return }
        isLoading = true
        Task {
            do {
                let user = try await AuthService.shared.signIn(email: email, password: password)
                setSession(user)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isLoggedIn = false
                storedIsLoggedIn = false
            }
            isLoading = false
        }
    }

    func signUp() {
        errorMessage = nil
        infoMessage = nil
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Name is required"; return }
        guard validateEmail(email) else { errorMessage = "Enter a valid email address"; return }
        guard password.count >= 6 else { errorMessage = "Password must be at least 6 characters"; return }
        isLoading = true
        Task {
            do {
                let user = try await AuthService.shared.signUp(email: email, password: password, displayName: name)
                setSession(user)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isLoggedIn = false
                storedIsLoggedIn = false
            }
            isLoading = false
        }
    }

    func forgotPassword() {
        errorMessage = nil
        infoMessage = nil
        guard validateEmail(email) else { errorMessage = "Enter your account email"; return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await AuthService.shared.sendPasswordReset(email: email)
                infoMessage = "Password reset email sent"
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func signInWithGoogle() {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isLoading = false }
            do {
                let idToken = try await GoogleOAuthHelper.getIDToken()
                let user = try await AuthService.shared.signInWithGoogle(idToken: idToken, accessToken: nil)
                self.setSession(user)
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func signUpWithGoogle() {
        // Same flow as sign-in: IdP creates account if it doesn't exist
        signInWithGoogle()
    }

    func signOut() {
        KeychainHelper.clearAll()
        isLoggedIn = false
        storedIsLoggedIn = false
        clearFields()
    }

    func showLogin() {
        showSignUp = false
        clearFields()
    }

    func showSignUpPage() {
        showSignUp = true
        clearFields()
    }

    private func setSession(_ user: AuthUser) {
        KeychainHelper.saveString(user.idToken, key: KeychainHelper.Key.idToken)
        KeychainHelper.saveString(user.refreshToken, key: KeychainHelper.Key.refreshToken)
        KeychainHelper.saveString(user.localId, key: KeychainHelper.Key.userId)
        KeychainHelper.saveString(user.email, key: KeychainHelper.Key.email)
        isLoggedIn = true
        storedIsLoggedIn = true
    }

    private func clearFields() {
        email = ""
        password = ""
        name = ""
        errorMessage = nil
        infoMessage = nil
    }

    // Basic email validation used by tests
    func validateEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
