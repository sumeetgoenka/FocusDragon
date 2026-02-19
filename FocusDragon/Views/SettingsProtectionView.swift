import SwiftUI

struct SettingsProtectionView: View {
    @StateObject private var protection = SettingsProtection.shared

    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingRemoveConfirm: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            if protection.isPasswordProtected {
                if protection.isAuthenticated {
                    authenticatedView
                } else {
                    loginView
                }
            } else {
                setupView
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Remove Password?", isPresented: $showingRemoveConfirm) {
            Button("Remove", role: .destructive) {
                protection.removePassword()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Settings will no longer require a password to access.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 5) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Settings Protection")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Password-protect your FocusDragon settings")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Setup (no password set yet)

    private var setupView: some View {
        VStack(spacing: 15) {
            Text("Set a password to prevent unauthorized changes to your blocking settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SecureField("New Password", text: $password)
                .textFieldStyle(.roundedBorder)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

            Button("Set Password") {
                setNewPassword()
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty || confirmPassword.isEmpty)
        }
        .frame(maxWidth: 300)
    }

    // MARK: - Login (password set, not authenticated)

    private var loginView: some View {
        VStack(spacing: 15) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)

            Text("Settings are locked")
                .font(.headline)

            Text("Enter your password to access settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit { authenticate() }

            Button("Unlock") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty)
        }
        .frame(maxWidth: 300)
    }

    // MARK: - Authenticated (settings unlocked)

    private var authenticatedView: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                Text("Settings Protected")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            Text("Your settings are password-protected.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 15) {
                Button("Lock Now") {
                    protection.lockSettings()
                    password = ""
                }
                .buttonStyle(.bordered)

                Button("Remove Password") {
                    showingRemoveConfirm = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }

            if protection.shouldPreventUninstall() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Uninstall blocked while a lock is active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 5)
            }
        }
    }

    // MARK: - Actions

    private func setNewPassword() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showError = true
            return
        }

        guard password.count >= 4 else {
            errorMessage = "Password must be at least 4 characters"
            showError = true
            return
        }

        if protection.setPassword(password) {
            password = ""
            confirmPassword = ""
        } else {
            errorMessage = "Failed to save password"
            showError = true
        }
    }

    private func authenticate() {
        if !protection.authenticate(password) {
            errorMessage = "Incorrect password"
            showError = true
            password = ""
        }
    }
}
