// Background script for FocusDragon Firefox extension

const NATIVE_APP_NAME = "com.focusdragon.nativehost";
const STORAGE_KEY = "blockedDomains";
const STORAGE_BLOCKING_KEY = "isBlocking";
const EXCEPTIONS_KEY = "urlExceptions";
const PROFILE_ID_KEY = "profileId";
const HEARTBEAT_INTERVAL_MS = 2000;

let nativePort = null;
let heartbeatTimer = null;
let heartbeatSeq = 0;

let blockedDomains = [];
let isBlocking = false;
let currentLockState = null;
let urlExceptions = [];

const GUARDED_URL_PREFIXES = [
  "about:addons",
  "about:debugging",
  "about:config",
  "about:profiles",
  "about:support",
  "about:preferences",
  "moz-extension://",
];

const SELF_PREFIX = browser.runtime.getURL("");

function connectNative() {
  try {
    nativePort = browser.runtime.connectNative(NATIVE_APP_NAME);

    nativePort.onMessage.addListener((message) => {
      console.log("Received from native:", message);
      handleNativeMessage(message);
    });

    nativePort.onDisconnect.addListener(() => {
      console.log("Native host disconnected");
      nativePort = null;
      stopHeartbeat();
      setTimeout(connectNative, 5000);
    });

    nativePort.postMessage({ type: "getBlockedDomains" });
    startHeartbeat();
  } catch (error) {
    console.error("Failed to connect to native host:", error);
    nativePort = null;
  }
}

function startHeartbeat() {
  stopHeartbeat();
  sendHeartbeat();
  heartbeatTimer = setInterval(sendHeartbeat, HEARTBEAT_INTERVAL_MS);
}

function stopHeartbeat() {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

async function getProfileId() {
  const data = await browser.storage.local.get(PROFILE_ID_KEY);
  if (data && data[PROFILE_ID_KEY]) {
    return data[PROFILE_ID_KEY];
  }

  const id = (crypto && crypto.randomUUID)
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(16).slice(2)}`;

  await browser.storage.local.set({ [PROFILE_ID_KEY]: id });
  return id;
}

async function getIncognitoAllowed() {
  try {
    if (browser.extension && typeof browser.extension.isAllowedIncognitoAccess === "function") {
      return await browser.extension.isAllowedIncognitoAccess();
    }
  } catch (error) {
    console.warn("Incognito check failed:", error);
  }

  // If we cannot verify, treat as not allowed for safety.
  return false;
}

async function sendHeartbeat() {
  if (!nativePort) return;

  try {
    const incognitoAllowed = await getIncognitoAllowed();
    const windows = await browser.windows.getAll({ windowTypes: ["normal"] });
    const profileId = await getProfileId();

    heartbeatSeq++;

    nativePort.postMessage({
      type: "heartbeat",
      browser: "firefox",
      timestamp: Date.now(),
      incognitoAllowed: incognitoAllowed,
      windowCount: windows.length,
      profileId: profileId,
      seq: heartbeatSeq,
    });

    await browser.storage.local.set({ incognitoAllowed });
  } catch (e) {
    console.warn("Failed to send heartbeat:", e);
  }
}

async function isBlockingActive() {
  const data = await browser.storage.local.get([STORAGE_KEY, STORAGE_BLOCKING_KEY]);
  const domains = data[STORAGE_KEY] || [];
  const blocking = data[STORAGE_BLOCKING_KEY] || false;
  return blocking && domains.length > 0;
}

// ─── Tab Guardian ───────────────────────────────────────────────────

browser.tabs.onUpdated.addListener(async (tabId, changeInfo) => {
  if (!changeInfo.url) return;
  if (!(await isBlockingActive())) return;

  const url = changeInfo.url;
  if (url.startsWith(SELF_PREFIX)) return;

  for (const prefix of GUARDED_URL_PREFIXES) {
    if (url.startsWith(prefix)) {
      console.log(`Blocked navigation to guarded URL: ${url}`);
      try {
        await browser.tabs.update(tabId, {
          url: browser.runtime.getURL("blocked.html"),
        });
      } catch {
        try { await browser.tabs.remove(tabId); } catch {}
      }
      return;
    }
  }

  const ipPattern = /^https?:\/\/(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/|$)/;
  if (ipPattern.test(url)) {
    try {
      await browser.tabs.update(tabId, {
        url: browser.runtime.getURL("blocked.html"),
      });
    } catch {}
  }
});

browser.tabs.onCreated.addListener(async (tab) => {
  const url = tab.pendingUrl || tab.url;
  if (!url) return;
  if (!(await isBlockingActive())) return;

  if (url.startsWith(SELF_PREFIX)) return;

  for (const prefix of GUARDED_URL_PREFIXES) {
    if (url.startsWith(prefix)) {
      try {
        await browser.tabs.update(tab.id, {
          url: browser.runtime.getURL("blocked.html"),
        });
      } catch {
        try { await browser.tabs.remove(tab.id); } catch {}
      }
      return;
    }
  }
});

function handleNativeMessage(message) {
  switch (message.type) {
    case "updateBlockedDomains":
      blockedDomains = message.domains || [];
      isBlocking = message.isBlocking || false;
      urlExceptions = message.urlExceptions || [];
      currentLockState = message.lockState || null;
      browser.storage.local.set({ lockState: currentLockState });
      updateWebRequestListener();
      updateExtensionIcon();
      persistState();
      break;

    case "blockStatus":
      isBlocking = message.isBlocking || false;
      updateExtensionIcon();
      persistState();
      break;

    default:
      console.warn("Unknown message type:", message.type);
  }
}

async function persistState() {
  await browser.storage.local.set({
    [STORAGE_KEY]: blockedDomains,
    [STORAGE_BLOCKING_KEY]: isBlocking,
    [EXCEPTIONS_KEY]: urlExceptions,
  });
}

function updateWebRequestListener() {
  if (browser.webRequest.onBeforeRequest.hasListener(blockBlockedDomains)) {
    browser.webRequest.onBeforeRequest.removeListener(blockBlockedDomains);
  }
  if (browser.webRequest.onBeforeRequest.hasListener(blockIPAddress)) {
    browser.webRequest.onBeforeRequest.removeListener(blockIPAddress);
  }

  if (isBlocking && blockedDomains.length > 0) {
    const patterns = generateUrlPatterns(blockedDomains);

    browser.webRequest.onBeforeRequest.addListener(
      blockBlockedDomains,
      { urls: patterns, types: ["main_frame"] },
      ["blocking"]
    );

    browser.webRequest.onBeforeRequest.addListener(
      blockIPAddress,
      { urls: ["<all_urls>"], types: ["main_frame"] },
      ["blocking"]
    );
  }
}

function blockBlockedDomains(details) {
  if (isAllowedByException(details.url)) {
    return undefined;
  }
  return { redirectUrl: browser.runtime.getURL("blocked.html") };
}

function blockIPAddress(details) {
  const ipPattern = /^https?:\/\/(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/|$)/;
  if (ipPattern.test(details.url)) {
    return { redirectUrl: browser.runtime.getURL("blocked.html") };
  }
  return undefined;
}

function generateUrlPatterns(domains) {
  const patterns = [];
  for (const domain of domains) {
    patterns.push(`*://${domain}/*`);
    patterns.push(`*://www.${domain}/*`);
    patterns.push(`*://*.${domain}/*`);
  }
  return patterns;
}

