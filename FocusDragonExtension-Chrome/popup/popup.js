// Popup script for FocusDragon Chrome extension

async function updateUI() {
  const data = await chrome.storage.local.get(["blockedDomains", "incognitoAllowed"]);
  const domains = data.blockedDomains || [];
  const incognitoAllowed = data.incognitoAllowed;

  const statusIndicator = document.getElementById("status-indicator");
  const statusText = document.getElementById("status-text");
  const blockedList = document.getElementById("blocked-list");
  const incognitoWarning = document.getElementById("incognito-warning");

  // Incognito warning
  if (incognitoAllowed === false) {
    incognitoWarning.style.display = "block";
  } else {
    incognitoWarning.style.display = "none";
  }

  if (domains.length > 0) {
    statusIndicator.classList.add("active");
    statusText.textContent = `Blocking ${domains.length} site(s)`;

    blockedList.innerHTML = domains
      .map(
        (domain) =>
          `<div class="blocked-item">${escapeHtml(domain)}</div>`
      )
      .join("");
  } else {
    statusIndicator.classList.remove("active");
    statusText.textContent = "No blocking active";
    blockedList.innerHTML = '<div class="blocked-item">No sites blocked</div>';
  }
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

document.getElementById("open-app").addEventListener("click", () => {
  // Send message to background to open native app
  chrome.runtime.sendMessage({ type: "openApp" });
});

document.getElementById("fix-incognito").addEventListener("click", (e) => {
  e.preventDefault();
  // Open the extension's detail page where "Allow in Incognito" toggle lives
  chrome.tabs.create({
    url: `chrome://extensions/?id=${chrome.runtime.id}`,
  });
});

// Update UI on load
updateUI();

// Update UI when storage changes
chrome.storage.onChanged.addListener((changes) => {
  if (changes.blockedDomains || changes.incognitoAllowed) {
    updateUI();
  }
});
