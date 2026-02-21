//
//  Presets.swift
//  FocusDragon
//

import Foundation

struct BlockListPreset: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let domains: [String]
    let apps: [String]
    let description: String

    init(name: String, category: String, domains: [String], apps: [String], description: String) {
        // Derive stable UUID from name so identity is consistent across launches
        self.id = UUID(uuidString: "00000000-0000-0000-0000-\(abs(name.hashValue) % 1_000_000_000_000)".padding(toLength: 36, withPad: "0", startingAt: 0)) ?? UUID()
        self.name = name
        self.category = category
        self.domains = domains
        self.apps = apps
        self.description = description
    }
}

class PresetsLibrary {
    static let shared = PresetsLibrary()
    private init() {}

    let presets: [BlockListPreset] = [
        BlockListPreset(
            name: "Social Media",
            category: "Focus",
            domains: [
                "facebook.com", "twitter.com", "x.com", "instagram.com",
                "tiktok.com", "reddit.com", "linkedin.com", "snapchat.com",
                "pinterest.com", "tumblr.com"
            ],
            apps: [],
            description: "Block all major social media platforms"
        ),
        BlockListPreset(
            name: "Video Streaming",
            category: "Entertainment",
            domains: [
                "youtube.com", "netflix.com", "hulu.com", "disneyplus.com",
                "twitch.tv", "primevideo.com", "peacocktv.com", "max.com",
                "paramountplus.com", "crunchyroll.com"
            ],
            apps: [],
            description: "Block video streaming services"
        ),
        BlockListPreset(
            name: "News Sites",
            category: "Information",
            domains: [
                "cnn.com", "bbc.com", "nytimes.com", "theguardian.com",
                "washingtonpost.com", "foxnews.com", "msn.com",
                "huffpost.com", "reuters.com", "apnews.com"
            ],
            apps: [],
            description: "Block major news websites"
        ),
        BlockListPreset(
            name: "Gaming",
            category: "Games",
            domains: [
                "store.steampowered.com", "epicgames.com", "twitch.tv",
                "ign.com", "gamespot.com", "polygon.com", "kotaku.com"
            ],
            apps: ["Steam", "Epic Games Launcher", "Discord"],
            description: "Block gaming platforms and communities"
        ),
        BlockListPreset(
            name: "Shopping",
            category: "Shopping",
            domains: [
                "amazon.com", "ebay.com", "etsy.com", "walmart.com",
                "target.com", "bestbuy.com", "aliexpress.com", "shein.com"
            ],
            apps: [],
            description: "Block online shopping sites"
        ),
        BlockListPreset(
            name: "Adult Content",
            category: "Focus",
            domains: [
                "pornhub.com", "xvideos.com", "xnxx.com", "redtube.com",
                "youporn.com", "spankbang.com", "tube8.com"
            ],
            apps: [],
            description: "Block adult content websites"
        ),
        BlockListPreset(
            name: "Nuclear Option",
            category: "All",
            domains: [
                "facebook.com", "twitter.com", "x.com", "instagram.com",
                "tiktok.com", "reddit.com", "youtube.com", "netflix.com",
                "twitch.tv", "hulu.com", "disneyplus.com", "amazon.com",
                "ebay.com", "etsy.com", "cnn.com", "bbc.com",
                "nytimes.com", "theguardian.com"
            ],
            apps: [],
            description: "Block the most common distractions"
        )
    ]
}
