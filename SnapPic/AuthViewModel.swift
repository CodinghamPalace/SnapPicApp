//  AuthViewModel.swift
//  SnapPic
//
//  Created by Automated Assistant on 8/28/25.
//
//  NOTE: This is a lightweight placeholder auth layer. Replace with real backend / Firebase later.

import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    // Persist simple login state (NOT secure, just demo)
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
        isLoggedIn = storedIsLoggedIn
    }

    func signIn() {
        errorMessage = nil
        infoMessage = nil
        guard validateEmail(email) else {
            errorMessage = "Enter a valid email address"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password can't be empty"
            return
        }
        isLoading = true
        // Simulate network delay
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
            guard let self else { return }
            // Accept any credentials for demo
            self.isLoading = false
            self.isLoggedIn = true
            self.storedIsLoggedIn = true
        }
    }

    func signOut() {
        isLoggedIn = false
        storedIsLoggedIn = false
        email = ""
        password = ""
    }

    func forgotPassword() {
        errorMessage = nil
        infoMessage = "Password reset link (demo) would be sent to \(email)."
    }

    func signInWithGoogle() {
        errorMessage = nil
        infoMessage = "Google Sign-In not implemented in demo"
    }

    func signUp() {
        errorMessage = nil
        infoMessage = nil
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Name is required"
            return
        }
        guard validateEmail(email) else {
            errorMessage = "Enter a valid email address"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        isLoading = true
        // Simulate network delay
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            guard let self else { return }
            // Accept any credentials for demo
            self.isLoading = false
            self.isLoggedIn = true
            self.storedIsLoggedIn = true
        }
    }

    func signUpWithGoogle() {
        errorMessage = nil
        infoMessage = "Google Sign-Up not implemented in demo"
    }

    func showLogin() {
        showSignUp = false
        clearFields()
    }

    func showSignUpPage() {
        showSignUp = true
        clearFields()
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
