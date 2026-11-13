import os
import sys
import json
import time
import glob
import zipfile
import subprocess
import urllib.request
import urllib.error
import shutil

# Satisfy the HF spaces package GPU check (we run CPU-only; the decorator is a no-op on CPU)
try:
    import spaces
    @spaces.GPU
    def _noop_gpu():
        pass
except Exception:
    pass

import gradio as gr

# 1. Normalize any existing files that have Windows backslashes in their names on Linux
for fname in os.listdir("."):
    if "\\" in fname:
        clean = fname.replace("\\", "/")
        target_dir = os.path.dirname(clean)
        if target_dir:
            os.makedirs(target_dir, exist_ok=True)
        if not os.path.exists(clean):
            shutil.move(fname, clean)
        else:
            try:
                os.remove(fname)
            except Exception:
                pass

# 2. Auto-extract any uploaded zip files (e.g. project.zip) safely converting \ to /
for zip_file in glob.glob("*.zip"):
    try:
        with zipfile.ZipFile(zip_file, "r") as z:
            for member in z.infolist():
                clean_name = member.filename.replace("\\", "/").lstrip("/")
                if not clean_name:
                    continue
                target_path = os.path.join(".", clean_name)
                if clean_name.endswith("/"):
                    os.makedirs(target_path, exist_ok=True)
                else:
                    os.makedirs(os.path.dirname(target_path), exist_ok=True)
                    with z.open(member) as src_f, open(target_path, "wb") as dst_f:
                        dst_f.write(src_f.read())
    except Exception as e:
        print(f"Error extracting {zip_file}: {e}")

# 3. If src is nested inside a subfolder, move it to root
if not os.path.isdir("src"):
    for item in os.listdir("."):
        if os.path.isdir(item) and os.path.isdir(os.path.join(item, "src")):
            for sub in os.listdir(item):
                src_path = os.path.join(item, sub)
                dst_path = os.path.join(".", sub)
                if not os.path.exists(dst_path):
                    shutil.move(src_path, dst_path)
            break

PROLOG_PORT = int(os.environ.get("PROLOG_PORT", 8000))

# -------------------------------------------------------------
# Launch SWI-Prolog HTTP Server in Background
# -------------------------------------------------------------
def start_prolog():
    cmd = ["swipl", "server.pl", str(PROLOG_PORT)]
    print(f"Starting SWI-Prolog server: {' '.join(cmd)}")
    proc = subprocess.Popen(cmd, cwd=os.path.abspath("."))
    
    # Poll until ready
    for i in range(30):
        time.sleep(0.5)
        try:
            req = urllib.request.Request(
                f"http://127.0.0.1:{PROLOG_PORT}/api/analyse",
                data=json.dumps({"message": "ping"}).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=2) as resp:
                if resp.status == 200:
                    print("SWI-Prolog backend is online and responding!")
                    return proc
        except Exception:
            pass
    print("Warning: SWI-Prolog took longer to respond.")
    return proc

prolog_process = start_prolog()

