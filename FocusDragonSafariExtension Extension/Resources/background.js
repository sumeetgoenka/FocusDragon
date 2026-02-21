// FocusDragon Safari Extension - background.js
// Uses browser.* WebExtension API + sendNativeMessage to SafariWebExtensionHandler

const STORAGE_KEY = "blockedDomains";
const POLL_INTERVAL_MS = 3000;
const HEARTBEAT_INTERVAL_MS = 5000;

let blockedDomains = [];
let isBlocking = false;
let currentLockState = null;

// ─── Native messaging (one-shot per call for Safari) ────────────────

async function sendNative(message) {
    try {
        return await browser.runtime.sendNativeMessage(
            "com.anaygoenka.FocusDragon",
            message
        );
    } catch (e) {
        console.warn("FocusDragon: native message failed:", e);
        return null;
    }
}

// ─── Block list polling ──────────────────────────────────────────────

async function fetchAndApplyBlockList() {
    const response = await sendNative({ type: "getBlockedDomains" });

    if (!response) {
        // Fallback: use whatever is in storage
        const stored = await browser.storage.local.get([STORAGE_KEY, "isBlocking", "lockState"]);
        blockedDomains = stored[STORAGE_KEY] || [];
        isBlocking = stored.isBlocking || false;
        currentLockState = stored.lockState || null;
        await applyBlockingRules();
        return;
    }

    const newDomains = response.domains || [];
    const newBlocking = response.isBlocking || false;
    const newLock = response.lockState || null;

    const changed = JSON.stringify(newDomains) !== JSON.stringify(blockedDomains)
        || newBlocking !== isBlocking;

    blockedDomains = newDomains;
    isBlocking = newBlocking;
    currentLockState = newLock;

    await browser.storage.local.set({
        [STORAGE_KEY]: blockedDomains,
        isBlocking,
        lockState: currentLockState,
    });

    if (changed) await applyBlockingRules();
}

// ─── Heartbeat ───────────────────────────────────────────────────────

async function sendHeartbeat() {
    await sendNative({ type: "heartbeat", timestamp: Date.now() });
}

// ─── declarativeNetRequest rules ────────────────────────────────────

async function applyBlockingRules() {
    const existing = await browser.declarativeNetRequest.getDynamicRules();
    const removeIds = existing.map((r) => r.id);

    if (!isBlocking || blockedDomains.length === 0) {
        if (removeIds.length > 0) {
            await browser.declarativeNetRequest.updateDynamicRules({ removeRuleIds: removeIds });
        }
        updateBadge(false);
        return;
    }

    const rules = [];
    let ruleId = 1;
    for (const domain of blockedDomains) {
        const blockedPath = browser.runtime.getURL("blocked.html");

        rules.push({
            id: ruleId++,
            priority: 1,
            action: { type: "redirect", redirect: { extensionPath: "/blocked.html" } },
            condition: { urlFilter: `*://${domain}/*`, resourceTypes: ["main_frame"] },
        });
        if (!domain.startsWith("www.")) {
            rules.push({
                id: ruleId++,
                priority: 1,
                action: { type: "redirect", redirect: { extensionPath: "/blocked.html" } },
                condition: { urlFilter: `*://www.${domain}/*`, resourceTypes: ["main_frame"] },
            });
        }
        rules.push({
            id: ruleId++,
            priority: 1,
            action: { type: "redirect", redirect: { extensionPath: "/blocked.html" } },
            condition: { urlFilter: `*://*.${domain}/*`, resourceTypes: ["main_frame"] },
        });
    }

    await browser.declarativeNetRequest.updateDynamicRules({
        removeRuleIds: removeIds,
        addRules: rules,
    });

    updateBadge(true);
}

function updateBadge(active) {
    try {
        browser.action.setBadgeText({ text: active ? "ON" : "" });
        browser.action.setBadgeBackgroundColor({ color: active ? "#FF0000" : "#808080" });
    } catch {}
}

// ─── Tab Guardian (prevent disabling extension) ──────────────────────

const GUARDED_PREFIXES = ["safari-extension://"];

browser.tabs.onUpdated.addListener(async (tabId, changeInfo) => {
    if (!changeInfo.url || !isBlocking) return;
    for (const prefix of GUARDED_PREFIXES) {
        if (changeInfo.url.startsWith(prefix)) {
            try {
                await browser.tabs.update(tabId, {
                    url: browser.runtime.getURL("blocked.html"),
                });
            } catch {}
            return;
        }
    }

    // Block direct IP navigation
    const ipPattern = /^https?:\/\/(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/|$)/;
    if (ipPattern.test(changeInfo.url)) {
        try {
            await browser.tabs.update(tabId, { url: browser.runtime.getURL("blocked.html") });
        } catch {}
    }
});

// ─── Internal message handler ────────────────────────────────────────

browser.runtime.onMessage.addListener((message) => {
    if (message.type === "getStatus") {
        return Promise.resolve({
            isBlocking,
            domains: blockedDomains,
        });
    }
    if (message.type === "getLockInfo") {
        return browser.storage.local.get("lockState").then((r) => ({
            lockState: r.lockState || currentLockState || null,
        }));
    }
    if (message.type === "openApp") {
        sendNative({ type: "openApp" });
        return Promise.resolve({ success: true });
    }
    return undefined;
});

// ─── Init ────────────────────────────────────────────────────────────

// Restore from storage immediately so rules survive service-worker restarts
browser.storage.local.get([STORAGE_KEY, "isBlocking", "lockState"]).then((stored) => {
    blockedDomains = stored[STORAGE_KEY] || [];
    isBlocking = stored.isBlocking || false;
    currentLockState = stored.lockState || null;
    applyBlockingRules();
});

// Poll native app for updates every 3 seconds
setInterval(fetchAndApplyBlockList, POLL_INTERVAL_MS);

// Send heartbeat every 5 seconds so app knows extension is alive
setInterval(sendHeartbeat, HEARTBEAT_INTERVAL_MS);

// Fetch immediately on startup
fetchAndApplyBlockList();
