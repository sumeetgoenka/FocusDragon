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
        ZStack {
            AppBackground()

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Applications")
                            .font(AppTheme.headerFont(16))
                        Text("Pick apps to block during focus sessions.")
                            .font(AppTheme.bodyFont(12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding()

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
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(6)
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 28, height: 28)
                            }

                            VStack(alignment: .leading) {
                                Text(app.displayName)
                                    .font(AppTheme.bodyFont(12))
                                if let bundleId = app.bundleIdentifier {
                                    Text(bundleId)
                                        .font(AppTheme.bodyFont(10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if isAppBlocked(app) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.accent)
                            } else {
                                Button("Add") {
                                    manager.addApplication(app)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .frame(width: 620, height: 520)
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
