// FocusDragon - blocked page script (Safari)

function formatTime(ms) {
  if (ms <= 0) return "0:00";
  const totalSecs = Math.floor(ms / 1000);
  const hours = Math.floor(totalSecs / 3600);
  const mins = Math.floor((totalSecs % 3600) / 60);
  const secs = totalSecs % 60;
  if (hours > 0) return `${hours}h ${mins}m ${secs}s`;
  return `${mins}m ${String(secs).padStart(2, "0")}s`;
}

function startCountdown(isoExpiry) {
  const expiryMs = new Date(isoExpiry).getTime();
  const timerEl = document.getElementById("timer");
  timerEl.style.display = "block";

  function tick() {
    const remaining = expiryMs - Date.now();
    if (remaining <= 0) {
      timerEl.textContent = "Lock expired";
      return;
    }
    timerEl.textContent = formatTime(remaining) + " remaining";
    setTimeout(tick, 1000);
  }
  tick();
}

function showLockInfo(lockState) {
  if (!lockState || !lockState.isLocked) {
    document.getElementById("unlock-btn").style.display = "inline-block";
    return;
  }

  document.getElementById("lock-info").style.display = "block";
  const label = document.getElementById("lock-label");
  const lockType = lockState.lockType || "unknown";

  switch (lockType) {
    case "timer":
      label.textContent = "Timer lock active";
      if (lockState.timerExpiry) startCountdown(lockState.timerExpiry);
      break;
    case "schedule":
      label.textContent = "Schedule lock — cannot stop until schedule ends";
      break;
    case "randomText":
      label.textContent = "Random-text lock — open FocusDragon to enter the code";
      document.getElementById("unlock-btn").style.display = "inline-block";
      break;
    case "breakable":
      label.textContent = "Breakable lock active";
      document.getElementById("unlock-btn").style.display = "inline-block";
      break;
    default:
      label.textContent = `Locked (${lockType})`;
  }
}

browser.runtime.sendMessage({ type: "getLockInfo" }).then((response) => {
  showLockInfo(response && response.lockState);
}).catch(() => {});

document.getElementById("open-app").addEventListener("click", () => {
  browser.runtime.sendMessage({ type: "openApp" });
});

document.getElementById("unlock-btn").addEventListener("click", () => {
  browser.runtime.sendMessage({ type: "openApp" });
  const btn = document.getElementById("unlock-btn");
  btn.textContent = "Opening FocusDragon…";
  btn.disabled = true;
  setTimeout(() => {
    btn.textContent = "Request Unlock";
    btn.disabled = false;
  }, 3000);
});