function isAllowedByException(url) {
  if (!urlExceptions || urlExceptions.length === 0) return false;

  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }

  const host = parsed.hostname.toLowerCase();
  const path = parsed.pathname || "/";

  for (const exception of urlExceptions) {
    const domain = (exception.domain || "").toLowerCase();
    if (!domain) continue;

    const hostMatches =
      host === domain ||
      host === `www.${domain}` ||
      host.endsWith(`.${domain}`);

    if (!hostMatches) continue;

    const allowedPaths = exception.allowedPaths || [];
    for (const rawPath of allowedPaths) {
      const normalized = rawPath.startsWith("/") ? rawPath : `/${rawPath}`;
      if (path.startsWith(normalized)) {
        return true;
      }
    }
  }

  return false;
}

function updateExtensionIcon() {
  const iconPath = isBlocking ? "icons/icon-active" : "icons/icon";

  browser.browserAction.setIcon({
    path: {
      48: `${iconPath}48.png`,
      96: `${iconPath}96.png`,
    },
  });

  browser.browserAction.setBadgeText({
    text: isBlocking ? "ON" : "",
  });

  browser.browserAction.setBadgeBackgroundColor({
    color: isBlocking ? "#FF0000" : "#808080",
  });
}

async function restoreFromStorage() {
  const data = await browser.storage.local.get([STORAGE_KEY, STORAGE_BLOCKING_KEY]);
  blockedDomains = data[STORAGE_KEY] || [];
  isBlocking = data[STORAGE_BLOCKING_KEY] || false;
  updateWebRequestListener();
  updateExtensionIcon();
}

browser.runtime.onMessage.addListener((message) => {
  if (message.type === "openApp") {
    if (nativePort) {
      nativePort.postMessage({ type: "openApp" });
    }
    return Promise.resolve({ success: true });
  }

  if (message.type === "getStatus") {
    return browser.storage.local.get([STORAGE_KEY, STORAGE_BLOCKING_KEY]).then((result) => {
      const domains = result[STORAGE_KEY] || [];
      const blocking = result[STORAGE_BLOCKING_KEY] || false;
      return {
        isBlocking: blocking && domains.length > 0,
        domains: domains,
        connected: nativePort !== null,
      };
    });
  }

  if (message.type === "getLockInfo") {
    return browser.storage.local.get("lockState").then((result) => {
      return { lockState: result.lockState || currentLockState || null };
    });
  }

  return undefined;
});

// Initialize
restoreFromStorage().finally(() => {
  connectNative();
});

browser.runtime.onStartup.addListener(() => {
  connectNative();
});

browser.runtime.onInstalled.addListener((details) => {
  console.log("Extension installed:", details.reason);
});
