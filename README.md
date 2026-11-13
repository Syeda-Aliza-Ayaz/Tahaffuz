---
title: Tahaffuz
emoji: 🛡️
colorFrom: red
colorTo: indigo
sdk: gradio
app_file: app.py
pinned: false
---

# Tahaffuz <span lang="ur" dir="rtl">تحفظ</span>

An explainable expert system that detects scam / phishing messages (SMS, email text, links)
in English and Roman Urdu, and explains **why** it reached its verdict.

- **Reasoning:** MYCIN-style certainty factors (no machine learning)
- **Matching:** keyword / phrase matching (no NLP)
- **Backend:** SWI-Prolog HTTP server · **Frontend:** plain HTML / CSS / JS (no frameworks, works offline)

> **Viva preparation guide:** https://claude.ai/artifact/WbfoyUjTLmWY95Uwa1zQVR
> (everything we built, why, and the IAI concepts, plus likely viva questions and answers)

---

## 1. Requirements

- **SWI-Prolog 9 or newer** (developed on 10.1.14) — https://www.swi-prolog.org/download/stable
- Nothing else. No npm, no Python, no internet needed after install.

### Make `swipl` available (Windows, one-time)

SWI-Prolog installs to `C:\Program Files\swipl\bin` but may not be on PATH. Either:

- **Add it to PATH:** Start → "Edit the system environment variables" → Environment Variables →
  *Path* → New → `C:\Program Files\swipl\bin` → OK, then reopen the terminal; **or**
- **Use the full path** in every command below, e.g.
  `& "C:\Program Files\swipl\bin\swipl.exe" load.pl`

Check it works:

```powershell
swipl --version
```

All commands below are run from the project folder (`IAI Project`).

---

## 2. Run it (console)

```powershell
swipl load.pl
```

Then, at the `?-` prompt (strings in double quotes, every query ends with a full stop):

```prolog
?- explain("Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP.").
```

Output:

```
Verdict: SCAM   (confidence 99%)
Reasons (strongest first):
  +0.85  Asks you to share your OTP / PIN  [CF 0.85]
          matched: send, otp
  +0.10  Claims your account is blocked or suspended  [CF 0.70]
          matched: blocked
  ...
```

More to try:

```prolog
?- explain("Apna OTP code humein foran bhejein").                 % Roman Urdu scam
?- explain("Your OTP is 4821. Do not share it with anyone.").     % genuine -> SAFE
?- explain("Reminder: your electricity bill of Rs 3,200 is due."). % genuine -> SAFE
```

Get the raw result instead of the printed report:

```prolog
?- analyse("Pay Rs 500 fee at tinyurl.com/x", Score, Verdict, Reasons).
```

`Reasons` is a list of `reason(Indicator, CF, Contribution, ReasonText, MatchedWords)`.

Leave the console with `?- halt.`

---

## 3. Run the web app

**Easiest:** double-click **`start.bat`** in the project folder. It starts the Prolog server in its own
window and opens the app in your browser. Close the *Tahaffuz server* window to stop it.

Or from a terminal:

```powershell
swipl server.pl            # or: swipl server.pl 9000  for another port
```

Then open **http://localhost:8080** in a browser. Stop the server with `Ctrl+C` (then `e` to exit if Prolog asks).

> Double-clicking `web/index.html` on its own doesn't work: the page is only the front end, and the
> analysis runs in Prolog, so the server has to be running.

- Paste a message and press **Analyse** (or `Ctrl+Enter`), or click one of the example buttons.
- The result shows the verdict, a confidence meter (its colour follows the verdict), a plain-language
  piece of advice, the gate note when a score was capped, and every reason with its CF, contribution
  and matched words. *Direct request* tags mark the action indicators.
- **Demo links:** `http://localhost:8080/?m=<message>` pre-fills and analyses a message, e.g.
  `http://localhost:8080/?m=Send%20your%20OTP%20now`.

The server is bound to `localhost` only, so nobody else on the network can reach it.

### API

```
POST /api/analyse
Content-Type: application/json

{ "message": "Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP." }
```

```json
{
  "verdict": "scam", "score": 0.99, "percent": 99, "capped": false,
  "reasons": [
    { "indicator": "otp_request", "cf": 0.85, "contribution": 0.85,
      "reason": "Asks you to share your OTP / PIN", "matched": ["send", "otp"] }
  ]
}
```

When the gate rule lowered the verdict, `capped` is `true` and a `note` field explains why.
Errors return status `400` with `{ "error": "..." }` (missing/invalid JSON, empty message, over 5,000 characters).

Try it from PowerShell:

