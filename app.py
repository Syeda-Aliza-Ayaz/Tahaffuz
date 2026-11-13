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
            print(f"Fixed Windows path file: {fname} -> {clean}")
        else:
            try:
                os.remove(fname)
            except Exception:
                pass

# 2. Auto-extract any uploaded zip files (e.g. project.zip) safely converting \ to /
for zip_file in glob.glob("*.zip"):
    try:
        print(f"Extracting {zip_file}...")
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
        print(f"Extracted {zip_file} successfully.")
    except Exception as e:
        print(f"Error extracting {zip_file}: {e}")

# 3. If src is nested inside a subfolder (e.g. "IAI Project/src"), move it to root
if not os.path.isdir("src"):
    for item in os.listdir("."):
        if os.path.isdir(item) and os.path.isdir(os.path.join(item, "src")):
            print(f"Found nested folder: '{item}'. Moving contents to root...")
            for sub in os.listdir(item):
                src_path = os.path.join(item, sub)
                dst_path = os.path.join(".", sub)
                if not os.path.exists(dst_path):
                    shutil.move(src_path, dst_path)
                    print(f"Moved {src_path} -> {dst_path}")
            break

print("App working directory:", os.getcwd())
if os.path.isdir("src"):
    print("Found src folder containing:", os.listdir("src"))
else:
    print("WARNING: src folder was not found! Current directory listing:", os.listdir("."))

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
# Analyse Function
# -------------------------------------------------------------
def analyse_message(message):
    if not message or not message.strip():
        return "<div style='color: #ef4444; padding: 12px;'>Please enter or paste a message to analyse.</div>"
    
    if len(message) > 5000:
        return f"<div style='color: #ef4444; padding: 12px;'>Message is too long ({len(message)} characters, max 5000).</div>"
    
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
        return f"<div style='color: #ef4444; padding: 12px;'>Error connecting to Prolog backend: {e}</div>"

    verdict = data.get("verdict", "SAFE")
    percent = data.get("percent", 0)
    score = data.get("score", 0.0)
    action = data.get("action", {})
    action_text = action.get("text", "")
    advice_list = data.get("advice", [])
    diagnosis_list = data.get("diagnosis", [])
    reasons = data.get("reasons", [])
    capped = data.get("capped", False)
    note = data.get("note", "")

    # Verdict Colors
    if verdict == "SCAM":
        badge_bg = "#fee2e2"
        badge_border = "#ef4444"
        badge_text = "#991b1b"
        meter_fill = "#ef4444"
        icon = "🚨"
    elif verdict == "SUSPICIOUS":
        badge_bg = "#fef3c7"
        badge_border = "#f59e0b"
        badge_text = "#92400e"
        meter_fill = "#f59e0b"
        icon = "⚠️"
    else:
        badge_bg = "#dcfce7"
        badge_border = "#22c55e"
        badge_text = "#166534"
        meter_fill = "#22c55e"
        icon = "✅"

    # HTML Output
    html = []
    html.append(f"""
    <div style="font-family: system-ui, -apple-system, sans-serif; line-height: 1.5; color: #1e293b;">
        <!-- Verdict Card -->
        <div style="background: {badge_bg}; border: 2px solid {badge_border}; border-radius: 12px; padding: 16px 20px; margin-bottom: 20px;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
                <div style="font-size: 24px; font-weight: 800; color: {badge_text}; letter-spacing: 0.5px;">
                    {icon} {verdict}
                </div>
                <div style="font-size: 20px; font-weight: 700; color: {badge_text};">
                    Confidence: {percent}%
                </div>
            </div>
            
            <!-- Meter Bar -->
            <div style="background: rgba(0,0,0,0.1); height: 10px; border-radius: 5px; margin: 12px 0 6px 0; overflow: hidden; position: relative;">
                <div style="background: {meter_fill}; width: {percent}%; height: 100%; border-radius: 5px; transition: width 0.4s ease;"></div>
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 11px; color: #64748b;">
                <span>0 Safe</span>
                <span>40 Suspicious</span>
                <span>70 Scam</span>
                <span>100</span>
            </div>
        </div>
    """)

    if note:
        html.append(f"""
        <div style="background: #eff6ff; border-left: 4px solid #3b82f6; padding: 10px 14px; margin-bottom: 16px; border-radius: 4px; font-size: 13px; color: #1e40af;">
            ℹ️ {note}
        </div>
        """)

    # Recommended Action
    if action_text:
        html.append(f"""
        <div style="margin-bottom: 18px;">
            <div style="font-size: 14px; font-weight: 700; color: #334155; text-transform: uppercase; margin-bottom: 6px;">Recommended Action</div>
            <div style="font-size: 15px; font-weight: 600; color: {badge_text};">{action_text}</div>
        </div>
        """)

    # Diagnosis if present
    if diagnosis_list:
        html.append("""
        <div style="margin-bottom: 18px;">
            <div style="font-size: 14px; font-weight: 700; color: #334155; text-transform: uppercase; margin-bottom: 8px;">Diagnosis</div>
        """)
        for d in diagnosis_list:
            html.append(f"""
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px 14px; margin-bottom: 6px;">
                <div style="font-weight: 700; color: #0f172a;">{d.get('name', '')}</div>
                <div style="font-size: 13px; color: #475569; margin-top: 2px;">{d.get('description', '')}</div>
            </div>
            """)
        html.append("</div>")

    # What to do (Advice)
    if advice_list:
        html.append("""
        <div style="margin-bottom: 18px;">
            <div style="font-size: 14px; font-weight: 700; color: #334155; text-transform: uppercase; margin-bottom: 6px;">Safety Tips</div>
            <ul style="margin: 0; padding-left: 20px; font-size: 14px; color: #334155;">
        """)
        for tip in advice_list:
            html.append(f"<li style='margin-bottom: 4px;'>{tip}</li>")
        html.append("</ul></div>")

    # Why (Reasons breakdown)
    html.append("""
    <div>
        <div style="font-size: 14px; font-weight: 700; color: #334155; text-transform: uppercase; margin-bottom: 8px;">Why (Rule Contributions)</div>
    """)
    if not reasons:
        html.append("<div style='font-size: 13px; color: #64748b;'>No scam indicators triggered.</div>")
    else:
        html.append("<div style='display: flex; flex-direction: column; gap: 8px;'>")
        for r in reasons:
            contrib = r.get("contribution", 0)
            reason_text = r.get("reason", "")
            matched = r.get("matched", [])
            matched_str = ", ".join(matched) if matched else "none"
            html.append(f"""
            <div style="background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 10px 14px;">
                <div style="display: flex; justify-content: space-between; align-items: baseline;">
                    <span style="font-size: 14px; font-weight: 600; color: #1e293b;">{reason_text}</span>
                    <span style="font-size: 13px; font-weight: 700; color: #dc2626; margin-left: 10px;">+{contrib:.2f} CF</span>
                </div>
                <div style="font-size: 12px; color: #64748b; margin-top: 4px;">
                    Matched keywords: <code style="background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 11px;">{matched_str}</code>
                </div>
            </div>
            """)
        html.append("</div>")

    html.append("</div></div>")
    return "\n".join(html)

