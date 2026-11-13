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
:root, .gradio-container, .dark, body {
  --bg: #f5f7f6;
  --card: #ffffff;
  --text: #1c2421;
  --muted: #4b5563;
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

  /* Gradio theme variable overrides (prevent washed out white-on-white text) */
  --body-text-color: #1c2421 !important;
  --body-background-fill: #f5f7f6 !important;
  --background-fill-primary: #ffffff !important;
  --background-fill-secondary: #fbfcfc !important;
  --block-background-fill: #ffffff !important;
  --block-label-text-color: #374151 !important;
  --block-title-text-color: #111827 !important;
  --input-background-fill: #fbfcfc !important;
  --input-border-color: #dde4e1 !important;
  --input-text-color: #111827 !important;
}

body, .gradio-container {
  background: #f5f7f6 !important;
  background-color: #f5f7f6 !important;
  color: #1c2421 !important;
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
.tahaffuz-title, .tahaffuz-title span {
  margin: 0;
  color: #0f6b57 !important;
  font-size: 2.2rem;
  line-height: 1.2;
}
.title-ur {
  font-family: "Urdu Typesetting", "Jameel Noori Nastaleeq", "Noto Nastaliq Urdu", serif !important;
  font-size: 2.8rem !important;
  font-weight: normal;
  color: #0f6b57 !important;
}
.title-en {
  color: #0f6b57 !important;
  font-weight: 700;
}
.title-sep { color: #9ca3af !important; font-weight: 300; margin: 0 6px; }
.tahaffuz-tagline { margin: 8px 0 0; color: #4b5563 !important; font-size: 1rem; max-width: 65ch; }

/* Cards */
.card-box {
  background: #ffffff !important;
  background-color: #ffffff !important;
  border: 1px solid #dde4e1 !important;
  border-radius: 12px !important;
  box-shadow: 0 1px 2px rgba(16, 24, 20, .06), 0 4px 16px rgba(16, 24, 20, .05) !important;
  padding: 22px !important;
}
.card-label {
  margin: 0 0 12px !important;
  font-size: .85rem !important;
  font-weight: 700 !important;
  text-transform: uppercase !important;
  letter-spacing: .06em !important;
  color: #374151 !important;
}

/* Textarea & Inputs */
.gradio-container .block,
.gradio-container .form,
.gradio-container fieldset {
  border: none !important;
  box-shadow: none !important;
  background: transparent !important;
  padding: 0 !important;
}

textarea {
  width: 100% !important;
  background: #fbfcfc !important;
  border: 1px solid #dde4e1 !important;
  border-radius: 8px !important;
  color: #111827 !important;
  font-family: inherit !important;
  font-size: 0.95rem !important;
}
textarea:focus {
  outline: 2px solid #0f6b57 !important;
  border-color: #0f6b57 !important;
  background: #fff !important;
}

/* Buttons */
.btn-primary {
  background: #0f6b57 !important;
  background-color: #0f6b57 !important;
  color: #ffffff !important;
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
  color: #4b5563 !important;
  border: 1px solid #dde4e1 !important;
  border-radius: 8px !important;
  font-weight: 600 !important;
  padding: 10px 22px !important;
  cursor: pointer !important;
}
.btn-ghost:hover {
  color: #111827 !important;
  border-color: #9ca3af !important;
}

/* Examples */
.gradio-container .examples {
  margin-top: 12px !important;
}
.gradio-container .examples button,
.gradio-container .examples div[role="button"] {
  border-radius: 999px !important;
  border: 1px solid #dde4e1 !important;
  background: #ffffff !important;
  color: #1f2937 !important;
  font-size: 0.85rem !important;
  font-weight: 500 !important;
}
.gradio-container .examples button:hover {
  border-color: #0f6b57 !important;
  color: #0f6b57 !important;
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

.v-safe .badge { background: #e5f4eb !important; color: #1f8a4c !important; }
.v-suspicious .badge { background: #fdf1dc !important; color: #b26a00 !important; }
.v-scam .badge { background: #fbe5e3 !important; color: #c2312a !important; }

.v-safe .percent { color: #1f8a4c !important; }
.v-suspicious .percent { color: #b26a00 !important; }
.v-scam .percent { color: #c2312a !important; }

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
.v-safe .meter-fill { background: #1f8a4c !important; }
.v-suspicious .meter-fill { background: #b26a00 !important; }
.v-scam .meter-fill { background: #c2312a !important; }

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
  color: #4b5563 !important;
}
.meter-scale span { position: absolute; white-space: nowrap; color: #4b5563 !important; }
.meter-scale span:first-child { left: 0; }
.meter-scale span[style] { transform: translateX(-50%); }
.meter-scale .end { right: 0; }

.advice {
  margin: 14px 0 0;
  font-weight: 600;
  font-size: 1rem;
  color: #111827 !important;
}

.note {
  margin: 12px 0 0;
  padding: 10px 12px;
  border-left: 4px solid #b26a00;
  background: #fdf1dc;
  border-radius: 6px;
  font-size: .92rem;
  color: #78350f !important;
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
  color: #111827 !important;
}
.v-scam .diagnosis li { background: #fbe5e3 !important; }
.v-suspicious .diagnosis li { background: #fdf1dc !important; }
.diagnosis-desc { color: #4b5563 !important; font-size: .9rem; }
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
  color: #111827 !important;
}
.tips li::before {
  content: "✓";
  position: absolute;
  left: 2px;
  color: #0f6b57;
  font-weight: 700;
}

/* Reasons */
.reasons-title {
  margin: 20px 0 8px;
  font-size: .85rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #374151 !important;
}
.reasons {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 10px;
}
.reason {
  border: 1px solid #dde4e1 !important;
  border-radius: 8px;
  padding: 10px 12px;
  background: #ffffff !important;
}
.reason-top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: baseline;
}
.reason-text { font-weight: 600; color: #111827 !important; font-size: 0.95rem; }
.reason-plus {
  font-variant-numeric: tabular-nums;
  font-weight: 700;
  white-space: nowrap;
  color: #0f6b57 !important;
}
.v-scam .reason-plus { color: #c2312a !important; }

.reason-bar {
  height: 4px;
  margin: 8px 0;
  background: #edf1ef;
  border-radius: 999px;
  overflow: hidden;
}
.reason-bar > div {
  height: 100%;
  background: #0f6b57;
  border-radius: 999px;
}
.v-scam .reason-bar > div { background: #c2312a; }
.v-suspicious .reason-bar > div { background: #b26a00; }

.reason-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  font-size: .82rem;
  color: #4b5563 !important;
}
.tag {
  padding: 1px 8px;
  border-radius: 999px;
  background: #eef3f1 !important;
  color: #111827 !important;
  font-family: Consolas, monospace;
  font-size: .8rem;
}
.tag-action {
  background: #fbe5e3 !important;
  color: #c2312a !important;
  font-family: inherit;
  font-weight: 600;
}

/* Footer */
.tahaffuz-footer {
  margin-top: 28px;
  padding: 16px 0 32px 0;
  border-top: 1px solid #dde4e1;
  color: #4b5563 !important;
  font-size: .88rem;
}
.tahaffuz-footer p { margin: 6px 0; color: #4b5563 !important; }
.tahaffuz-footer code {
  font-family: Consolas, monospace;
  background: #eef3f1;
  padding: 1px 5px;
  border-radius: 4px;
  color: #111827 !important;
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
<div class="result-container" style="color: #4b5563 !important; padding: 48px 0; text-align: center;">
  <p style="color: #4b5563 !important; font-size: 1rem; margin: 0;">Your result will appear here.</p>
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

with gr.Blocks(title="Tahaffuz — Scam Message Checker", css=CUSTOM_CSS, theme=gr.themes.Default(primary_hue="emerald")) as demo:
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