# -------------------------------------------------------------
# UI CSS (Exact Match of the Original Tahaffuz Style)
# -------------------------------------------------------------
CUSTOM_CSS = """
:root {
  --bg: #f5f7f6;
  --card: #ffffff;
  --text: #1c2421;
  --muted: #5d6b66;
  --border: #dde4e1;
  --brand: #0f6b57;
  --safe: #1f8a4c;
  --safe-bg: #e5f4eb;
  --warn: #b26a00;
  --warn-bg: #fdf1dc;
  --scam: #c2312a;
  --scam-bg: #fbe5e3;
  --radius: 12px;
  --shadow: 0 1px 2px rgba(16, 24, 20, .06), 0 4px 16px rgba(16, 24, 20, .05);
}

body, .gradio-container {
  background: var(--bg) !important;
  color: var(--text) !important;
  font-family: "Segoe UI", system-ui, -apple-system, Roboto, "Noto Sans", Arial, sans-serif !important;
  font-size: 16px !important;
  line-height: 1.5 !important;
}

.tahaffuz-app {
  max-width: 1080px;
  margin: 0 auto;
  padding: 0 8px;
}

/* Header */
.tahaffuz-header {
  padding: 24px 0 16px 0;
  text-align: left;
}
.tahaffuz-title {
  margin: 0;
  display: flex;
  align-items: baseline;
  gap: 12px;
  flex-wrap: wrap;
  color: var(--brand);
  font-size: 2.2rem;
  line-height: 1.2;
}
.title-ur {
  font-family: "Urdu Typesetting", "Jameel Noori Nastaleeq", "Noto Nastaliq Urdu", serif;
  font-size: 2.8rem;
  font-weight: normal;
}
.title-sep { color: var(--border); font-weight: 300; }
.tahaffuz-tagline { margin: 8px 0 0; color: var(--muted); font-size: 1rem; max-width: 65ch; }

/* Cards */
.card-box {
  background: var(--card) !important;
  border: 1px solid var(--border) !important;
  border-radius: var(--radius) !important;
  box-shadow: var(--shadow) !important;
  padding: 22px !important;
}
.card-label {
  margin: 0 0 12px;
  font-size: .85rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--muted);
}

/* Textarea & Inputs */
textarea {
  width: 100% !important;
  background: #fbfcfc !important;
  border: 1px solid var(--border) !important;
  border-radius: 8px !important;
  color: var(--text) !important;
  font-family: inherit !important;
  font-size: 0.95rem !important;
}
textarea:focus {
  outline: 2px solid var(--brand) !important;
  background: #fff !important;
}

/* Buttons */
.btn-primary {
  background: var(--brand) !important;
  color: #fff !important;
  border-radius: 8px !important;
  font-weight: 600 !important;
  border: 1px solid transparent !important;
  padding: 10px 22px !important;
  cursor: pointer !important;
}
.btn-primary:hover {
  background: #0b5a49 !important;
}
.btn-ghost {
  background: transparent !important;
  color: var(--muted) !important;
  border: 1px solid var(--border) !important;
  border-radius: 8px !important;
  font-weight: 600 !important;
  padding: 10px 22px !important;
  cursor: pointer !important;
}
.btn-ghost:hover {
  color: var(--text) !important;
  border-color: var(--muted) !important;
}

/* Result Card Components */
.result-container {
  min-height: 240px;
}
.verdict-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.badge {
  display: inline-block;
  padding: 6px 16px;
  border-radius: 999px;
  font-weight: 700;
  font-size: 1.15rem;
  letter-spacing: .02em;
}
.percent {
  font-size: 1.7rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.v-safe .badge { background: var(--safe-bg); color: var(--safe); }
.v-suspicious .badge { background: var(--warn-bg); color: var(--warn); }
.v-scam .badge { background: var(--scam-bg); color: var(--scam); }

.v-safe .percent { color: var(--safe); }
.v-suspicious .percent { color: var(--warn); }
.v-scam .percent { color: var(--scam); }

/* Meter */
.meter {
  position: relative;
  height: 14px;
  margin-top: 14px;
  border-radius: 999px;
  background: #edf1ef;
  overflow: hidden;
}
.meter-fill {
  height: 100%;
  border-radius: 999px;
  transition: width .4s ease;
}
.v-safe .meter-fill { background: var(--safe); }
.v-suspicious .meter-fill { background: var(--warn); }
.v-scam .meter-fill { background: var(--scam); }

.meter-mark {
  position: absolute;
  top: 0; bottom: 0;
  width: 2px;
  background: rgba(255, 255, 255, .95);
}
.meter-scale {
  position: relative;
  height: 18px;
  margin-top: 4px;
  font-size: .75rem;
  color: var(--muted);
}
.meter-scale span { position: absolute; white-space: nowrap; }
.meter-scale span:first-child { left: 0; }
.meter-scale span[style] { transform: translateX(-50%); }
.meter-scale .end { right: 0; }

.advice {
  margin: 14px 0 0;
  font-weight: 600;
  font-size: 1rem;
  color: var(--text);
}

.note {
  margin: 12px 0 0;
  padding: 10px 12px;
  border-left: 4px solid var(--warn);
  background: var(--warn-bg);
  border-radius: 6px;
  font-size: .92rem;
  color: #78350f;
}

/* Diagnosis */
.diagnosis, .tips {
  margin: 0;
  padding: 0;
  list-style: none;
  display: grid;
  gap: 8px;
}
.diagnosis li {
  display: grid;
  gap: 2px;
  padding: 10px 12px;
  border-radius: 8px;
  background: #f3f6f5;
}
.v-scam .diagnosis li { background: var(--scam-bg); }
.v-suspicious .diagnosis li { background: var(--warn-bg); }
.diagnosis-desc { color: var(--muted); font-size: .9rem; }
.tag.tag-main {
  margin-left: 8px;
  font-size: .72rem;
  font-weight: 600;
  vertical-align: middle;
}

/* Tips */
.tips li {
  position: relative;
  padding-left: 22px;
  font-size: .95rem;
  color: var(--text);
}
.tips li::before {
  content: "✓";
  position: absolute;
  left: 2px;
  color: var(--brand);
  font-weight: 700;
}

/* Reasons */
.reasons-title {
  margin: 20px 0 8px;
  font-size: .85rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--muted);
}
.reasons {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 10px;
}
.reason {
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 12px;
  background: #fff;
}
.reason-top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: baseline;
}
.reason-text { font-weight: 600; color: var(--text); font-size: 0.95rem; }
.reason-plus {
  font-variant-numeric: tabular-nums;
  font-weight: 700;
  white-space: nowrap;
  color: var(--brand);
}
.v-scam .reason-plus { color: var(--scam); }

.reason-bar {
  height: 4px;
  margin: 8px 0;
  background: #edf1ef;
  border-radius: 999px;
  overflow: hidden;
}
.reason-bar > div {
  height: 100%;
  background: var(--brand);
  border-radius: 999px;
}
.v-scam .reason-bar > div { background: var(--scam); }
.v-suspicious .reason-bar > div { background: var(--warn); }

.reason-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  font-size: .82rem;
  color: var(--muted);
}
.tag {
  padding: 1px 8px;
  border-radius: 999px;
  background: #eef3f1;
  color: var(--text);
  font-family: Consolas, monospace;
  font-size: .8rem;
}
.tag-action {
  background: var(--scam-bg);
  color: var(--scam);
  font-family: inherit;
  font-weight: 600;
}

/* Footer */
.tahaffuz-footer {
  margin-top: 28px;
  padding: 16px 0 32px 0;
  border-top: 1px solid var(--border);
  color: var(--muted);
  font-size: .88rem;
}
.tahaffuz-footer p { margin: 6px 0; }
.tahaffuz-footer code {
  font-family: Consolas, monospace;
  background: #eef3f1;
  padding: 1px 5px;
  border-radius: 4px;
}
"""

