# LESSON — System One: the AI that decides (doesn't write)

> Open self-study material (hands-on tutorial). Setup: `RUNBOOK.md`; extra technical details: `AGENTS.md`. Portuguese version: `LESSON.pt-BR.md`.

**How to use this tutorial:** every step has 3 parts — **(1)** the concept in a few lines, **(2)** the command/JSON to paste, **(3)** the expected result + what to notice in it. Work in order: read the concept → run it → see the result → notice → next.

---

## 1. The idea in one sentence

**System One model = AI autopilot.** You ask "is this urgent?" and it answers "yes, 94%" — without writing text, without long reasoning, without inventing sentences.

**The Kahneman analogy (who named the terms):** our brain has two modes. **System 1** is automatic: you swerve around the pothole before consciously seeing it — fast, cheap, no conscious effort. **System 2** is slow reasoning: parking in a tight spot, comparing two financing offers... it costs time and energy. Daily LLMs are **System 2**: they write answers word by word. A System One is **System 1**: one quick look, one ready answer with a confidence level.

## 2. How it works (the plumbing)

Every System One model follows the same contract:

```
                ┌────────────────────┐
   "state"      │                    │  TYPED answers:
  (text or     │       MODEL        │  choice + probabilities + confidence
   JSON)  ────► │    (one pass)      │
                │                    │
   "questions"─►│                    │  output_tokens: 0 (NO text generated)
                └────────────────────┘
```

The speed trick: each question becomes a **multiple choice** — each candidate is a letter (A, B, C...) — and the model **reads the probability of each letter straight from the guts of the neural network**, in a single pass. It is like peeking at the model's internal scoreboard without asking it to write "option B seems better because...". That is why it is 40–200× faster than an LLM answering in text.

## 3. The 4 question types (the system's variables)

| Type | Like asking... | It returns | Everyday example |
|---|---|---|---|
| `noul` (yes/no) | "Does this block customers?" | P(yes), 0 to 1 | "Is the customer angry?" → 0.85 |
| `choice` | "Which option describes it best?" | winning option + prob. of each + confidence | "email SPAM/WORK/PERSONAL?" |
| `score` | "Grade on an ordered ruler" | weighted mean of the ruler + confidence | "Urgency: [low, medium, high]" |
| `numeric`* | "Read the number in the data" | weighted value + median + spread | thermostat: 24 °C |

`*` `numeric` exists only in Rizzo Flow's native API (`/v1/decisions`). The first 3 exist everywhere, in the `/v1/systemone` contract (identical to the paid Jev API).

Request anatomy: **`state`** (the material to judge) · **`questions`** (each with `type`, `instructions` = the question in plain text, `criteria` = the menu of options with descriptions). The `criteria` descriptions are what "steers" the model — with no description, it guesses.

## 4. Confidence ≠ accuracy (read before experimenting)

Each answer comes with **confidence** — a mathematical function of the *shape* of the probabilities, not a promise of being right. TypeSafe's slogan ("more confidence ⇒ more accuracy") holds **measured on their data**. On your domain there are exceptions — and **Step 7** shows it happening in front of you.

---

## 5. Hands-on — step by step

### Step 1 — Install the engine (pick one)

**Option A — with a GPU (Rizzo Flow):**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh    # Python management tool
git clone https://github.com/Rizzo-AI-Academy/rizzo-flow.git && cd rizzo-flow
uv sync --locked
uv run rizzo download
```

You should see: download lines with sha256 checks, ending with the model in `models/` and the runtime in `runtimes/`.

**Option B — any computer, no GPU (Laya on CPU):**

```bash
mkdir -p ../laya-cpu && cd ../laya-cpu
uv venv --python 3.12 && uv pip install laya
```

You should see: packages installed without errors. The weights (~800 MB) download on the first run of Step 7.

### Step 2 — Start the server (Option A only)

```bash
./start.sh
```

You should see, among other lines: `Uvicorn running on http://127.0.0.1:8017`. In another terminal, check:

```bash
curl http://127.0.0.1:8017/health
```

Expected: `{"status":"ready", ...}` — ready, the engine is warm.

### Step 3 — First decision (playground)

Open **http://127.0.0.1:8017/playground** → menu **Examples…** → **Support ticket** → button **Run**.

You should see: 3 answers with probability bars — `department` (pick a team), `escalate` (P of urgency) and `frustration` (position on a ruler) — plus timings and **`output_tokens: 0`**.

**Notice:** the model wrote not a single word; the bars ARE the answer. Change 1 word of the `state` (swap "refund" for "angry") and Run again — the bars move.

### Step 4 — The same decision through the API (copy and paste)

```bash
curl http://127.0.0.1:8017/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": "Help! My payouts have been failing for 3 days.",
  "model": "rizzo-latest",
  "questions": {
    "is_urgent": {"type": "noul", "instructions": "Does this convey urgency?"},
    "department": {"type": "choice", "instructions": "Which team should handle this?",
      "criteria": {"billing": "Payments, invoicing, refunds", "technical": "Bugs, outages", "sales": null}},
    "frustration": {"type": "score", "instructions": "How frustrated is the customer?",
      "criteria": ["Calm", "Frustrated", "Very angry"]}
  }
}'
```

You should see (approximate values):

