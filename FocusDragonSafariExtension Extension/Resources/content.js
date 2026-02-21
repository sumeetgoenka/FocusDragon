// FocusDragon Safari Extension - content.js
// Detects direct IP address navigation and notifies background

(function () {
    const ipPattern = /^https?:\/\/(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/|$)/;
    if (ipPattern.test(window.location.href)) {
        browser.runtime.sendMessage({ type: "ipDetected", url: window.location.href });
    }
})();
