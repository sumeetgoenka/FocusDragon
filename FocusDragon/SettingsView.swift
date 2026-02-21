//
//  SettingsView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI
import SafariServices
import AppKit

// MARK: - Main Tabbed Settings

struct SettingsView: View {
    @ObservedObject var manager: BlockListManager

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gear") }

            BlockingSettings(manager: manager)
                .tabItem { Label("Blocking", systemImage: "shield") }

            NotificationSettings()
                .tabItem { Label("Notifications", systemImage: "bell") }

            AdvancedSettings(manager: manager)
                .tabItem { Label("Advanced", systemImage: "wrench") }
        }
        .frame(minWidth: 580, minHeight: 500)
    }
}

// MARK: - General Settings

struct GeneralSettings: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("menuBarMode") private var menuBarMode = false
    @AppStorage("appearance") private var appearance = "auto"

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show in menu bar", isOn: $menuBarMode)
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("Auto").tag("auto")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Service Status", value: DaemonInstaller.shared.status.displayName)
            }
        }
        .formStyle(.grouped)
        .onChange(of: appearance) { _, newValue in
            applyAppearance(newValue)
        }
    }

    private func applyAppearance(_ mode: String) {
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // system default
        }
    }
}

// MARK: - Blocking Settings

struct BlockingSettings: View {
    @ObservedObject var manager: BlockListManager
    @State private var showSetup = false
    @State private var showExceptions = false
    @State private var newWhitelistDomain = ""

    private let installer = DaemonInstaller.shared

