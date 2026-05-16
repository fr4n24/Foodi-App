import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var goToSignUp = false
    @State private var forgotMode: ForgotView.Mode? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 60)

                        // Logo + branding
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.gymLinkPink.opacity(0.18))
                                    .frame(width: 78, height: 78)
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.gymLinkPink)
                            }
                            Text("GymLink")
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(.white)
                            Text("Your fitness community")
                                .font(.subheadline)
                                .foregroundColor(Color(white: 0.45))
                        }

                        Spacer().frame(height: 44)

                        // Fields
                        VStack(spacing: 12) {
                            AuthField(icon: "envelope.fill", placeholder: "Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)

                            // Password field
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.gymLinkPink)
                                    .frame(width: 22)
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .textContentType(.password)
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(Color(white: 0.38))
                                        .font(.system(size: 15))
                                }
                            }
                            .padding(14)
                            .background(Color(white: 0.11))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)

                        Spacer().frame(height: 20)

                        // Error message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 8)
                        }

                        // Sign In button
                        Button(action: signIn) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(canSignIn ? Color.gymLinkPink : Color(white: 0.18))
                                    .frame(height: 54)
                                    .shadow(color: canSignIn ? Color.gymLinkPink.opacity(0.45) : .clear,
                                            radius: 12, x: 0, y: 4)
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundColor(canSignIn ? .white : Color(white: 0.38))
                                }
                            }
                        }
                        .disabled(!canSignIn || isLoading)
                        .padding(.horizontal, 24)
                        .animation(.easeInOut(duration: 0.2), value: canSignIn)

                        Spacer().frame(height: 16)

                        // Recovery links
                        HStack(spacing: 24) {
                            Button("Forgot password?") { forgotMode = .password }
                                .font(.footnote).foregroundColor(.gymLinkPink)
                            Button("Forgot username?") { forgotMode = .username }
                                .font(.footnote).foregroundColor(.gymLinkPink)
                        }

                        Spacer().frame(height: 48)

                        // Divider
                        HStack(spacing: 12) {
                            Rectangle().fill(Color(white: 0.18)).frame(height: 1)
                            Text("or").font(.footnote).foregroundColor(Color(white: 0.35))
                            Rectangle().fill(Color(white: 0.18)).frame(height: 1)
                        }
                        .padding(.horizontal, 24)

                        Spacer().frame(height: 24)

                        // Create account
                        VStack(spacing: 10) {
                            Text("New to GymLink?")
                                .font(.subheadline)
                                .foregroundColor(Color(white: 0.45))

                            Button {
                                goToSignUp = true
                            } label: {
                                Text("Create an Account")
                                    .font(.headline)
                                    .foregroundColor(.gymLinkPink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.gymLinkPink.opacity(0.12))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.gymLinkPink.opacity(0.4), lineWidth: 1.5)
                                    )
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer().frame(height: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .preferredColorScheme(.dark)
            .navigationDestination(isPresented: $goToSignUp) {
                SignUpView()
            }
            .navigationDestination(item: $forgotMode) { mode in
                ForgotView(mode: mode)
            }
        }
    }

    private var canSignIn: Bool { !email.isEmpty && !password.isEmpty }

    private func signIn() {
        guard canSignIn else { return }
        isLoading = true
        errorMessage = ""
        AuthManager.shared.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                   password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success: break
                case .failure(let err): errorMessage = friendlyError(err)
                }
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17009: return "Incorrect password. Please try again."
        case 17011: return "No account found with this email."
        case 17008: return "Please enter a valid email address."
        case 17020: return "Network error. Check your connection."
        default:    return "Sign in failed. Please try again."
        }
    }
}

// MARK: - Reusable auth input field
struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gymLinkPink)
                .frame(width: 22)
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(14)
        .background(Color(white: 0.11))
        .cornerRadius(14)
    }
}