# -------------------------------------------------------------
# Gradio UI Design
# -------------------------------------------------------------
examples = [
    ["Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP."],
    ["Mubarak ho! Aap ne 50,000 inaam jeet liya hai. Inaam hasil karne ke liye 500 rupay processing fee 03001234567 par bhejein."],
    ["Your Ehsaas aid of Rs. 25000 has been approved. Contact Bilal Raza on WhatsApp at 0344-5678901 to receive it."],
    ["Dear customer, enjoy 20% off this weekend. Limited time offer, act now!"],
    ["Your OTP is 4821. Do not share it with anyone."],
    ["Send me your account number, I'll transfer your share of the trip money."]
]

with gr.Blocks(title="Tahaffuz — Scam Detector") as demo:
    gr.HTML("""
    <div style="text-align: center; padding: 10px 0 16px 0;">
        <h1 style="margin: 0; font-size: 28px; font-weight: 800;">
            <span lang="ur" dir="rtl" style="font-family: 'Noto Nastaliq Urdu', serif; color: #1e293b;">تحفظ</span>
            <span style="color: #94a3b8; font-weight: 300; margin: 0 8px;">/</span>
            <span>Tahaffuz</span>
        </h1>
        <p style="margin: 6px 0 0 0; color: #64748b; font-size: 14px;">
            Explainable Expert System for Scam & Phishing Detection in English & Roman Urdu
        </p>
    </div>
    """)
    
    with gr.Row():
        with gr.Column(scale=1):
            msg_input = gr.Textbox(
                label="Message to analyse",
                placeholder="Paste an SMS, email or WhatsApp message here...",
                lines=5,
                max_lines=10
            )
            with gr.Row():
                clear_btn = gr.Button("Clear", variant="secondary")
                analyse_btn = gr.Button("Analyse Message", variant="primary")
            
            gr.Examples(
                examples=examples,
                inputs=msg_input,
                label="Try an example message"
            )

        with gr.Column(scale=1):
            gr.Markdown("### 📋 Analysis Result")
            output_html = gr.HTML(
                value="<div style='color: #94a3b8; padding: 20px; text-align: center; border: 1px dashed #cbd5e1; border-radius: 8px;'>Your analysis result will appear here.</div>"
            )

    analyse_btn.click(fn=analyse_message, inputs=msg_input, outputs=output_html)
    msg_input.submit(fn=analyse_message, inputs=msg_input, outputs=output_html)
    clear_btn.click(fn=lambda: ("", "<div style='color: #94a3b8; padding: 20px; text-align: center; border: 1px dashed #cbd5e1; border-radius: 8px;'>Your analysis result will appear here.</div>"), outputs=[msg_input, output_html])

    with gr.Accordion("ℹ️ How it works (Viva / Project Details)", open=False):
        gr.Markdown("""
        - **Reasoning Engine:** MYCIN-style Certainty Factor combination formula:
          $$\\text{CF} = \\text{CF}_1 + \\text{CF}_2 \\times (1 - \\text{CF}_1)$$
        - **Matching:** Pattern and keyword/phrase matching across English and Roman Urdu (no black-box machine learning or LLMs).
        - **Safety Gates:** A **SCAM** verdict strictly requires at least one actionable ask (OTP, credentials, money, or impersonated links).
        - **Backend:** SWI-Prolog HTTP engine running knowledge bases (`kb.pl`, `matcher.pl`, `diagnosis.pl`).
        """)

if __name__ == "__main__":
    demo.launch(theme=gr.themes.Soft())

