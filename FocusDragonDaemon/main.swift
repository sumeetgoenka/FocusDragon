//
//  main.swift
//  FocusDragonDaemon
//
//  Created by Anay Goenka on 18/02/2026.
//

import Foundation
import Darwin

// Global daemon instance for signal handlers
var daemonService: DaemonService?

// Signal handler - must be global function for C interop
func signalHandler(_ signal: Int32) {
    let signalName: String
    switch signal {
    case SIGTERM: signalName = "SIGTERM"
    case SIGINT: signalName = "SIGINT"
    case SIGHUP: signalName = "SIGHUP"
    default: signalName = "UNKNOWN(\(signal))"
    }

    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] [SIGNAL] Received \(signalName)")

    if signal == SIGHUP {
        // Reload configuration on SIGHUP
        daemonService?.reloadConfiguration()
    } else {
        // Graceful shutdown on SIGTERM/SIGINT
        daemonService?.stop()
        exit(0)
    }
}

// Register signal handlers
signal(SIGTERM, signalHandler)
signal(SIGINT, signalHandler)
signal(SIGHUP, signalHandler)

// Create and start daemon
daemonService = DaemonService()

let timestamp = ISO8601DateFormatter().string(from: Date())
print("[\(timestamp)] [MAIN] FocusDragon Daemon starting...")
print("[\(timestamp)] [MAIN] PID: \(getpid())")

daemonService?.start()

// Keep running
RunLoop.main.run()