ACTION_INDICATORS = {
    "otp_request", "credential_request", "send_money",
    "suspicious_domain", "personal_number_bait"
}

# -------------------------------------------------------------
# Analysis Handler (Matching Original JavaScript Render Logic)
# -------------------------------------------------------------
def analyse_message(message):
    if not message or not message.strip():
        return """
        <div class="result-container" style="color: var(--muted); padding: 32px 0; text-align: center;">
          <p>Please enter or paste a message to analyse.</p>
        </div>
        """
    
    if len(message) > 5000:
        return f"""
        <div class="result-container" style="color: var(--scam); background: var(--scam-bg); padding: 12px 16px; border-radius: 8px;">
          <p>The message is too long ({len(message)} characters, limit 5000).</p>
        </div>
        """
    
    try:
        req = urllib.request.Request(
            f"http://127.0.0.1:{PROLOG_PORT}/api/analyse",
            data=json.dumps({"message": message}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return f"""
        <div class="result-container" style="color: var(--scam); background: var(--scam-bg); padding: 12px 16px; border-radius: 8px;">
          <p>Unable to connect to the Prolog reasoning engine: {e}</p>
        </div>
        """

    verdict_raw = data.get("verdict", "safe").lower()
    verdict_label = {"safe": "Safe", "suspicious": "Suspicious", "scam": "Scam"}.get(verdict_raw, verdict_raw.capitalize())
    percent = int(data.get("percent", 0))
    score = float(data.get("score", 0.0))
    action_text = data.get("action", {}).get("text", "")
    note = data.get("note", "")
    diagnosis_list = data.get("diagnosis", [])
    advice_list = data.get("advice", [])
    reasons = data.get("reasons", [])

    html = []
    html.append(f'<div class="result-container v-{verdict_raw}">')

    # 1. Verdict & Percentage Row
    html.append(f"""
      <div class="verdict-row">
        <span class="badge">{verdict_label}</span>
        <span class="percent">{percent}%</span>
      </div>
    """)

    # 2. Confidence Meter Bar
    html.append(f"""
      <div class="meter" aria-hidden="true">
        <div class="meter-fill" style="width: {percent}%;"></div>
        <div class="meter-mark" style="left: 40%;"></div>
        <div class="meter-mark" style="left: 70%;"></div>
      </div>
      <div class="meter-scale" aria-hidden="true">
        <span>0</span>
        <span style="left: 40%;">40 Suspicious</span>
        <span style="left: 70%;">70 Scam</span>
        <span class="end">100</span>
      </div>
    """)

    # 3. Action Advice
    if action_text:
        html.append(f'<p class="advice">{action_text}</p>')

    # 4. Note (if gate meta-rule capped the verdict)
    if note:
        html.append(f'<div class="note">{note}</div>')

    # 5. Diagnosis Section
    if diagnosis_list:
        html.append('<h3 class="reasons-title">Diagnosis</h3>')
        html.append('<ul class="diagnosis">')
        for i, d in enumerate(diagnosis_list):
            is_main = (i == 0 and len(diagnosis_list) > 1)
            main_tag = '<span class="tag tag-main">main</span>' if is_main else ''
            html.append(f"""
              <li>
                <strong>{d.get('name', '')} {main_tag}</strong>
                <span class="diagnosis-desc">{d.get('description', '')}</span>
              </li>
            """)
        html.append('</ul>')

    # 6. What to do (Advice List)
    if advice_list:
        html.append('<h3 class="reasons-title">What to do</h3>')
        html.append('<ul class="tips">')
        for tip in advice_list:
            html.append(f'<li>{tip}</li>')
        html.append('</ul>')

    # 7. Why (Rule Breakdown)
    html.append('<h3 class="reasons-title">Why</h3>')
    if not reasons:
        html.append('<p style="color: var(--muted); font-size: 0.9rem;">No scam indicators found in this message.</p>')
    else:
        html.append('<ol class="reasons">')
        for r in reasons:
            contrib = float(r.get("contribution", 0.0))
            contrib_pct = round(contrib * 100)
            reason_text = r.get("reason", "")
            cf = float(r.get("cf", 0.0))
            matched = r.get("matched", [])
            bar_pct = (contrib / score * 100) if score > 0 else 0

            action_tag = '<span class="tag tag-action">direct request</span>' if r.get("indicator") in ACTION_INDICATORS else ''
            
            matched_html = ""
            if matched:
                matched_tags = "".join([f'<span class="tag">{w}</span>' for w in matched])
                matched_html = f" · matched: {matched_tags}"

            html.append(f"""
              <li class="reason">
                <div class="reason-top">
                  <span class="reason-text">{reason_text}</span>
                  <span class="reason-plus">+{contrib_pct}%</span>
                </div>
                <div class="reason-bar">
                  <div style="width: {bar_pct:.1f}%;"></div>
                </div>
                <div class="reason-meta">
                  <span>CF {cf:.2f}</span>
                  {action_tag}
                  {matched_html}
                </div>
              </li>
            """)
        html.append('</ol>')

    html.append('</div>')
    return "\n".join(html)

EMPTY_STATE_HTML = """
<div class="result-container" style="color: var(--muted); padding: 32px 0; text-align: center;">
  <p>Your result will appear here.</p>
</div>
"""

# -------------------------------------------------------------
# Gradio Interface
# -------------------------------------------------------------
examples = [
    ["Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP."],
    ["Mubarak ho! Aap ne 50,000 inaam jeet liya hai. Inaam hasil karne ke liye 500 rupay processing fee 03001234567 par bhejein."],
    ["Your Ehsaas aid of Rs. 25000 has been approved. Contact Bilal Raza on WhatsApp at 0344-5678901 to receive it."],
    ["Dear customer, enjoy 20% off this weekend. Limited time offer, act now!"],
    ["Your OTP is 4821. Do not share it with anyone."],
    ["Send me your account number, I'll transfer your share of the trip money."]
]

with gr.Blocks(title="Tahaffuz — Scam Message Checker", css=CUSTOM_CSS) as demo:
    with gr.Column(elem_classes=["tahaffuz-app"]):
        
        # Header
        gr.HTML("""
        <header class="tahaffuz-header">
          <h1 class="tahaffuz-title">
            <span class="title-ur" lang="ur" dir="rtl">تحفظ</span>
            <span class="title-sep" aria-hidden="true">/</span>
            <span class="title-en">Tahaffuz</span>
          </h1>
          <p class="tahaffuz-tagline">Paste an SMS, WhatsApp message or link. Tahaffuz tells you if it looks like a scam, and why.</p>
        </header>
        """)
        
        with gr.Row(equal_height=False):
            # Left Column (Input)
            with gr.Column(elem_classes=["card-box"]):
                gr.HTML('<h2 class="card-label">Message</h2>')
                msg_input = gr.Textbox(
                    placeholder="e.g. Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP.",
                    lines=6,
                    max_lines=12,
                    show_label=False
                )
                with gr.Row():
                    analyse_btn = gr.Button("Analyse", elem_classes=["btn-primary"], scale=2)
                    clear_btn = gr.Button("Clear", elem_classes=["btn-ghost"], scale=1)
                
                gr.HTML('<div style="margin-top: 16px; border-top: 1px solid var(--border); padding-top: 14px;"><p class="card-label" style="margin-bottom: 8px;">Try an example:</p></div>')
                gr.Examples(
                    examples=examples,
                    inputs=msg_input,
                    label=""
                )

            # Right Column (Result)
            with gr.Column(elem_classes=["card-box"]):
                gr.HTML('<h2 class="card-label">Result</h2>')
                output_html = gr.HTML(value=EMPTY_STATE_HTML)

        # Wire actions
        analyse_btn.click(fn=analyse_message, inputs=msg_input, outputs=output_html)
        msg_input.submit(fn=analyse_message, inputs=msg_input, outputs=output_html)
        clear_btn.click(fn=lambda: ("", EMPTY_STATE_HTML), outputs=[msg_input, output_html])

        # Footer
        gr.HTML("""
        <footer class="tahaffuz-footer">
          <p>
            Rule-based expert system (no machine learning). Each indicator has a certainty factor (CF);
            they are combined with the MYCIN formula <code>CF = CF₁ + CF₂ × (1 − CF₁)</code>.
            A <strong>Scam</strong> verdict needs at least one direct request (OTP, details, money, a personal number or a fake site).
          </p>
          <p style="color: var(--muted); font-size: 0.82rem; margin-top: 8px;">NED University · Introduction to AI · Tahaffuz</p>
        </footer>
        """)

if __name__ == "__main__":
    demo.launch()