```powershell
Invoke-RestMethod -Uri http://localhost:8080/api/analyse -Method Post -ContentType "application/json" -Body '{"message":"Send your OTP now"}'
```

---

## 4. Test it

### 4.1 Unit tests + labelled message set

```powershell
swipl tests/run_tests.pl
```

This prints:

1. **84 unit tests** (plunit), e.g. "`pin` doesn't match *shopping*", "*do not share your OTP* doesn't fire",
   MYCIN fold `0.85, 0.6, 0.5 → 0.97`, band edges, gate rule. Expected: `All 84 tests passed`.
2. **A results table** for all 88 messages in `tests/messages.pl`, with verdict, score and which
   indicators fired. Any message whose result isn't `ok` is the one to look at.
3. **A summary** for the *tune* set and the *holdout* set.

How results are scored:

| Message is… | `scam` verdict | `suspicious` | `safe` |
|---|---|---|---|
| scam | ✅ ok | soft miss | miss |
| genuine | ❌ false positive (worst) | soft FP | ✅ ok |

**Holdout rule:** messages marked `holdout` must never be used to decide a keyword or CF change.
Only look at the tune set when tuning; check holdout at the end.

### 4.2 Real-world datasets

```powershell
swipl tests/eval_corpus.pl <corpus> [summary | count]
```

| Corpus | Dataset | Role |
|---|---|---|
| `uci` | UCI SMS Spam Collection — 5,574 real SMS, English (`data/uci/`) | False-positive check. Used once while tuning (urgency CF). |
| `pksms` | Pakistan SMS Classification — 4,895 SMS, English, partly LLM-paraphrased (`data/pk_sms/`) | **Dev set** — its misses were read and used to improve the rules |
| `zenodo` | Roman Urdu Phishing SMS — 1,000 SMS, Pakistani, likely template-generated (`data/zenodo_ru/`) | **Final test** — never read, summary only |
| `mendeley` | Mendeley SMS Phishing — 5,971 SMS, Western (`data/mendeley/`) | **Final test (outside Pakistan)** — never read, summary only |

Modes: no mode = full report with example messages · `summary` = numbers only, never shows message text
(use this for the final-test sets) · `count` = only checks the file loads.

Read the numbers the right way: *spam* is mostly marketing, not fraud, so Tahaffuz rating it Safe is expected.
The useful numbers are the **ham false-positive rate** and the **smishing detection rate**.

> **Rule:** never change the knowledge base because of a `zenodo` or `mendeley` result, and never run them
> without `summary` — otherwise they stop being fair tests.

**Results (27 Oct 2026, rules frozen):**

| Set | Genuine rated Safe | Scam rated Scam | Scam flagged (Suspicious or Scam) |
|---|---|---|---|
| Own tune set (36 scam / 40 genuine) | 40 / 40 | 32 / 36 | 36 / 36 |
| Own holdout (6 / 6) | 5 / 6 (1 suspicious) | 6 / 6 | 6 / 6 |
| UCI (4,827 ham) | **100 %** | – | – |
| pksms — dev (2,504 ham / 1,111 fraud) | **100 %** | 36.1 % | 89.4 % |
| **zenodo — final test** (595 ham / 405 phishing) | 97.8 % (13 suspicious, **0 scam**) | 8.9 % | **82.2 %** |
| **mendeley — final test** (4,844 ham / 638 smishing) | **100 %** | 0 % | 37.6 % |

Across all four corpora (~12,770 genuine messages, UCI and Mendeley overlap), **no genuine message was rated Scam**.

### 4.3 Add your own test message

Add one line to `tests/messages.pl`:

```prolog
test_message(g23, genuine, tune, en, "Your text here").
%            id   label    set   lang
```

`label` = `scam` | `genuine`, `set` = `tune` | `holdout`, `lang` = `en` | `ur`. Then rerun `swipl tests/run_tests.pl`.

---

## 5. Change the knowledge base

Everything the system knows is in `src/kb.pl` (facts only).

**Add a trigger word to an existing indicator** — one line:

```prolog
keyword(urgency, "turant").
```

A keyword with a space is a phrase; without a space it must match a whole word.

**Add a new indicator** — two steps:

```prolog
indicator(fake_job, 0.50, 'Offers a job that sounds too easy').   % 1. name, CF, reason
keyword(fake_job, "work from home").                              % 2. its keywords
```

Add `action_indicator(fake_job).` only if the message *directly asks for something of value*
(only action indicators can push a verdict to Scam — see the gate rule below).

After any change, rerun `swipl tests/run_tests.pl` and check nothing that was `ok` broke.

---

## 6. How it decides (short version)

