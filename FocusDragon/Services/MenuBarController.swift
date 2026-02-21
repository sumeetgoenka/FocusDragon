import AppKit
import SwiftUI
import Combine

class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private weak var manager: BlockListManager?
    private var cancellable: AnyCancellable?

    func install(manager: BlockListManager) {
        self.manager = manager

        if statusItem != nil {
            updateIcon()
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "FocusDragon")
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        // Observe blocking state to keep icon in sync
        cancellable = manager.$isBlocking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }

        updateIcon()
    }

    func uninstall() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        cancellable?.cancel()
        cancellable = nil
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        let isBlocking = manager?.isBlocking ?? false

        button.image = NSImage(
            systemSymbolName: isBlocking ? "shield.fill" : "shield",
            accessibilityDescription: "FocusDragon"
        )
    }

    @objc private func statusItemClicked() {
        showMenu()
    }

    private func showMenu() {
        let menu = NSMenu()

        let isBlocking = manager?.isBlocking ?? false

        let statusMenuItem = NSMenuItem(
            title: isBlocking ? "✅ Blocking Active" : "⏸ Inactive",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: isBlocking ? "Stop Blocking" : "Start Blocking",
            action: #selector(toggleBlocking),
            keyEquivalent: "b"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Reset so clicks trigger action next time
    }

    @objc private func toggleBlocking() {
        guard let manager = manager else { return }
        if manager.isBlocking {
            manager.isBlocking.toggle()
            updateIcon()
            return
        }

        Task {
            let ready = await ExtensionRequirementChecker.extensionsReadyForBlocking()
            if !ready {
                await MainActor.run {
                    NotificationCenter.default.post(name: .extensionSetupRequested, object: nil)
                    showWindow()
                }
                return
            }

            await MainActor.run {
                manager.isBlocking.toggle()
                updateIcon()
            }
        }
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
