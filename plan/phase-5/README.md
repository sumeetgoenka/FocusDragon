# Phase 5: Browser Extensions

**Objective:** Create browser extensions for Chrome, Firefox, and Safari to provide redundant blocking and detect circumvention attempts.

## Overview

Browser extensions add an additional layer of protection:
- Block sites even if hosts file is bypassed
- Block access by IP address (hosts file doesn't catch this)
- Detect if extension is disabled
- Work in incognito/private mode
- Report tamper attempts to daemon

## Why Browser Extensions?

Hosts file blocking has limitations:
- ❌ Doesn't block access by IP (e.g., `142.250.185.46` for Google)
- ❌ Can be bypassed with VPN (sometimes)
- ❌ Doesn't work with DNS-over-HTTPS in some browsers
- ✅ Extensions catch these bypass attempts

## Extension Features

### Core Features
1. **URL Blocking** - Block by domain and pattern
2. **IP Blocking** - Block direct IP access
3. **Incognito Support** - Work in private browsing
4. **Sync Block List** - Read from FocusDragon config
5. **Tamper Detection** - Report disable attempts
6. **Lock Enforcement** - Can't disable during locks

### UI Features
- Custom block page with FocusDragon branding
- Time remaining on timer locks
- Option to request unlock (if not locked)

## Architecture

```
Browser Extension
    ├── Manifest (Chrome V3 / Firefox WebExtensions / Safari)
    ├── Background Script (monitors requests, enforces blocks)
    ├── Content Script (detects IP access, shows block page)
    └── Native Messaging (communicates with daemon)

Daemon
    └── Extension Monitor (detects if extensions disabled)
```

## Implementation Sections

### 5.1 Chrome Extension (Manifest V3)
- Manifest configuration
- Background service worker
- declarativeNetRequest API
- Content scripts
- Native messaging

### 5.2 Firefox Extension
- WebExtensions API
- webRequest blocking
- Native messaging for Firefox
- Incognito permissions

### 5.3 Safari Extension
- Safari App Extension target
- Safari-specific APIs
- Integration with main app

### 5.4 Native Messaging
- Protocol for app ↔ extension communication
- Sync block list
- Report extension status
- Receive lock state

### 5.5 Extension Enforcement
- Detect extension disable attempts
- Force re-enable during locks (if possible)
- Alert user if extension removed

## File Structure

```
Extensions/
├── Chrome/
│   ├── manifest.json
│   ├── background.js
│   ├── content.js
│   ├── blocked.html
│   ├── blocked.css
│   ├── native-messaging-host.json
│   └── icons/
│       ├── icon16.png
│       ├── icon48.png
│       └── icon128.png
├── Firefox/
│   ├── manifest.json
│   ├── background.js
│   ├── content.js
│   ├── blocked.html
│   └── icons/
└── Safari/
    └── FocusDragonExtension/
        ├── Info.plist
        ├── SafariExtensionHandler.swift
        └── Resources/
```

## Chrome Extension Implementation

### manifest.json
```json
{
  "manifest_version": 3,
  "name": "FocusDragon Blocker",
  "version": "1.0",
  "description": "Website and application blocker extension",
  "permissions": [
    "declarativeNetRequest",
    "declarativeNetRequestFeedback",
    "storage",
    "nativeMessaging"
  ],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [{
    "matches": ["<all_urls>"],
    "js": ["content.js"]
  }],
  "declarative_net_request": {
    "rule_resources": [{
      "id": "focusdragon_rules",
      "enabled": true,
      "path": "rules.json"
    }]
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  }
}
```

### background.js
```javascript
// Load blocked domains from native app
let blockedDomains = [];
let isLocked = false;

// Connect to native app
const port = chrome.runtime.connectNative('com.focusdragon.extension');

port.onMessage.addListener((message) => {
  if (message.type === 'updateBlockList') {
    blockedDomains = message.domains;
    updateBlockingRules();
  }
  if (message.type === 'lockState') {
    isLocked = message.locked;
  }
});

// Update declarativeNetRequest rules
function updateBlockingRules() {
  const rules = blockedDomains.map((domain, index) => ({
    id: index + 1,
    priority: 1,
    action: { type: 'redirect', redirect: { url: chrome.runtime.getURL('blocked.html') } },
    condition: {
      urlFilter: `*://*.${domain}/*`,
      resourceTypes: ['main_frame']
    }
  }));

  chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: rules.map(r => r.id),
    addRules: rules
  });
}

// Detect extension disable attempts
chrome.management.onDisabled.addListener((info) => {
  if (info.id === chrome.runtime.id && isLocked) {
    // Extension was disabled during lock
    port.postMessage({
      type: 'tamperDetected',
      action: 'extension_disabled'
    });

    // Try to re-enable (requires user permission)
    chrome.management.setEnabled(chrome.runtime.id, true);
  }
});

// Request block list on startup
port.postMessage({ type: 'getBlockList' });
```

### content.js
```javascript
// Detect direct IP access
const url = window.location.href;
const ipPattern = /^https?:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;