1. **Match** — the message is lowercased and split into sentences and words; each indicator's rule
   checks for its keywords, links, request patterns, etc. (`src/matcher.pl`)
2. **Combine** — CFs of fired indicators are combined with the MYCIN formula
   `CF = CF1 + CF2 × (1 − CF1)` (`src/inference.pl`)
3. **Band** — `< 0.40` Safe · `0.40–0.69` Suspicious · `≥ 0.70` Scam
4. **Gate** — Scam only if at least one *action* indicator fired (asks for OTP, details, money,
   a personal number, or links to a fake brand site); otherwise capped at Suspicious
5. **Diagnose** — diagnosis rules name the kind of scam from the indicators that fired (`src/diagnosis.pl`)
6. **Advise** — decision rules pick the recommended action for the verdict, plus tips for each diagnosis
7. **Explain** — each reason with its CF, matched words and how much it raised the score (`src/explain.pl`)

### Expert-system components (course requirements)

| Requirement | How Tahaffuz does it | Where |
|---|---|---|
| **Knowledge base** | Indicators with CFs, keywords (English + Roman Urdu), brands, official domains, scam types, advice | `src/kb.pl`, `src/diagnosis.pl` |
| **Inferencing** | Rules fire on the facts of the message (data-driven, like forward chaining), and the CFs of every fired rule are combined with the MYCIN formula. Order-independent: the formula is commutative and associative. | `src/matcher.pl`, `src/inference.pl` |
| **Decision making** | Score → band (Safe < 0.40 ≤ Suspicious < 0.70 ≤ Scam), then the **gate meta-rule**: Scam needs a direct request | `verdict/3` in `src/inference.pl` |
| **Diagnosis** | Which scam it is: OTP / PIN theft, personal-details theft, fake prize, fake official helpline, money request, phishing link, account-blocked scare, too-good offer. Several can apply; the first is the main diagnosis. | `diagnosis/2` in `src/diagnosis.pl` |
| **Decision support** | Recommended action from a decision table (Scam → block and report, Suspicious → verify first, Safe → no action) plus specific advice for each diagnosis | `decision_support/4` in `src/diagnosis.pl` |
| **Explanation facility** | Every reason with its CF, matched words and contribution; the gate note when a verdict was capped | `src/explain.pl` |
| **User interface** | Console (`explain/1`) and web page | `load.pl`, `server.pl`, `web/` |

In the console, `explain/1` prints all of it. The API returns it as `diagnosis`, `action` and `advice`.

Full design: [PLAN.md](PLAN.md). Progress: [CHECKLIST.md](CHECKLIST.md).

---

## 7. Project layout

```
load.pl              console entry point
server.pl            web server + /api/analyse
web/                 index.html, style.css, app.js
src/kb.pl            knowledge base (facts only)
src/matcher.pl       pattern matcher
src/inference.pl     MYCIN combination, bands, gate rule
src/explain.pl       explanation facility + analyse/4, assess/7
src/diagnosis.pl     diagnosis (scam type) + decision support (action, advice)
tests/messages.pl    88 labelled test messages (hand-written)
tests/run_tests.pl   unit tests + results table
tests/eval_corpus.pl corpus evaluation (uci, pksms, zenodo, mendeley)
data/uci/            UCI SMS Spam Collection
data/mendeley/       Mendeley SMS Phishing dataset
data/pk_sms/         Pakistan SMS Classification dataset (dev)
data/zenodo_ru/      Roman Urdu Phishing SMS dataset (converted to CSV)
```

**Dataset credits** (used for evaluation only; contents unchanged):
- T. A. Almeida and J. M. Gómez Hidalgo, *SMS Spam Collection*, UCI Machine Learning Repository. CC BY 4.0.
- S. Mishra and D. Soni, *SMS Phishing Dataset for Machine Learning and Pattern Recognition*,
  Mendeley Data, v1, 2022. doi:10.17632/f45bkkt8pr.1. CC BY 4.0.
- G. Siddiq, *Roman Urdu Phishing SMS Dataset for Smishing Detection Research*, Zenodo, v1.0.0, 2026.
  doi:10.5281/zenodo.21810885. CC BY 4.0. Converted from .xlsx to .csv.
- *Pakistan SMS Classification Dataset*, Kaggle (muhammadhumyun), via GitHub usamabhatti1998/pakistan_sms_classification.
  No licence stated; used privately for development only.

Notes: Mendeley was partly built from UCI, so some *ham* messages appear in both. The Pakistan SMS set is
partly LLM-paraphrased (per its own README). The Zenodo set is probably template-generated (not confirmed).
The messages in `tests/messages.pl` are hand-written for this project; names, numbers and links are made up.
