const chatEl = document.getElementById("chat");
const innerEl = document.getElementById("messagesInner");
const inputRowEl = document.getElementById("inputRow");
const inputEl = document.getElementById("input");

const CHAT_CONFIG = {
  maxMessagesVisible: 16,
  maxMessagesStored: 250,
  pageScrollLines: 2,
  smoothScroll: true,
  smoothScrollMs: 160
};

let buffer = [];        // oldest -> newest
let viewOffset = 0;     // 0 = bottom (latest), increases as you scroll up
let animTimer = null;

function escapeHtml(s) {
  return (s || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function parseText(text) {
  let out = "";
  let ital = false;

  out += `<span class="seg">`;

  for (let i = 0; i < text.length; i++) {
    if (text.startsWith("^/", i)) {
      out += "<i>";
      ital = true;
      i++;
      continue;
    }
    if (text.startsWith("^r", i)) {
      if (ital) out += "</i>";
      ital = false;
      i++;
      continue;
    }
    if (text.startsWith("^#", i) && i + 8 <= text.length) {
      const hex = text.slice(i + 2, i + 8);
      if (/^[0-9a-fA-F]{6}$/.test(hex)) {
        out += `</span><span class="seg" style="color:#${hex}">`;
        i += 7;
        continue;
      }
    }
    out += escapeHtml(text[i]);
  }

  if (ital) out += "</i>";
  out += "</span>";
  return out;
}

function clampOffset() {
  const maxOffset = Math.max(0, buffer.length - CHAT_CONFIG.maxMessagesVisible);
  if (viewOffset > maxOffset) viewOffset = maxOffset;
  if (viewOffset < 0) viewOffset = 0;
}

function hardResetAnimationState() {
  if (animTimer) {
    clearTimeout(animTimer);
    animTimer = null;
  }
  innerEl.style.transition = "";
  innerEl.style.transform = "";
}

function render() {
  clampOffset();
  innerEl.innerHTML = "";

  const end = buffer.length - viewOffset;
  const start = Math.max(0, end - CHAT_CONFIG.maxMessagesVisible);

  for (let i = start; i < end; i++) {
    const el = document.createElement("div");
    el.className = "msg";
    el.innerHTML = buffer[i].html;
    innerEl.appendChild(el);
  }
}

function animateScroll(dir, cb) {
  if (!CHAT_CONFIG.smoothScroll) {
    cb();
    return;
  }

  const px = 18 * dir;
  innerEl.style.transition = `transform ${CHAT_CONFIG.smoothScrollMs}ms ease`;
  innerEl.style.transform = `translateY(${px}px)`;

  if (animTimer) clearTimeout(animTimer);
  animTimer = setTimeout(() => {
    hardResetAnimationState();
    cb();
  }, CHAT_CONFIG.smoothScrollMs);
}

function scrollUp(lines) {
  const maxOffset = Math.max(0, buffer.length - CHAT_CONFIG.maxMessagesVisible);
  const next = Math.min(maxOffset, viewOffset + lines);
  if (next === viewOffset) return;

  animateScroll(1, () => {
    viewOffset = next;
    render();
  });
}

function scrollDown(lines) {
  const next = Math.max(0, viewOffset - lines);
  if (next === viewOffset) return;

  animateScroll(-1, () => {
    viewOffset = next;
    render();
  });
}

function addMessage(msg) {
  hardResetAnimationState();

  let text = Array.isArray(msg?.args)
    ? msg.args.join(" ")
    : String(msg?.args || "");

  if (Array.isArray(msg?.color)) {
    const [r, g, b] = msg.color;
    const hex = [r, g, b].map(v => v.toString(16).padStart(2, "0")).join("");
    text = `^#${hex}${text}`;
  }

  buffer.push({ html: parseText(text) });

  while (buffer.length > CHAT_CONFIG.maxMessagesStored) {
    buffer.shift();
  }

  viewOffset = 0;

  // ✅ force paint on next frame (helps with “one behind” feeling in CEF)
  requestAnimationFrame(() => render());
}

window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d?.type) return;

  switch (d.type) {
    case "ON_CONFIG":
      Object.assign(CHAT_CONFIG, d.config || {});
      render();
      break;

    case "ON_MESSAGE":
      addMessage(d.message);
      break;

    case "ON_CLEAR":
      buffer = [];
      viewOffset = 0;
      innerEl.innerHTML = "";
      break;

    case "ON_SCROLL":
      if (d.dir === "up") scrollUp(CHAT_CONFIG.pageScrollLines);
      if (d.dir === "down") scrollDown(CHAT_CONFIG.pageScrollLines);
      break;

    case "ON_OPEN":
      inputRowEl.classList.remove("hidden");
      inputEl.value = d.prefix || "";
      inputEl.focus();
      break;

    case "ON_HIDE_CHAT":
      chatEl.style.display = "none";
      break;

    case "ON_SHOW_CHAT":
      chatEl.style.display = "block";
      break;

    case "ON_SOUND":
      const audio = new Audio(`sounds/${d.sound}.ogg`);
      audio.volume = 0.6;
      audio.play().catch(() => {});
      break;
  }
});

document.addEventListener("keydown", (e) => {
  if (inputRowEl.classList.contains("hidden")) return;

  if (e.key === "Escape") {
    inputRowEl.classList.add("hidden");
    fetch(`https://${GetParentResourceName()}/chatResult`, {
      method: "POST",
      body: JSON.stringify({ canceled: true })
    });
  }

  if (e.key === "Enter") {
    const msg = inputEl.value.trim();
    inputRowEl.classList.add("hidden");

    fetch(`https://${GetParentResourceName()}/chatResult`, {
      method: "POST",
      body: JSON.stringify({ canceled: false, message: msg })
    });

    inputEl.value = "";
  }
});

fetch(`https://${GetParentResourceName()}/loaded`, {
  method: "POST",
  body: "{}"
});
