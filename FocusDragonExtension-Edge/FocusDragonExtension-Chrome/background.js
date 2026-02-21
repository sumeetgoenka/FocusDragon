// Background service worker for FocusDragon Chrome extension

const NATIVE_APP_NAME = "com.focusdragon.nativehost";
const BROWSER_NAME = "chrome";
const STORAGE_KEY = "blockedDomains";
const PROFILE_ID_KEY = "profileId";
const RULE_ID_START = 1;
const HEARTBEAT_INTERVAL_MS = 2000; // Tightened: 2s (was 3s)

// Connect to native host
let nativePort = null;
let heartbeatTimer = null;
let heartbeatSeq = 0; // Monotonically increasing sequence counter

function connectNative() {
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_APP_NAME);

    nativePort.onMessage.addListener((message) => {
      console.log("Received from native:", message);
      handleNativeMessage(message);
    });

    nativePort.onDisconnect.addListener(() => {
      console.log("Native host disconnected");
      nativePort = null;
      stopHeartbeat();

      // Retry connection after 5 seconds
      setTimeout(connectNative, 5000);
    });

    // Request current blocked domains
    nativePort.postMessage({ type: "getBlockedDomains" });

    // Start heartbeat so the daemon knows the extension is alive
    startHeartbeat();
  } catch (error) {
    console.error("Failed to connect to native host:", error);
    nativePort = null;
  }
}

// Heartbeat: periodically tell the native host we're alive.
// The native host writes a timestamp file the daemon checks.
function startHeartbeat() {
  stopHeartbeat();
  sendHeartbeat(); // send immediately
  heartbeatTimer = setInterval(sendHeartbeat, HEARTBEAT_INTERVAL_MS);
}

function stopHeartbeat() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

async function sendHeartbeat() {
  if (!nativePort) return;

  try {
    const incognitoAllowed = await getIncognitoAllowed();

    // Count all windows the extension can see (normal + incognito if allowed)
    const windows = await chrome.windows.getAll({ windowTypes: ["normal"] });

    const profileId = await getProfileId();

    heartbeatSeq++;

    nativePort.postMessage({
      type: "heartbeat",
      browser: BROWSER_NAME,
      timestamp: Date.now(),
      incognitoAllowed: incognitoAllowed,
      windowCount: windows.length,
      profileId: profileId,
      seq: heartbeatSeq,
    });

    await chrome.storage.local.set({ incognitoAllowed });
  } catch (e) {
    console.warn("Failed to send heartbeat:", e);
  }
}

async function getProfileId() {
  const data = await chrome.storage.local.get(PROFILE_ID_KEY);
  if (data && data[PROFILE_ID_KEY]) {
    return data[PROFILE_ID_KEY];
  }

  const id = (crypto && crypto.randomUUID)
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;

  await chrome.storage.local.set({ [PROFILE_ID_KEY]: id });
  return id;
}

async function getIncognitoAllowed() {
  return await new Promise((resolve) =>
    chrome.extension.isAllowedIncognitoAccess(resolve)
  );
}

// ─── Tab Guardian ───────────────────────────────────────────────────
// Prevent users from navigating to chrome://extensions to disable the
// extension during a blocking session. Also block direct IP access to
// blocked domains.

const GUARDED_URL_PREFIXES = [
  "chrome://extensions",
  "chrome://settings/extensions",
  "brave://extensions",
  "brave://settings/extensions",
  "edge://extensions",
  "edge://settings/extensions",
  "vivaldi://extensions",
  "vivaldi://settings/extensions",
  "opera://extensions",
  "opera://settings/extensions",
  "chrome-extension://",    // prevent accessing other extension internals
];

// Our own extension pages are allowed
const SELF_PREFIX = `chrome-extension://${chrome.runtime.id}`;

// Check if blocking is currently active
async function isBlockingActive() {
  const data = await chrome.storage.local.get(STORAGE_KEY);
  const domains = data[STORAGE_KEY] || [];
  return domains.length > 0;
}

// Monitor tab updates — close tabs that navigate to guarded URLs
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (!changeInfo.url) return;
  if (!(await isBlockingActive())) return;

  const url = changeInfo.url;

  // Allow our own extension pages (blocked.html, popup, etc.)
  if (url.startsWith(SELF_PREFIX)) return;

  // Block guarded URLs (extensions page, settings)
  for (const prefix of GUARDED_URL_PREFIXES) {
    if (url.startsWith(prefix)) {
      console.log(`Blocked navigation to guarded URL: ${url}`);
      try {
        // Redirect to our blocked page instead of closing
        await chrome.tabs.update(tabId, {
          url: chrome.runtime.getURL("/blocked.html"),
        });
      } catch {
        // If update fails, try closing
        try { await chrome.tabs.remove(tabId); } catch {}
      }
      return;
    }
  }

  // Block direct IP address access to blocked sites
  // Match http(s)://IP_ADDRESS patterns
  const ipPattern = /^https?:\/\/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d+)?(\/|$)/;
  const match = url.match(ipPattern);
  if (match) {
    console.log(`Blocked direct IP navigation: ${url}`);
    try {
      await chrome.tabs.update(tabId, {
        url: chrome.runtime.getURL("/blocked.html"),
      });
    } catch {}
  }
});

