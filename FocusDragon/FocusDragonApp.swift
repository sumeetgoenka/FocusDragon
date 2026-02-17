//
//  FocusDragonApp.swift
//  FocusDragon
//
//  Created by Anay Goenka on 16/02/2026.
//

import SwiftUI

@main
struct FocusDragonApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