```json
{"answers": {
  "is_urgent":  {"type": "noul",  "noul": 0.94},
  "department": {"type": "choice", "choice": "billing",
                 "probabilities": {"billing": 0.99, "technical": 0.01, "sales": 0.00}, "confidence": 0.99},
  "frustration":{"type": "score", "score": 1.23,
                 "probabilities": {"0": 0.00, "1": 0.76, "2": 0.24}, "confidence": 0.64}
}, "usage": {"input_tokens": 291, "output_tokens": 0}}
```

**Notice:** the ticket mixes a return + a late delivery + a billing issue — and the `department` probabilities say exactly that ("billing" wins, but not with 100% chance): that is why the answer carries a distribution, not just a label. And `output_tokens: 0` again.

### Step 5 — The options steer the answer

In the playground, delete the option **descriptions** of `department` (keep only the keys: `billing`, `technical`, `sales`) and Run. Then add a fake option `"vip": "high-value customer"` and Run again.

You should see: without descriptions the distribution gets "blinder" (less stable); with the new option the bars redistribute.

**Notice:** the `criteria` descriptions are the model's menu — they carry the meaning. Prompt engineering here = writing good option descriptions.

### Step 6 — Numbers by anchors

In the playground, **JSON** tab, paste and run:

```json
{
  "state": {"percent_value": 75, "unit": "%"},
  "questions": {
    "fill": {
      "type": "numeric", "unit": "percent",
      "instructions": "Read the reported fill percentage.",
      "anchors": [
        {"value": 0, "description": "Empty"},
        {"value": 50, "description": "Half"},
        {"value": 75, "description": "Three quarters"},
        {"value": 100, "description": "Completely full"}
      ]
    }
  }
}
```

You should see: `value ≈ 75`, with the probability mass concentrated on "Three quarters" + spread fields. Now change `"percent_value": 75` to `130` and run again.

You should see: the result comes back as `__above_range__` (off the ruler), with an explicit `status`.

**Notice:** the number is not "read" — it is the **weighted mean of the anchors**. And off the ruler the model **refuses with an elegant status** instead of guessing.

### Step 7 — When confidence lies (Laya, CPU)

In the `laya-cpu` folder (Option B of Step 1), create `test.py`:

```python
from laya import Router
router = Router(device='cpu')   # first run downloads the weights
q = {'churn': {'type': 'noul', 'instructions': 'Does the user threaten to cancel or leave?'}}
print("EN :", router.predict({'body': 'Please refund or we will cancel our plan.'}, q)['answers']['churn']['noul'])
print("PT :", router.predict({'body': 'Peço o reembolso hoje ou cancelarei nosso plano.'}, q)['answers']['churn']['noul'])
```

Run with `OMP_NUM_THREADS=16 .venv/bin/python test.py`. You should see:

```
EN : 0.886
PT : 0.029
```

**Notice:** same question, same meaning — in English it gets it right; in Portuguese it errs **with full confidence** (0.029 is almost "I am sure it is NOT"). This is the key moment of the tutorial: confidence is only worth it when calibrated on YOUR data. (Before production: test on your own texts, use the right checkpoint, calibrate or fine-tune.)

### Step 8 — Speed you can see

Open **http://127.0.0.1:8017/snake** (Option A only). Each move of the snake = **1 model decision**, with the probabilities of each legal direction on screen. Play one round.

**Notice:** an LLM writing "my strategy is..." would spend seconds per move; here the decision arrives in milliseconds, generating no token. This is the cost of automation dropping orders of magnitude (TypeSafe calls it the Jevons paradox: cheapen intelligence and demand explodes).

### Step 9 — Build your own benchmark

Take **5 texts of your own** (messages, e-mails, notes) and a JSON like this one — replace `state` and the `options` with your case:

```json
{
  "state": "<paste text 1 here>",
  "options": {
    "<category_1>": "<describe what belongs here>",
    "<category_2>": "<describe what belongs here>",
    "_vazia": "none of the options fit"
  }
}
```

Run each one through the Step 4 `curl` (or the ready-made `./try-rizzo.sh`, `./try-laya.py` scripts in the repo) and note: did it hit? Where was confidence low? Where did it err **confidently**?

**Notice:** comparing against your own human guess is what turns "cute" into "trustworthy". A third-party benchmark is a map; your domain is the territory.

---

## 6. Summary card (to take home)

- **What it is:** `state` (text/JSON) + typed questions = typed answers with probabilities. No text generated ⇒ no hallucinated sentences and no invalid JSON (type-safety is inherent to the design).
- **When to use:** fast, high-volume automation (triage, routing, guardrails, field extraction). **Don't** use it to WRITE text — that is the LLM's job.
- **Key variables:** `state` · `questions{type, instructions, criteria}` · `noul = P(yes)` · `choice → probabilities + confidence` · `score → legend + mean` · `numeric → anchors` (representative values, NOT confidence intervals).
- **Practical pitfalls:** badly described options; question without enough context; language (test in PT!); raw confidence needs calibration.
- **What you experimented with today:** Rizzo Flow 4B (GPU, Q8_0, API identical to Jev) and Laya (CPU, multilingual) — both open-weights.

## 7. Where to go next

- The cloud experiment (a Laya engine inside an AWS Lambda, with the measured memory matrix) is documented in **`LAMBDA-LAYA.md`** and **`lambda/README.md`** — including what went wrong on each attempt, so you don't burn the same time.
- The measured numbers and platform pitfalls (Linux/Mac/Windows) live in **`AGENTS.md`**.

Enjoy the journey! 🐍
