//
//  MainView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI

struct MainView: View {
    @StateObject private var manager = BlockListManager()
    @State private var newDomain: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var domainValidationError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("FocusDragon")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Add domain section
            VStack(spacing: 8) {
                HStack {
                    TextField("Enter domain (e.g., youtube.com)", text: $newDomain)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: newDomain) { _ in
                            domainValidationError = nil
                        }
                        .onSubmit {
                            addDomain()
                        }

                    Button("Add") {
                        addDomain()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newDomain.isEmpty)
                }
                .padding(.horizontal)

                if let error = domainValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }

            // Block list
            List {
                ForEach(manager.blockedItems) { item in
                    HStack {
                        Text(item.domain)
                        Spacer()
                        Toggle("", isOn: binding(for: item))
                    }
                }
                .onDelete(perform: manager.removeDomain)
            }
            .frame(minHeight: 200)

            // Status indicator
            HStack {
                Circle()
                    .fill(manager.isBlocking ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                Text(manager.isBlocking ? "Blocking Active" : "Not Blocking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Control buttons
            HStack(spacing: 20) {
                Button(manager.isBlocking ? "Stop Block" : "Start Block") {
                    toggleBlocking()
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isBlocking ? .red : .green)
                .disabled(isProcessing || manager.blockedItems.isEmpty)

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            verifyBlockingState()
        }
    }

    private func addDomain() {
        let cleaned = newDomain.cleanDomain

        guard !cleaned.isEmpty else { return }

        guard cleaned.isValidDomain else {
            domainValidationError = "Invalid domain format. Use: example.com"
            return
        }

        if manager.blockedItems.contains(where: { $0.domain == cleaned }) {
            domainValidationError = "Domain already in block list"
            return
        }

        manager.addDomain(cleaned)
        newDomain = ""
        domainValidationError = nil
    }

    private func binding(for item: BlockItem) -> Binding<Bool> {
        Binding(
            get: { item.isEnabled },
            set: { _ in manager.toggleDomain(id: item.id) }
        )
    }

    private func toggleBlocking() {
        isProcessing = true

        Task {
            do {
                if manager.isBlocking {
                    try await stopBlocking()
                } else {
                    try await startBlocking()
                }
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }

            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func startBlocking() async throws {
        let enabledDomains = manager.blockedItems
            .filter { $0.isEnabled }
            .map { $0.domain }

        guard !enabledDomains.isEmpty else {
            throw BlockError.noDomains
        }

        // Request admin privileges
        let hasPrivileges = await requestPrivileges()
        guard hasPrivileges else {
            throw BlockError.privilegesDenied
        }

        // Apply block
        try HostsFileManager.shared.applyBlock(domains: enabledDomains)

        await MainActor.run {
            manager.isBlocking = true
        }
    }

    private func stopBlocking() async throws {
        try HostsFileManager.shared.removeBlock()

        await MainActor.run {
            manager.isBlocking = false
        }
    }

    private func requestPrivileges() async -> Bool {
        // Run privilege request on background thread
        return await Task.detached {
            HostsFileManager.shared.requestAdminPrivileges()
        }.value
    }

    private func verifyBlockingState() {
        // Check if hosts file has our markers
        let hostsContent = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)
        let hasMarkers = hostsContent?.contains("#### FocusDragon Block Start ####") ?? false

        if manager.isBlocking && !hasMarkers {
            // Block should be active but isn't - reapply
            Task {
                try? await startBlocking()
            }
        } else if !manager.isBlocking && hasMarkers {
            // Block shouldn't be active but is - remove
            Task {
                try? await stopBlocking()
            }
        }
    }

    private func showError(_ error: Error) {
        alertMessage = error.localizedDescription
        showingAlert = true
    }
}

enum BlockError: LocalizedError {
    case noDomains
    case privilegesDenied

    var errorDescription: String? {
        switch self {
        case .noDomains:
            return "No domains enabled for blocking"
        case .privilegesDenied:
            return "Administrator privileges are required to modify the hosts file"
        }
    }
}

#Preview {
    MainView()
}
