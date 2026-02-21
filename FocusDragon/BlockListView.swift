//
//  BlockListView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI
import AppKit

struct BlockListView: View {
    @ObservedObject var manager: BlockListManager
    @Environment(\.colorScheme) private var scheme
    @State private var selectedTab = 0
    @State private var newDomain = ""
    @State private var showingAppPicker = false
    @State private var showingPresets = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block List")
                        .font(AppTheme.headerFont(16))
                    Text("Websites and apps to lock down during a focus session.")
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("Type", selection: $selectedTab) {
                    Text("Websites").tag(0)
                    Text("Applications").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button {
                    showingPresets = true
                } label: {
                    Label("Presets", systemImage: "sparkles")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if selectedTab == 0 {
                websitesView
            } else {
                applicationsView
            }
        }
        .sheet(isPresented: $showingPresets) {
            PresetsView(manager: manager)
        }
    }

    private var websitesView: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Enter domain (e.g., youtube.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    guard !newDomain.isEmpty else { return }
                    manager.addDomain(newDomain)
                    newDomain = ""
                }
                .buttonStyle(PrimaryGlowButtonStyle())
            }

            List {
                ForEach(manager.getWebsites()) { item in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(AppTheme.electricBlue)
                        Text(item.displayName)
                        Spacer()
                        Toggle("", isOn: binding(for: item))
                            .labelsHidden()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    deleteItems(at: offsets, from: manager.getWebsites())
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var applicationsView: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: selectApplication) {
                    Label("Add Application", systemImage: "plus.app")
                }
                .buttonStyle(PrimaryGlowButtonStyle())

                Spacer()

                Button(action: showAppBrowser) {
                    Label("Browse Apps", systemImage: "list.bullet")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            List {
                ForEach(manager.getApplications()) { item in
                    HStack {
                        if let iconPath = item.appIconPath,
                           let image = NSImage(contentsOfFile: iconPath) {
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: 28, height: 28)
                                .cornerRadius(6)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 28, height: 28)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(AppTheme.bodyFont(13))
                            if let bundleId = item.bundleIdentifier {
                                Text(bundleId)
                                    .font(AppTheme.bodyFont(11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Toggle("", isOn: binding(for: item))
                            .labelsHidden()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    deleteItems(at: offsets, from: manager.getApplications())
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .sheet(isPresented: $showingAppPicker) {
            AppBrowserView(manager: manager, isPresented: $showingAppPicker)
        }
    }

    private func binding(for item: BlockItem) -> Binding<Bool> {
        Binding(
            get: { item.isEnabled },
            set: { _ in manager.toggleDomain(id: item.id) }
        )
    }

    private func deleteItems(at offsets: IndexSet, from items: [BlockItem]) {
        let idsToDelete = offsets.map { items[$0].id }
        manager.blockedItems.removeAll { idsToDelete.contains($0.id) }
    }

    private func selectApplication() {
        AppSelector.shared.selectApplication { item in
            guard let item = item else { return }
            manager.addApplication(item)
        }
    }

    private func showAppBrowser() {
        showingAppPicker = true
    }
}

#Preview {
    BlockListView(manager: BlockListManager())
}
