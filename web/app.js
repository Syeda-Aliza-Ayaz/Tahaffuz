// Tahaffuz - frontend. Sends the message to the Prolog server and shows the
// verdict. All text from the server is inserted with textContent (never
// innerHTML), because the message itself is untrusted.

const ACTION_INDICATORS = new Set([
  "otp_request", "credential_request", "send_money",
  "suspicious_domain", "personal_number_bait",
]);

const VERDICT_TEXT = {
  safe: "Safe",
  suspicious: "Suspicious",
  scam: "Scam",
};

const $ = (id) => document.getElementById(id);
const form = $("form");
const textarea = $("message");
const button = $("analyse");

function show(state) {
  for (const id of ["empty", "loading", "error", "result"]) {
    $(id).hidden = id !== state;
  }
}

function updateCount() {
  $("count").textContent = `${textarea.value.length} / 5000`;
}

async function analyse() {
  const message = textarea.value;
  if (!message.trim()) {
    showError("Please paste a message first.");
    return;
  }
  show("loading");
  button.disabled = true;
  try {
    const res = await fetch("/api/analyse", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      showError(data.error || `The server returned an error (${res.status}).`);
      return;
    }
    render(data);
  } catch (err) {
    showError("Can't reach the Tahaffuz server. Is it running? Start it with: swipl server.pl");
  } finally {
    button.disabled = false;
  }
}

function showError(text) {
  $("error-text").textContent = text;
  show("error");
}

function render(data) {
  const result = $("result");
  result.className = `v-${data.verdict}`;

  $("verdict").textContent = VERDICT_TEXT[data.verdict] || data.verdict;
  $("percent").textContent = `${data.percent}%`;
  const meterFill = $("meter-fill");
  meterFill.style.width = "0";
  void meterFill.offsetWidth;            // force a reflow so the width change animates
  meterFill.style.width = `${data.percent}%`;
  // recommended action, diagnosis and advice all come from the Prolog
  // decision-support rules (src/diagnosis.pl)
  $("advice").textContent = data.action.text;

  const note = $("note");
  note.hidden = !data.note;
  note.textContent = data.note || "";

  const diagnosis = $("diagnosis");
  diagnosis.replaceChildren();
  $("diagnosis-box").hidden = data.diagnosis.length === 0;
  data.diagnosis.forEach((d, i) => {
    const li = document.createElement("li");
    const name = document.createElement("strong");
    name.textContent = d.name;
    if (i === 0 && data.diagnosis.length > 1) name.append(tag("main", "tag tag-main"));
    const desc = document.createElement("span");
    desc.className = "diagnosis-desc";
    desc.textContent = d.description;
    li.append(name, desc);
    diagnosis.append(li);
  });

  const tips = $("tips");
  tips.replaceChildren();
  for (const tip of data.advice) {
    const li = document.createElement("li");
    li.textContent = tip;
    tips.append(li);
  }

  const list = $("reasons");
  list.replaceChildren();
  $("no-reasons").hidden = data.reasons.length > 0;
  for (const r of data.reasons) {
    list.append(reasonItem(r, data.score));
  }
  show("result");
}

function reasonItem(r, score) {
  const li = document.createElement("li");
  li.className = "reason";

  const top = document.createElement("div");
  top.className = "reason-top";
  const text = document.createElement("span");
  text.className = "reason-text";
  text.textContent = r.reason;
  const plus = document.createElement("span");
  plus.className = "reason-plus";
  plus.textContent = `+${Math.round(r.contribution * 100)}%`;
  plus.title = "How much this raised the score";
  top.append(text, plus);

  // bar = share of the final score this indicator contributed
  const bar = document.createElement("div");
  bar.className = "reason-bar";
  const fill = document.createElement("div");
  fill.style.width = `${score > 0 ? (r.contribution / score) * 100 : 0}%`;
  bar.append(fill);

  const meta = document.createElement("div");
  meta.className = "reason-meta";
  meta.append(`CF ${r.cf.toFixed(2)}`);
  if (ACTION_INDICATORS.has(r.indicator)) {
    meta.append(tag("direct request", "tag tag-action"));
  }
  if (r.matched.length) {
    meta.append(" · matched:");
    for (const word of r.matched) meta.append(tag(word, "tag"));
  }

  li.append(top, bar, meta);
  return li;
}

function tag(text, className) {
  const span = document.createElement("span");
  span.className = className;
  span.textContent = text;
  return span;
}

form.addEventListener("submit", (e) => {
  e.preventDefault();
  analyse();
});

textarea.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    analyse();
  }
});

textarea.addEventListener("input", updateCount);

$("clear").addEventListener("click", () => {
  textarea.value = "";
  updateCount();
  show("empty");
  textarea.focus();
});

// Opened by double-clicking index.html: there is no Prolog server behind it
if (location.protocol === "file:") {
  showError("This page needs the Tahaffuz server. Double-click start.bat in the project folder (or run: swipl server.pl), then use http://localhost:8080.");
}

// ?m=<message> pre-fills and analyses a message (handy for demos and links)
const preset = new URLSearchParams(location.search).get("m");
if (preset) {
  textarea.value = preset;
  updateCount();
  analyse();
}

for (const chip of document.querySelectorAll("[data-example]")) {
  chip.addEventListener("click", () => {
    textarea.value = chip.dataset.example;
    updateCount();
    analyse();
  });
}