if (ipPattern.test(url)) {
  chrome.runtime.sendMessage({
    type: 'checkIP',
    ip: url
  });
}
```

### blocked.html
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Site Blocked - FocusDragon</title>
  <link rel="stylesheet" href="blocked.css">
</head>
<body>
  <div class="container">
    <h1>🐉 Site Blocked by FocusDragon</h1>
    <p>This website is currently blocked to help you stay focused.</p>
    <p id="lockInfo"></p>
    <button id="requestUnlock">Request Unlock</button>
  </div>
  <script src="blocked.js"></script>
</body>
</html>
```

## Native Messaging Setup

### Native Messaging Host Manifest (macOS)
```json
{
  "name": "com.focusdragon.extension",
  "description": "FocusDragon Extension Native Host",
  "path": "/Library/Application Support/FocusDragon/extension-bridge",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://YOUR_EXTENSION_ID/"
  ]
}
```

Install location:
- Chrome: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
- Firefox: `~/Library/Application Support/Mozilla/NativeMessagingHosts/`

### Native Bridge (Swift)
```swift
#!/usr/bin/env swift
import Foundation

func readMessage() -> [String: Any]? {
    var lengthBytes = [UInt8](repeating: 0, count: 4)
    let stdin = FileHandle.standardInput
    let lengthData = stdin.readData(ofLength: 4)
    lengthBytes = [UInt8](lengthData)

    let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
    let messageData = stdin.readData(ofLength: Int(length))

    return try? JSONSerialization.jsonObject(with: messageData) as? [String: Any]
}

func sendMessage(_ message: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: message)
    var length = UInt32(data.count)

    let stdout = FileHandle.standardOutput
    let lengthData = Data(bytes: &length, count: 4)
    stdout.write(lengthData)
    stdout.write(data)
}

// Main loop
while true {
    guard let message = readMessage() else { break }

    // Read config from daemon
    let configPath = "/Library/Application Support/FocusDragon/config.json"
    let configData = try? Data(contentsOf: URL(fileURLWithPath: configPath))
    let config = try? JSONSerialization.jsonObject(with: configData!) as? [String: Any]

    // Send back to extension
    sendMessage([
        "type": "updateBlockList",
        "domains": config?["blockedDomains"] ?? []
    ])
}
```

## Firefox Extension Differences

### manifest.json (Firefox)
```json
{
  "manifest_version": 2,
  "name": "FocusDragon Blocker",
  "version": "1.0",
  "permissions": [
    "webRequest",
    "webRequestBlocking",
    "<all_urls>",
    "storage",
    "nativeMessaging"
  ],
  "background": {
    "scripts": ["background.js"]
  },
  "browser_specific_settings": {
    "gecko": {
      "id": "focusdragon@example.com"
    }
  }
}
```

Firefox uses `webRequest` API instead of `declarativeNetRequest`.

## Safari Extension

Safari extensions require an App Extension target in Xcode.

### SafariExtensionHandler.swift
```swift
import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // Handle messages from JS
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // Update toolbar
    }
}
```

## Testing Criteria

### Test 1: Basic Blocking
- [ ] Install Chrome extension
- [ ] Add youtube.com to block list
- [ ] Visit youtube.com → blocked page shown

### Test 2: IP Blocking
- [ ] Block google.com
- [ ] Visit `http://142.250.185.46` (Google's IP) → blocked

### Test 3: Incognito Mode
- [ ] Open incognito window
- [ ] Try to access blocked site → still blocked

### Test 4: Native Messaging
- [ ] Update block list in main app
- [ ] Extension receives update within seconds
- [ ] New blocks work immediately

### Test 5: Extension Disable Detection
- [ ] Start locked block
- [ ] Try to disable extension
- [ ] Daemon detects and alerts user

### Test 6: Multi-Browser
- [ ] Install in Chrome, Firefox, Safari
- [ ] All three block same sites
- [ ] Sync works for all

## Deliverables

✅ Chrome extension working
✅ Firefox extension working
✅ Safari extension working
✅ Native messaging functional
✅ IP address blocking
✅ Incognito mode support
✅ Tamper detection
✅ Custom block page
✅ All browsers sync same block list

## Known Limitations

- **Can't prevent extension removal entirely** - Just detect and alert
- **Safari more restrictive** - Requires app extension, not web extension
- **Browser-specific APIs** - Need separate implementations
- **Native messaging can be complex** - Requires proper permissions

## Security Notes

⚠️ Extensions can be force-disabled by user
⚠️ Native messaging requires proper host manifest installation
⚠️ Extensions are an additional layer, not primary defense

## Estimated Time

**Total: 6-8 hours**
- Chrome extension: 2-3 hours
- Firefox extension: 1-2 hours
- Safari extension: 2-3 hours
- Native messaging: 1-2 hours
- Testing: 1 hour

## Next Phase

After Phase 5 → **Phase 6: Advanced Features & Polish**
