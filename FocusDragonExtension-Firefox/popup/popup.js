// Popup script for FocusDragon Firefox extension

async function updateUI() {
  const data = await browser.storage.local.get(["blockedDomains", "incognitoAllowed", "isBlocking"]);
  const domains = data.blockedDomains || [];
  const incognitoAllowed = data.incognitoAllowed;
  const isBlocking = data.isBlocking && domains.length > 0;

  const statusIndicator = document.getElementById("status-indicator");
  const statusText = document.getElementById("status-text");
  const blockedList = document.getElementById("blocked-list");
  const incognitoWarning = document.getElementById("incognito-warning");

  if (incognitoAllowed === false) {
    incognitoWarning.style.display = "block";
  } else {
    incognitoWarning.style.display = "none";
  }

  if (isBlocking) {
    statusIndicator.classList.add("active");
    statusText.textContent = `Blocking ${domains.length} site(s)`;

    blockedList.innerHTML = domains
      .map((domain) => `<div class="blocked-item">${escapeHtml(domain)}</div>`)
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
  browser.runtime.sendMessage({ type: "openApp" });
});

document.getElementById("fix-incognito").addEventListener("click", (e) => {
  e.preventDefault();
  browser.tabs.create({ url: "about:addons" });
});

updateUI();

browser.storage.onChanged.addListener((changes) => {
  if (changes.blockedDomains || changes.incognitoAllowed || changes.isBlocking) {
    updateUI();
  }
});
