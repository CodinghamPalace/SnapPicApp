//  SignUpView.swift
//  SnapPic
//
//  Created by STUDENT on 8/28/25.
//
//  Sign up screen matching the provided design.

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 0) {
                    Image("SnapPic_Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 150)
                    Text("Sign Up for SnapPic")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        Text("Name").font(.headline)
                        TextField("Enter name", text: $auth.name)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                        
                        Divider().opacity(0)
                        
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
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                if let info = auth.infoMessage {
                    Text(info)
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.center)
                }

                Button(action: auth.signUp) {
                    ZStack {
                        if auth.isLoading {
                            ProgressView().progressViewStyle(.circular)
                        }
                        Text("Sign Up")
                            .opacity(auth.isLoading ? 0 : 1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(auth.isLoading)

                Button(action: auth.signUpWithGoogle) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                        Text("Sign up with ") + Text("Google").bold()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.3), lineWidth: 1))

                HStack(spacing: 4) {
                    Text("Already have an account?")
                    Button("Login") { auth.showLogin() }
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
        case .name: focusedField = .email
        case .email: focusedField = .password
        default: auth.signUp()
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
