# Jev & System One — Runbook (local open-weights)

**What you will end up with: an AI "System One" server running on YOUR machine, offline, for free, with a graphical interface and an API compatible with TypeSafe's Jev.**

*(This is the English mirror of `RUNBOOK.pt-BR.md`, which is the canonical Portuguese version.)*

60-second context:

- **System One Model** = an AI that *decides* instead of writing text. You send a `state` (text or JSON) + questions and get back **typed answers with probabilities**: yes/no (`noul`), pick-one (`choice`), scale (`score`), number (`numeric`). A single pass through the neural network, no tokens generated, no hallucination. **Jev** (TypeSafe) is the famous model of this class — ~40–200× faster and cheaper than LLMs for automation.
- Jev is **closed and paid** (cloud API). This runbook runs the **open-weights** equivalent on your hardware.

## Installation (3 commands)

> Works on real Linux with an AMD/Intel/NVIDIA GPU (ideal) — tested on an **8 GB GPU**. No GPU? Jump to "CPU mode" at the bottom.

**1. Tools + project**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # install uv (if not present); close the terminal afterwards
git clone https://github.com/Rizzo-AI-Academy/rizzo-flow.git && cd rizzo-flow
uv sync --locked
```

**2. Download model + runtime** (~5 GB; if the connection drops, run it again — resumes where it stopped)

```bash
uv run rizzo download
```

**3. Start the server** (model loads in ~10 s)

```bash
uv run rizzo serve
```

---

## Run it again or shut it down (another day)

Everything is already downloaded — no reinstall needed. Two shortcuts live next to this file (`JEV/` folder):

| What you want | Command (from the `JEV` folder) |
|---|---|
| **Start** (server + playground up) | `./start.sh` |
| **Stop** (frees the 6 GB of VRAM) | `./stop.sh` |
| Check if it is up | `curl http://127.0.0.1:8017/health` (`"status":"ready"` = ok) |

After `./start.sh`, wait ~15 s and open **http://127.0.0.1:8017/playground**.

---

## Testing (run in order)

1. **Was the GPU seen?** `uv run rizzo devices` → should list `Vulkan0` with your card's name.
2. **Graphical interface** → open **http://127.0.0.1:8017/playground**
   - Menu **Examples…** → **Support ticket** → button **Run** → 3 answers with probability bars.
   - Badge on top: `Spark-X2.5-4B · q8_0 · gpu`.
3. **API via terminal** (paste in another terminal, with the server running):

```bash
curl http://127.0.0.1:8017/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": "Payouts failing for 3 days",
  "model": "rizzo-latest",
  "questions": {"u": {"type": "noul", "instructions": "Is this urgent?"}}
}'
```

✅ Must return a JSON with `"noul"` (~0.99) and `"output_tokens": 0`.

## To play

- **Playground**: build questions with clicks, change the text, press Run. ([/playground](http://127.0.0.1:8017/playground))
- **Decision Snake**: each move of the snake is one model decision. ([/snake](http://127.0.0.1:8017/snake))
- **API docs** (swagger): [/docs](http://127.0.0.1:8017/docs)
- Guided class + exercises: see **LESSON.pt-BR.md** (one folder up). It explains the 3 question types with everyday examples and ready-to-paste exercises.

## Always-on server (optional, Linux server)

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/rizzo.service <<'EOF'
[Unit]
Description=Rizzo Flow (System One)
After=network.target

[Service]
WorkingDirectory=%h/rizzo-flow
ExecStart=%h/.local/bin/uv run rizzo serve --host 0.0.0.0 --port 8017
Environment=RIZZO_API_KEY=CHANGE_THIS_TOKEN
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now rizzo.service
sudo loginctl enable-linger $USER
```

- Test: `curl -H 'Authorization: Bearer CHANGE_THIS_TOKEN' http://YOUR-IP:8017/health`
- Without the `RIZZO_API_KEY` variable, the API is open with no password (fine for a home lab).
- To reach it from other machines: open the firewall port (`sudo ufw allow 8017/tcp`) or put it behind a proxy (Caddy: `caddy reverse-proxy --from example.com --to 127.0.0.1:8017`).

## CPU mode (no GPU at all): Laya

```bash
mkdir -p ../laya-cpu && cd ../laya-cpu
uv venv --python 3.12 && uv pip install laya
```

> **Laya has no "start again / shut down"**: it is a program that runs and exits — when the script ends, CPU memory is freed by itself. Run it as many times as you like. Only **Rizzo** has start/stop (`start.sh` / `stop.sh`).

```bash
OMP_NUM_THREADS=16 .venv/bin/python -c "
from laya import Router
router = Router(device='cpu')  # first run downloads ~800 MB

state = {'body': 'I was charged twice. Refund today or I cancel the plan.'}
questions = {
  'department': {'type': 'choice', 'instructions': 'Which department?',
                 'criteria': {'billing': 'invoices, payments', 'technical': 'bugs, outages', 'other': 'rest'}},
  'urgency':   {'type': 'score', 'instructions': 'How urgent?', 'criteria': ['not urgent', 'soon', 'blocking']},
  'churn':     {'type': 'noul', 'instructions': 'Does the user threaten to cancel or leave?'},
}
r = router.predict(state, questions)
print(r['answers']['department']['choice'], '|', r['answers']['urgency']['score'])
"
```

- Measured on a 16-thread CPU: **136 ms** per full request — interactive-grade.
- **Heads-up:** in Portuguese, zero-shot Laya misses discrete intents (says "won't cancel" for someone who threatens to cancel). Always test on YOUR texts, EN and PT. (Details and numbers: LESSON.pt-BR.md.)

---

## Troubleshooting

| Symptom | What to do |
|---|---|
| `uv` not found | close and reopen the terminal |
| download stalled | run `uv run rizzo download` again (resumes where it stopped) |
| `rizzo devices` shows no card | install the Vulkan driver: `sudo apt install mesa-vulkan-drivers` |
| port 8017 busy | `uv run rizzo serve --port 8020` |
| SDK sends a weird model name | always use `model="rizzo-latest"` |
| slow / out of VRAM | `uv run rizzo serve --quant q4_k_m` (2.6 GB) or `--size 1.7b` (1.8 GB) |

More technical pitfalls and platform variants (Mac/Windows): see **AGENTS.md**.
