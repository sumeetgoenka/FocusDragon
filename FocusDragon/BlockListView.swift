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
    @State private var selectedTab = 0
    @State private var newDomain = ""
    @State private var showingAppPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Type", selection: $selectedTab) {
                Text("Websites").tag(0)
                Text("Applications").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                websitesView
            } else {
                applicationsView
            }
        }
    }

    private var websitesView: some View {
        VStack {
            // Add website input
            HStack {
                TextField("Enter domain (e.g., youtube.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    guard !newDomain.isEmpty else { return }
                    manager.addDomain(newDomain)
                    newDomain = ""
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            // Websites list
            List {
                ForEach(manager.getWebsites()) { item in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text(item.displayName)
                        Spacer()
                        Toggle("", isOn: binding(for: item))
                    }
                }
                .onDelete { offsets in
                    deleteItems(at: offsets, from: manager.getWebsites())
                }
            }
        }
    }

    private var applicationsView: some View {
        VStack {
            // Add application button
            HStack {
                Button(action: selectApplication) {
                    Label("Add Application", systemImage: "plus.app")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button(action: showAppBrowser) {
                    Label("Browse Apps", systemImage: "list.bullet")
                }
            }
            .padding(.horizontal)

            // Applications list
            List {
                ForEach(manager.getApplications()) { item in
                    HStack {
                        // App icon
                        if let iconPath = item.appIconPath,
                           let image = NSImage(contentsOfFile: iconPath) {
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading) {
                            Text(item.displayName)
                                .font(.body)
                            if let bundleId = item.bundleIdentifier {
                                Text(bundleId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Toggle("", isOn: binding(for: item))
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    deleteItems(at: offsets, from: manager.getApplications())
                }
            }
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
