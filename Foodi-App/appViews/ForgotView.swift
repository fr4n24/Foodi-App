import SwiftUI

struct ForgotView: View {
    enum Mode: String, Hashable {
        case password = "password"
        case username = "username"
    }

    @Environment(\.dismiss) private var dismiss

    var mode: Mode

    @State private var selectedMode: Mode
    @State private var emailInput = ""
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @State private var foundUsername = ""

    init(mode: Mode) {
        self.mode = mode
        _selectedMode = State(initialValue: mode)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)

                    // Header
                    VStack(spacing: 6) {
                        Text("Get back in")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("We'll help you recover your account")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 28)

                    // Mode toggle
                    HStack(spacing: 0) {
                        modeTab(label: "Forgot Password", tabMode: .password)
                        modeTab(label: "Forgot Username", tabMode: .username)
                    }
                    .background(Color(white: 0.11))
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .onChange(of: selectedMode) {
                        // Reset state on mode switch
                        emailInput = ""
                        statusMessage = ""
                        isSuccess = false
                        foundUsername = ""
                    }

                    Spacer().frame(height: 28)

                    // Content
                    VStack(spacing: 16) {
                        if selectedMode == .password {
                            passwordContent
                        } else {
                            usernameContent
                        }
                    }
                    .padding(.horizontal, 24)

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

    // MARK: - Mode tab button
    private func modeTab(label: String, tabMode: Mode) -> some View {
        let isSelected = selectedMode == tabMode
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedMode = tabMode
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Color(white: 0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.gymLinkPink : Color.clear)
                .cornerRadius(12)
                .padding(3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Forgot password content
    @ViewBuilder
    private var passwordContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            AuthField(icon: "envelope.fill", placeholder: "Email address", text: $emailInput)
                .keyboardType(.emailAddress)

            if !statusMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isSuccess ? .green : .red)
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundColor(isSuccess ? .green : .red)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )
            }

            Button(action: sendReset) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canSend ? Color.gymLinkPink : Color(white: 0.18))
                        .frame(height: 54)
                        .shadow(color: canSend ? Color.gymLinkPink.opacity(0.45) : .clear,
                                radius: 12, x: 0, y: 4)
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send Reset Link")
                            .font(.headline)
                            .foregroundColor(canSend ? .white : Color(white: 0.38))
                    }
                }
            }
            .disabled(!canSend || isLoading)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
    }

    // MARK: - Forgot username content
    @ViewBuilder
    private var usernameContent: some View {
        VStack(spacing: 12) {
            Text("Enter the email you registered with and we'll look up your username.")
                .font(.subheadline)
                .foregroundColor(Color(white: 0.5))
                .fixedSize(horizontal: false, vertical: true)

            AuthField(icon: "envelope.fill", placeholder: "Email address", text: $emailInput)
                .keyboardType(.emailAddress)

            if !statusMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isSuccess ? .green : .red)
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundColor(isSuccess ? .green : .red)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )
            }

            if !foundUsername.isEmpty {
                VStack(spacing: 4) {
                    Text("Your username is")
                        .font(.footnote)
                        .foregroundColor(Color(white: 0.5))
                    Text("@\(foundUsername)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.gymLinkPink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(white: 0.11))
                .cornerRadius(14)
            }

            Button(action: lookupUsername) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canSend ? Color.gymLinkPink : Color(white: 0.18))
                        .frame(height: 54)
                        .shadow(color: canSend ? Color.gymLinkPink.opacity(0.45) : .clear,
                                radius: 12, x: 0, y: 4)
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Find My Username")
                            .font(.headline)
                            .foregroundColor(canSend ? .white : Color(white: 0.38))
                    }
                }
            }
            .disabled(!canSend || isLoading)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
    }

    private var canSend: Bool { !emailInput.isEmpty && emailInput.contains("@") }

    // MARK: - Actions
    private func sendReset() {
        guard canSend else { return }
        isLoading = true
        statusMessage = ""

        AuthManager.shared.sendPasswordReset(email: emailInput.trimmingCharacters(in: .whitespaces)) { error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    isSuccess = false
                    statusMessage = "Couldn't send reset link: \(error.localizedDescription)"
                } else {
                    isSuccess = true
                    statusMessage = "Reset link sent! Check your inbox."
                }
            }
        }
    }

    private func lookupUsername() {
        guard canSend else { return }
        isLoading = true
        statusMessage = ""
        foundUsername = ""

        AuthManager.shared.lookupUsername(forEmail: emailInput.trimmingCharacters(in: .whitespaces)) { username in
            DispatchQueue.main.async {
                isLoading = false
                if let username = username {
                    isSuccess = true
                    foundUsername = username
                    statusMessage = "We found your account!"
                } else {
                    isSuccess = false
                    statusMessage = "No account found with that email."
                }
            }
        }
    }
}
