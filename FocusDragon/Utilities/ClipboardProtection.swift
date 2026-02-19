import AppKit

class ClipboardProtection {
    static let shared = ClipboardProtection()

    private var protectedStrings: Set<String> = []
    private var monitoring = false
    private var timer: Timer?

    func protect(_ text: String) {
        protectedStrings.insert(text)

        if !monitoring {
            startMonitoring()
        }
    }

    func unprotect(_ text: String) {
        protectedStrings.remove(text)

        if protectedStrings.isEmpty {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        monitoring = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        monitoring = false
    }

    private func checkClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            return
        }

        // Check if clipboard contains protected text
        for protected in protectedStrings {
            if clipboardString.contains(protected) {
                // Clear clipboard
                NSPasteboard.general.clearContents()
                print("ClipboardProtection: Cleared protected text from clipboard")

                // Show notification
                NotificationHelper.shared.showClipboardCleared()
            }
        }
    }

    func clear() {
        protectedStrings.removeAll()
        stopMonitoring()
    }
}
