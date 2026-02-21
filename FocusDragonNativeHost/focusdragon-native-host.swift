#!/usr/bin/env swift
//
//  FocusDragonNativeHost
//
//  Native messaging host for Chrome/Firefox extensions.
//  Receives JSON messages from the extension via stdin (length-prefixed),
//  writes heartbeat files for the daemon, and responds with blocked domain lists.
//
//  Chrome native messaging protocol:
//    - Each message is preceded by a 4-byte (UInt32) length in native byte order
//    - Messages are JSON objects
//

import Foundation

// MARK: - Paths

let configPath = "/Library/Application Support/FocusDragon/config.json"
let heartbeatDir = "/Library/Application Support/FocusDragon/heartbeats"
let configPollInterval: TimeInterval = 2.0

let writeLock = NSLock()
var configPollTimer: DispatchSourceTimer?
var lastConfigModTime: Date?

// MARK: - Native Messaging I/O

/// Read a single native messaging message from stdin
func readMessage() -> [String: Any]? {
    // Read 4-byte length prefix
    var lengthBytes = [UInt8](repeating: 0, count: 4)
    let bytesRead = fread(&lengthBytes, 1, 4, stdin)
    guard bytesRead == 4 else { return nil }

    let length = UInt32(lengthBytes[0])
        | (UInt32(lengthBytes[1]) << 8)
        | (UInt32(lengthBytes[2]) << 16)
        | (UInt32(lengthBytes[3]) << 24)

    guard length > 0, length < 1_048_576 else { return nil } // Max 1MB

    // Read message body
    var messageBytes = [UInt8](repeating: 0, count: Int(length))
    let bodyRead = fread(&messageBytes, 1, Int(length), stdin)
    guard bodyRead == Int(length) else { return nil }

    let data = Data(messageBytes)
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return json
}

/// Write a native messaging message to stdout
func writeMessage(_ message: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: message) else { return }

    var length = UInt32(data.count)
    let lengthBytes = withUnsafeBytes(of: &length) { Array($0) }

    writeLock.lock()
    defer { writeLock.unlock() }

    // Write length prefix
    fwrite(lengthBytes, 1, 4, stdout)
    // Write message body
    _ = data.withUnsafeBytes { ptr in
        fwrite(ptr.baseAddress, 1, data.count, stdout)
    }
    fflush(stdout)
}

// MARK: - Heartbeat

func recordHeartbeat(browser: String, incognitoAllowed: Bool, windowCount: Int, profileId: String) {
    let fm = FileManager.default

    try? fm.createDirectory(
        atPath: heartbeatDir,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: NSNumber(value: 0o777)]
    )

    // Write a per-profile heartbeat file with metadata
    let profileSafe = profileId.replacingOccurrences(of: "/", with: "_")
    let path = (heartbeatDir as NSString).appendingPathComponent("\(browser)_\(profileSafe).heartbeat")

    let heartbeatData: [String: Any] = [
        "browser": browser,
        "profileId": profileId,
        "incognitoAllowed": incognitoAllowed,
        "windowCount": windowCount,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: heartbeatData, options: .prettyPrinted) {
        try? jsonData.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // Also touch the legacy combined heartbeat for backward compat
    let legacyPath = (heartbeatDir as NSString).appendingPathComponent("\(browser).heartbeat")
    if fm.fileExists(atPath: legacyPath) {
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: legacyPath)
    } else {
        try? ISO8601DateFormatter().string(from: Date()).write(toFile: legacyPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Config Reading

struct LockInfo {
    let isLocked: Bool
    let lockType: String
    let timerExpiry: String?
}

func getBlockedDomains() -> ([String], Bool, [[String: Any]], LockInfo?) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ([], false, [], nil)
    }

    let domains = json["blockedDomains"] as? [String] ?? []
    let isBlocking = json["isBlocking"] as? Bool ?? false
    let urlExceptions = json["urlExceptions"] as? [[String: Any]] ?? []

    var lockInfo: LockInfo? = nil
    if let ls = json["lockState"] as? [String: Any],
       let isLocked = ls["isLocked"] as? Bool, isLocked {
        let lockType = ls["lockType"] as? String ?? "unknown"
        let timerExpiry = json["timerLockExpiry"] as? String
        lockInfo = LockInfo(isLocked: true, lockType: lockType, timerExpiry: timerExpiry)
    }

    return (domains, isBlocking, urlExceptions, lockInfo)
}

func sendBlockedDomains() {
    let (domains, isBlocking, urlExceptions, lockInfo) = getBlockedDomains()
    var message: [String: Any] = [
        "type": "updateBlockedDomains",
        "domains": domains,
        "isBlocking": isBlocking,
        "urlExceptions": urlExceptions
    ]
    if let li = lockInfo {
        var ls: [String: Any] = ["isLocked": li.isLocked, "lockType": li.lockType]
        if let expiry = li.timerExpiry { ls["timerExpiry"] = expiry }
        message["lockState"] = ls
    }
    writeMessage(message)
}

func startConfigPolling() {
    let queue = DispatchQueue(label: "focusdragon.nativehost.config")
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + configPollInterval, repeating: configPollInterval)
    timer.setEventHandler {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
           let modDate = attrs[.modificationDate] as? Date {
            if let last = lastConfigModTime {
                if modDate > last {
                    lastConfigModTime = modDate
                    sendBlockedDomains()
                }
            } else {
                lastConfigModTime = modDate
                sendBlockedDomains()
            }
        }
    }
    timer.resume()
    configPollTimer = timer
}

// MARK: - Message Handling

func handleMessage(_ message: [String: Any]) {
    guard let type = message["type"] as? String else { return }

    switch type {
    case "heartbeat":
        let browser = message["browser"] as? String ?? "chrome"
        let incognitoAllowed = message["incognitoAllowed"] as? Bool ?? false
        let windowCount = message["windowCount"] as? Int ?? 0
        let profileId = message["profileId"] as? String ?? "unknown"
        recordHeartbeat(browser: browser, incognitoAllowed: incognitoAllowed,
                        windowCount: windowCount, profileId: profileId)
        writeMessage(["type": "heartbeatAck", "status": "ok"])

    case "getBlockedDomains":
        sendBlockedDomains()

    case "openApp":
        // Open the FocusDragon app
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-b", "com.anaygoenka.FocusDragon"]
        try? task.run()
        writeMessage(["type": "openAppAck", "status": "ok"])

    default:
        writeMessage(["type": "error", "message": "Unknown message type: \(type)"])
    }
}

// MARK: - Main Loop

// Disable buffering
setvbuf(stdin, nil, _IONBF, 0)
setvbuf(stdout, nil, _IONBF, 0)

// Send initial status
sendBlockedDomains()

// Watch config.json for changes to push updates
startConfigPolling()

// Main message loop
while true {
    guard let message = readMessage() else {
        // stdin closed (extension disconnected)
        break
    }
    handleMessage(message)
}
