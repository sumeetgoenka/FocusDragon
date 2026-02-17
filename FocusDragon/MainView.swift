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

    var body: some View {
        VStack(spacing: 20) {
            Text("FocusDragon")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Add domain section
            HStack {
                TextField("Enter domain (e.g., youtube.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addDomain()
                    }

                Button("Add") {
                    addDomain()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

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

            // Control buttons
            HStack(spacing: 20) {
                Button(manager.isBlocking ? "Stop Block" : "Start Block") {
                    toggleBlocking()
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isBlocking ? .red : .green)
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
    }

    private func addDomain() {
        guard !newDomain.isEmpty else { return }
        manager.addDomain(newDomain)
        newDomain = ""
    }

    private func binding(for item: BlockItem) -> Binding<Bool> {
        Binding(
            get: { item.isEnabled },
            set: { _ in manager.toggleDomain(id: item.id) }
        )
    }

    private func toggleBlocking() {
        if manager.isBlocking {
            // Stop blocking
            do {
                try HostsFileManager.shared.removeBlock()
                manager.isBlocking = false
            } catch {
                showError(error)
            }
        } else {
            // Start blocking
            let domains = manager.blockedItems
                .filter { $0.isEnabled }
                .map { $0.domain }

            guard !domains.isEmpty else {
                showError(NSError(
                    domain: "FocusDragon",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Please add at least one domain to block"]
                ))
                return
            }

            do {
                // Request admin first
                guard HostsFileManager.shared.requestAdminPrivileges() else {
                    showError(NSError(
                        domain: "FocusDragon",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Admin privileges required"]
                    ))
                    return
                }

                try HostsFileManager.shared.applyBlock(domains: domains)
                manager.isBlocking = true
            } catch {
                showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        alertMessage = error.localizedDescription
        showingAlert = true
    }
}

#Preview {
    MainView()
}
