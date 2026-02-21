import SwiftUI

// MARK: - Dark Mode Support

extension View {
    func adaptiveForeground() -> some View {
        self.foregroundColor(Color.primary)
    }

    func adaptiveBackground() -> some View {
        self.background(Color(.controlBackgroundColor))
    }
}

// MARK: - Smooth Transitions

extension View {
    func smoothTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}
