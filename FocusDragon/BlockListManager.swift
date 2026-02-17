//
//  BlockListManager.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class BlockListManager: ObservableObject {
    @Published var blockedItems: [BlockItem] = []
    @Published var isBlocking: Bool = false

    func addDomain(_ domain: String) {
        // Clean the domain using the cleanDomain extension
        let cleaned = domain.cleanDomain

        // Validate domain format
        guard cleaned.isValidDomain else {
            print("Invalid domain format: \(domain)")
            return
        }

        // Check if already exists
        guard !blockedItems.contains(where: { $0.domain == cleaned }) else {
            print("Domain already exists: \(cleaned)")
            return
        }

        let item = BlockItem(domain: cleaned)
        blockedItems.append(item)
    }

    func removeDomain(at offsets: IndexSet) {
        blockedItems.remove(atOffsets: offsets)
    }

    func toggleDomain(id: UUID) {
        if let index = blockedItems.firstIndex(where: { $0.id == id }) {
            blockedItems[index].isEnabled.toggle()
        }
    }
}
