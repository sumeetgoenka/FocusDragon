import SwiftUI
import SafariServices

@main
struct FocusDragonSafariExtensionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SafariExtensionContainerView()
                .frame(minWidth: 420, minHeight: 320)
        }
    }
}

private struct SafariExtensionContainerView: View {
    private let extensionIdentifier = "com.anaygoenka.FocusDragon.FocusDragonSafariExtension"

    @State private var isEnabled: Bool?
    @State private var supportsSettings = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FocusDragon Safari Extension")
                .font(.title2)
                .fontWeight(.semibold)

            Text(statusText)
                .foregroundColor(.secondary)

            Text("Safari shows a standard warning that extensions can read and modify websites. This is expected and safe for FocusDragon.")
                .font(.callout)
                .foregroundColor(.secondary)

            Button("Open Safari Extension Settings") {
                openPreferences()
            }
            .buttonStyle(.borderedProminent)

            Text("Enable: Safari -> Settings -> Extensions -> FocusDragon -> Enable. Also turn on \"Allow in Private Browsing\".")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
        .onAppear {
            refreshState()
        }
    }

    private var statusText: String {
        guard let enabled = isEnabled else {
            return "Checking extension status..."
        }
        return enabled ? "Extension is enabled" : "Extension is disabled"
    }

    private func refreshState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionIdentifier) { state, error in
            DispatchQueue.main.async {
                if let error = error {
                    supportsSettings = false
                    isEnabled = nil
                    print("Failed to read Safari extension state: \(error.localizedDescription)")
                    return
                }
                isEnabled = state?.isEnabled
            }
        }
    }

    private func openPreferences() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionIdentifier) { _ in }
    }
}
