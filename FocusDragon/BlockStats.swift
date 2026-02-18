//
//  BlockStats.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import Foundation

struct BlockStats: Codable {
    var totalAppsBlocked: Int = 0
    var totalWebsitesBlocked: Int = 0
    var blockingSessions: Int = 0
    var lastBlockDate: Date?

    mutating func incrementAppBlocks() {
        totalAppsBlocked += 1
    }

    mutating func incrementWebsiteBlocks() {
        totalWebsitesBlocked += 1
    }

    mutating func startSession() {
        blockingSessions += 1
        lastBlockDate = Date()
    }
}