    var body: some View {
        Form {
            Section("Background Service") {
                DaemonStatusView()

                if !installer.isDaemonInstalled {
                    Button("Set Up Permissions") {
                        showSetup = true
                    }
                }
            }

            Section("Lock & Protection") {
                SettingsProtectionView()
            }

            Section("Browser Extensions") {
                Text("Browser extensions are required for blocking. Install and keep them enabled for any browsers you use.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Extension Status") {
                ExtensionInstallView()
            }

            Section("Exceptions") {
                Button("Manage URL & App Exceptions") {
                    showExceptions = true
                }

                Text("URL exceptions allow specific paths on blocked domains. These domains are removed from hosts-file blocking and rely on the browser extension.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Block all internet except whitelist", isOn: Binding(
                    get: { manager.internetBlockConfig.isEnabled },
                    set: { value in updateInternetConfig { $0.isEnabled = value } }
                ))
                .help("Uses PF to block all outbound traffic except whitelisted domains.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Whitelisted Domains")
                        .font(.subheadline)
                    HStack {
                        TextField("example.com", text: $newWhitelistDomain)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            addWhitelistDomain()
                        }
                        .disabled(newWhitelistDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    ForEach(manager.internetBlockConfig.whitelistDomains, id: \.self) { domain in
                        HStack {
                            Text(domain)
                            Spacer()
                            Button(role: .destructive) {
                                removeWhitelistDomain(domain)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .controlSize(.small)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Whitelisted Apps (optional)")
                        .font(.subheadline)
                    Button("Add Allowed App") {
                        AppSelector.shared.selectApplication { item in
                            guard let item, let bundleId = item.bundleIdentifier else { return }
                            addWhitelistApp(bundleId: bundleId)
                        }
                    }

                    ForEach(manager.internetBlockConfig.whitelistApps, id: \.self) { bundleId in
                        HStack {
                            Text(appName(for: bundleId))
                            Spacer()
                            Button(role: .destructive) {
                                removeWhitelistApp(bundleId)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text("Internet Blocking")
            } footer: {
                Text("Internet blocking uses PF at the system level. Whitelisted apps are enforced by allowing only those apps to run while internet blocking is active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showSetup) {
            DaemonSetupView()
        }
        .sheet(isPresented: $showExceptions) {
            ExceptionsView(manager: manager)
        }
    }

    private func updateInternetConfig(_ block: (inout InternetBlockConfig) -> Void) {
        var config = manager.internetBlockConfig
        block(&config)
        manager.internetBlockConfig = config
    }

    private func addWhitelistDomain() {
        let trimmed = newWhitelistDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        updateInternetConfig { config in
            if !config.whitelistDomains.contains(trimmed) {
                config.whitelistDomains.append(trimmed)
            }
        }

        newWhitelistDomain = ""
    }

    private func removeWhitelistDomain(_ domain: String) {
        updateInternetConfig { config in
            config.whitelistDomains.removeAll { $0 == domain }
        }
    }

    private func addWhitelistApp(bundleId: String) {
        updateInternetConfig { config in
            if !config.whitelistApps.contains(bundleId) {
                config.whitelistApps.append(bundleId)
            }
        }
    }

    private func removeWhitelistApp(_ bundleId: String) {
        updateInternetConfig { config in
            config.whitelistApps.removeAll { $0 == bundleId }
        }
    }

    private func appName(for bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleId
    }
}

// MARK: - Notification Settings

struct NotificationSettings: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableSounds") private var enableSounds = true

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable notifications", isOn: $enableNotifications)
                Toggle("Enable sounds", isOn: $enableSounds)
            }

            Section {
                Button("Open System Notification Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } footer: {
                Text("Manage notification permissions in System Settings.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettings: View {
    @ObservedObject var manager: BlockListManager
    @State private var showUninstallAlert = false
    @State private var uninstallError: String?
    @State private var showUninstallError = false
    @State private var showPasswordRequired = false

    private let installer = DaemonInstaller.shared

    var body: some View {
        Form {
            Section("System Permissions") {
                Button(action: { installer.openFullDiskAccessSettings() }) {
                    HStack {
                        Label("Full Disk Access", systemImage: "lock.doc")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button(action: { installer.openLoginItemsSettings() }) {
                    HStack {
                        Label("Login Items", systemImage: "gearshape.arrow.triangle.2.circlepath")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

                Section("Install Browser Extensions") {
                    Button(action: installChromeExtension) {
                        extensionRow("Install Chrome Extension")
                    }
                    .buttonStyle(.plain)

                    Button(action: { openChromiumExtensions(appName: "Microsoft Edge") }) {
                        extensionRow("Install Edge Extension")
                    }
                    .buttonStyle(.plain)

                    Button(action: { openChromiumExtensions(appName: "Brave Browser") }) {
                        extensionRow("Install Brave Extension")
                    }
                    .buttonStyle(.plain)

                    Button(action: { openChromiumExtensions(appName: "Vivaldi") }) {
                        extensionRow("Install Vivaldi Extension")
                    }
                    .buttonStyle(.plain)

                    Button(action: { openChromiumExtensions(appName: "Opera") }) {
                        extensionRow("Install Opera Extension")
                    }
                    .buttonStyle(.plain)

                    Button(action: { openChromiumExtensions(appName: "Comet") }) {
                        extensionRow("Install Comet Extension")
                    }
                    .buttonStyle(.plain)
                }

                Section("Safari Extension") {
                    Button(action: openSafariExtensionPreferences) {
                        extensionRow("Open Safari Extension Settings", icon: "safari")
                    }
                    .buttonStyle(.plain)

                    Text("Enable: Safari → Settings → Extensions → FocusDragon → Enable. Also turn on \"Allow in Private Browsing\".")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Danger Zone") {
                    if installer.isDaemonInstalled {
                        Button("Unregister Service", role: .destructive) {
                            if SettingsProtection.shared.shouldPreventUninstall() {
                                showPasswordRequired = true
                            } else {
                                showUninstallAlert = true
                            }
                        }
                    }
                }
        }
        .formStyle(.grouped)
        .alert("Unregister Service", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unregister", role: .destructive) {
                unregisterDaemon()
            }
        } message: {
            Text("This will stop the background service. Blocking will only work while the app is open.")
        }
        .alert("Error", isPresented: $showUninstallError) {
            Button("OK") { }
        } message: {
            Text(uninstallError ?? "Unknown error")
        }
        .alert("Uninstall Prevented", isPresented: $showPasswordRequired) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A lock is active or settings protection is enabled. You must authenticate in Lock & Protection settings before unregistering the service.")
        }
    }

    // MARK: - Helpers

    private func extensionRow(_ title: String, icon: String = "puzzlepiece.extension") -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Image(systemName: "arrow.up.forward.square")
                .foregroundColor(.secondary)
        }
    }

    private func unregisterDaemon() {
        do {
            try installer.unregister()
        } catch {
            uninstallError = error.localizedDescription
            showUninstallError = true
        }
    }

    private func installChromeExtension() {
        let extensionsURL = URL(string: "https://chrome.google.com/webstore")!

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Google Chrome", "chrome://extensions/"]

        do {
            try task.run()
        } catch {
            NSWorkspace.shared.open(extensionsURL)
        }
    }

    private func openChromiumExtensions(appName: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appName, "chrome://extensions/"]
        try? task.run()
    }

    private func openSafariExtensionPreferences() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: SharedConstants.safariExtensionIdentifier
        ) { error in
            if let error = error {
                uninstallError = error.localizedDescription
                showUninstallError = true
            }
        }
    }
}

#Preview {
    SettingsView(manager: BlockListManager())
}
