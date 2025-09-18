//  LoginView.swift
//  SnapPic
//
//  
//
//  A simple login screen UI placeholder.

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private let logoStackSpacing: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: logoStackSpacing) {
                    Image("SnapPic_Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 150)
                    Text("Login for SnapPic")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        Text("Email").font(.headline)
                        TextField("Enter email", text: $auth.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                        Divider().opacity(0)
                        Text("Password").font(.headline)
                        SecureField("Enter password", text: $auth.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                    }
                    .textFieldStyle(.roundedBorder)

                    HStack { Spacer() }
                    Button("Forgot Password?") { auth.forgotPassword() }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if let error = auth.errorMessage { Text(error).foregroundStyle(.red).multilineTextAlignment(.center) }
                if let info = auth.infoMessage { Text(info).foregroundStyle(.blue).multilineTextAlignment(.center) }

                Button(action: auth.signIn) {
                    ZStack {
                        if auth.isLoading { ProgressView().progressViewStyle(.circular) }
                        Text("Sign in").opacity(auth.isLoading ? 0 : 1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(auth.isLoading)

                Button(action: auth.signInWithGoogle) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                        Text("Log in with ") + Text("Google").bold()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.3), lineWidth: 1))

                HStack(spacing: 4) {
                    Text("Don't have an account?")
                    Button("Sign Up Now") { auth.showSignUpPage() }
                }
                .font(.subheadline)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 36)
        }
        .onSubmit(handleSubmit)
        .background(Color(.systemBackground))
    }

    private func handleSubmit() {
        switch focusedField {
        case .email: focusedField = .password
        default: auth.signIn()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