// Also guard new tabs being created to guarded URLs
chrome.tabs.onCreated.addListener(async (tab) => {
  if (!tab.pendingUrl && !tab.url) return;
  if (!(await isBlockingActive())) return;

  const url = tab.pendingUrl || tab.url;
  if (url.startsWith(SELF_PREFIX)) return;

  for (const prefix of GUARDED_URL_PREFIXES) {
    if (url.startsWith(prefix)) {
      try {
        await chrome.tabs.update(tab.id, {
          url: chrome.runtime.getURL("/blocked.html"),
        });
      } catch {
        try { await chrome.tabs.remove(tab.id); } catch {}
      }
      return;
    }
  }
});

function handleNativeMessage(message) {
  switch (message.type) {
    case "updateBlockedDomains":
      updateBlockingRules(message.domains, message.isBlocking);
      break;

    case "blockStatus":
      updateExtensionIcon(message.isBlocking);
      break;

    default:
      console.warn("Unknown message type:", message.type);
  }
}

// Update blocking rules using declarativeNetRequest
async function updateBlockingRules(domains, isBlocking) {
  if (!isBlocking || !domains || domains.length === 0) {
    // Clear all rules
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: await getAllRuleIds(),
    });

    await chrome.storage.local.set({ [STORAGE_KEY]: [] });
    updateExtensionIcon(false);
    return;
  }

  // Generate rules
  const rules = [];
  let ruleId = RULE_ID_START;

  for (const domain of domains) {
    // Block main domain
    rules.push({
      id: ruleId++,
      priority: 1,
      action: {
        type: "redirect",
        redirect: { extensionPath: "/blocked.html" },
      },
      condition: {
        urlFilter: `*://${domain}/*`,
        resourceTypes: ["main_frame"],
      },
    });

    // Block www variant
    if (!domain.startsWith("www.")) {
      rules.push({
        id: ruleId++,
        priority: 1,
        action: {
          type: "redirect",
          redirect: { extensionPath: "/blocked.html" },
        },
        condition: {
          urlFilter: `*://www.${domain}/*`,
          resourceTypes: ["main_frame"],
        },
      });
    }

    // Block subdomains
    rules.push({
      id: ruleId++,
      priority: 1,
      action: {
        type: "redirect",
        redirect: { extensionPath: "/blocked.html" },
      },
      condition: {
        urlFilter: `*://*.${domain}/*`,
        resourceTypes: ["main_frame"],
      },
    });
  }

  // Update rules
  try {
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: await getAllRuleIds(),
      addRules: rules,
    });

    await chrome.storage.local.set({ [STORAGE_KEY]: domains });
    updateExtensionIcon(true);

    console.log(`Updated blocking rules for ${domains.length} domains`);
  } catch (error) {
    console.error("Failed to update rules:", error);
  }
}

async function getAllRuleIds() {
  const rules = await chrome.declarativeNetRequest.getDynamicRules();
  return rules.map((rule) => rule.id);
}

function updateExtensionIcon(isBlocking) {
  const iconPath = isBlocking ? "icons/icon-active" : "icons/icon";

  chrome.action.setIcon({
    path: {
      16: `${iconPath}16.png`,
      48: `${iconPath}48.png`,
    },
  });

  chrome.action.setBadgeText({
    text: isBlocking ? "ON" : "",
  });

  chrome.action.setBadgeBackgroundColor({
    color: isBlocking ? "#FF0000" : "#808080",
  });
}

// Listen for messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "openApp") {
    if (nativePort) {
      nativePort.postMessage({ type: "openApp" });
    }
    sendResponse({ success: true });
  } else if (message.type === "getStatus") {
    chrome.storage.local.get(STORAGE_KEY, (result) => {
      const domains = result[STORAGE_KEY] || [];
      sendResponse({
        isBlocking: domains.length > 0,
        domains: domains,
        connected: nativePort !== null,
      });
    });
    return true; // async sendResponse
  }
});

// Check incognito access and warn if not granted
async function checkIncognitoAccess() {
  const allowed = await getIncognitoAllowed();
  await chrome.storage.local.set({ incognitoAllowed: allowed });
  if (!allowed) {
    console.warn(
      "FocusDragon: Incognito access NOT granted. " +
      "Go to chrome://extensions → FocusDragon → Details → Allow in Incognito"
    );
  }
  return allowed;
}

// Initialize
connectNative();
checkIncognitoAccess();

// Restore rules on startup
chrome.runtime.onStartup.addListener(async () => {
  console.log("Extension started");
  connectNative();
  checkIncognitoAccess();
});

// Handle installation
chrome.runtime.onInstalled.addListener((details) => {
  console.log("Extension installed:", details.reason);

  if (details.reason === "install") {
    // First install — open popup to show welcome state
    console.log("FocusDragon extension installed successfully");
  }
});
