//
//  PresetsView.swift
//  FocusDragon
//

import SwiftUI
import UniformTypeIdentifiers

struct PresetsView: View {
    @ObservedObject var manager: BlockListManager
    @Environment(\.dismiss) private var dismiss

    @State private var importError: String?
    @State private var showImportError = false
    @State private var showSuccessBanner = false
    @State private var successMessage = ""

    private let presetsLibrary = PresetsLibrary.shared
    private let importExportManager = ImportExportManager.shared

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Presets & Import")
                            .font(AppTheme.titleFont(20))
                        Text("One-click lists + easy imports.")
                            .font(AppTheme.bodyFont(12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Import / Export", systemImage: "arrow.up.arrow.down")
                                    .font(AppTheme.headerFont(15))

                                HStack(spacing: 12) {
                                    Menu {
                                        Button("Export as JSON") { exportList(format: .json) }
                                        Button("Export as CSV") { exportList(format: .csv) }
                                        Button("Export as Text") { exportList(format: .text) }
                                    } label: {
                                        Label("Export List", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                    .disabled(manager.blockedItems.isEmpty)

                                    Button {
                                        importList()
                                    } label: {
                                        Label("Import from File", systemImage: "square.and.arrow.down")
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }

                                Text("Export your current block list as JSON, CSV, or text. Imports merge into your current list (Cold Turkey/Freedom compatible).")
                                    .font(AppTheme.bodyFont(11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Preset Block Lists")
                                    .font(AppTheme.headerFont(16))
                                Text("Tap a preset to add its domains to your block list.")
                                    .font(AppTheme.bodyFont(12))
                                    .foregroundColor(.secondary)
                            }

                            ForEach(presetsLibrary.presets) { preset in
                                PresetRowView(preset: preset) {
                                    applyPreset(preset)
                                }
                            }
                        }
                    }
                    .padding()
                }

                if showSuccessBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successMessage)
                            .font(AppTheme.bodyFont(12))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.12))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: BlockListPreset) {
        var added = 0
        for domain in preset.domains {
            let before = manager.blockedItems.count
            manager.addDomain(domain)
            if manager.blockedItems.count > before { added += 1 }
        }

        if !preset.apps.isEmpty {
            let installed = AppSelector.shared.getInstalledApplications()
            for appName in preset.apps {
                if let match = installed.first(where: { $0.displayName.lowercased() == appName.lowercased() }) {
                    let before = manager.blockedItems.count
                    manager.addApplication(match)
                    if manager.blockedItems.count > before { added += 1 }
                }
            }
        }
        let msg = added == 0
            ? "All domains from \"\(preset.name)\" already in list"
            : "\(added) domain\(added == 1 ? "" : "s") added from \"\(preset.name)\""
        showSuccess(msg)
    }

    private enum ExportFormat {
        case json
        case csv
        case text
    }

    private func exportList(format: ExportFormat) {
        let url: URL?
        switch format {
        case .json:
            url = importExportManager.exportCurrentList(from: manager, name: nil)
        case .csv:
            url = importExportManager.exportCurrentListCSV(from: manager, name: nil)
        case .text:
            url = importExportManager.exportDomainsPlainText(from: manager, name: nil)
        }

        guard let url else { return }

        let type: UTType
        switch format {
        case .json: type = .json
        case .csv: type = .commaSeparatedText
        case .text: type = .plainText
        }

        importExportManager.showSavePanel(for: url, contentType: type)
    }

    private func importList() {
        importExportManager.showOpenPanel { url in
            guard let url else { return }
            do {
                try importExportManager.importList(from: url, into: manager)
                showSuccess("Block list imported successfully")
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

    private func showSuccess(_ message: String) {
        successMessage = message
        withAnimation { showSuccessBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showSuccessBanner = false }
        }
    }
}

// MARK: - Preset Row

struct PresetRowView: View {
    let preset: BlockListPreset
    let onApply: () -> Void

    var body: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(preset.name)
                            .font(AppTheme.headerFont(14))
                        AppBadge(text: preset.category, color: AppTheme.accent)
                    }

                    Text(preset.description)
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)

                    let appSuffix = preset.apps.isEmpty ? "" : " + \(preset.apps.count) app\(preset.apps.count == 1 ? "" : "s")"
                    Text("\(preset.domains.count) domain\(preset.domains.count == 1 ? "" : "s")\(appSuffix)")
                        .font(AppTheme.bodyFont(10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Add") { onApply() }
                    .buttonStyle(PrimaryGlowButtonStyle())
                    .controlSize(.small)
            }
        }
    }
}

#Preview {
    PresetsView(manager: BlockListManager())
}
