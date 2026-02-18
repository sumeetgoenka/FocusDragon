//
//  AppBrowserView.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import SwiftUI
import AppKit

struct AppBrowserView: View {
    @ObservedObject var manager: BlockListManager
    @Binding var isPresented: Bool
    @State private var apps: [BlockItem] = []
    @State private var searchText = ""
    @State private var isLoading = true

    var filteredApps: [BlockItem] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            HStack {
                Text("Select Applications to Block")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
            }
            .padding()

            // Search bar
            TextField("Search applications...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if isLoading {
                ProgressView("Loading applications...")
                    .padding()
            } else {
                List(filteredApps) { app in
                    HStack {
                        if let iconPath = app.appIconPath,
                           let image = NSImage(contentsOfFile: iconPath) {
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 32, height: 32)
                        }

                        VStack(alignment: .leading) {
                            Text(app.displayName)
                            if let bundleId = app.bundleIdentifier {
                                Text(bundleId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if isAppBlocked(app) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Add") {
                                manager.addApplication(app)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadApplications()
        }
    }

    private func loadApplications() {
        Task {
            let installedApps = await Task.detached {
                await AppSelector.shared.getInstalledApplications()
            }.value

            await MainActor.run {
                apps = installedApps
                isLoading = false
            }
        }
    }

    private func isAppBlocked(_ app: BlockItem) -> Bool {
        manager.blockedItems.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }
}
