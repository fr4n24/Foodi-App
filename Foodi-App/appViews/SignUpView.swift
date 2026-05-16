import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirm = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Header
                    VStack(spacing: 6) {
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Join the GymLink community")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 32)

                    // Fields
                    VStack(spacing: 12) {
                        AuthField(icon: "person.fill", placeholder: "Full Name", text: $fullName)
                            .textContentType(.name)

                        AuthField(icon: "at", placeholder: "Username", text: $username)
                            .textContentType(.username)

                        AuthField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)

                        // Password
                        passwordField(placeholder: "Password",
                                      text: $password,
                                      show: $showPassword,
                                      contentType: .newPassword)

                        // Confirm password
                        passwordField(placeholder: "Confirm Password",
                                      text: $confirmPassword,
                                      show: $showConfirm,
                                      contentType: .newPassword)

                        // Password match hint
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 16)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }

                    // Create account button
                    Button(action: createAccount) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canCreate ? Color.gymLinkPink : Color(white: 0.18))
                                .frame(height: 54)
                                .shadow(color: canCreate ? Color.gymLinkPink.opacity(0.45) : .clear,
                                        radius: 12, x: 0, y: 4)
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Account")
                                    .font(.headline)
                                    .foregroundColor(canCreate ? .white : Color(white: 0.38))
                            }
                        }
                    }
                    .disabled(!canCreate || isLoading)
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.2), value: canCreate)

                    Spacer().frame(height: 24)

                    Button("Already have an account? Sign in") {
                        dismiss()
                    }
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.45))

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Sign In")
                    }
                    .foregroundColor(.gymLinkPink)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Password input helper
    private func passwordField(placeholder: String,
                               text: Binding<String>,
                               show: Binding<Bool>,
                               contentType: UITextContentType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gymLinkPink)
                .frame(width: 22)
            Group {
                if show.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .foregroundColor(.white)
            .autocapitalization(.none)
            .textContentType(contentType)
            Button {
                show.wrappedValue.toggle()
            } label: {
                Image(systemName: show.wrappedValue ? "eye.slash" : "eye")
                    .foregroundColor(Color(white: 0.38))
                    .font(.system(size: 15))
            }
        }
        .padding(14)
        .background(Color(white: 0.11))
        .cornerRadius(14)
    }

    private var canCreate: Bool {
        !fullName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func createAccount() {
        guard canCreate else { return }
        isLoading = true
        errorMessage = ""

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        AuthManager.shared.signUp(
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            username: trimmedUsername,
            email: trimmedEmail,
            password: password
        ) { result in
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
        case 17007: return "This email is already registered."
        case 17026: return "Password must be at least 6 characters."
        case 17008: return "Please enter a valid email address."
        case 17020: return "Network error. Check your connection."
        default:    return "Sign up failed. Please try again."
        }
    }
}
