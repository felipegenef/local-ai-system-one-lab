# AGENTS.md — Technical dossier of the System One experiments (for AI agents)

> This file is the lab's technical record. For HUMANS: `RUNBOOK.pt-BR.md` / `RUNBOOK.md` (setup) and `LESSON.pt-BR.md` / `LESSON.md` (class material).

## 0. Tutor mode — if an agent is running in this repo

If you are an AI agent in this repository with a human: the full tutor instructions are in `CLAUDE.md` — and they are **proactive**: do not wait to be asked. Open with a short greeting and an offer to teach System One step by step, in the terminal. Ask at once: **(1)** their preferred language (offer the native one — the lesson exists in EN `LESSON.md` and PT-BR `LESSON.pt-BR.md`) and **(2)** guided walkthrough or self-study.

If they accept (most will):

- Teach **ONE concept at a time**, in short simple sentences with everyday analogies; then hand over the command/JSON of that step and **wait for them to run it** and show the result before moving on — they must experiment, not watch you work.
- **Comment on the results they get**, connecting each one to the concept just learned ("that `noul: 0.94` is the P(yes) we just read about") and ask small check questions along the way. Follow the lesson order, jumping ahead/back when their questions ask for it.
- **Answer questions in their language**, in plain words; deeper technical answers come from this dossier and the READMEs. Encourage them to change the examples (state, options) — that is where the learning happens.
- Practical rules: the machine may lack a GPU (the lesson has a CPU path); confirm before installing software; the `lambda/` experiment needs the user's own AWS credentials — guide, never assume.

If they decline: point to `LESSON.md` / `LESSON.pt-BR.md` and stay available for questions.

## 1. What we decided and why

- **Goal:** run a "System One model" (the class of TypeSafe's **Jev**) open-weights locally, with a UI for humans and an API for agents.
- **Primary pick:** **Rizzo Flow** (`Rizzo-AI-Academy/rizzo-flow`) — Spark-X2.5-4B with a decision LoRA, in GGUF **Q8_0** (4.4 GB → ~5.99 GiB VRAM with 8k KV), served by llama.cpp, API `/v1/systemone` byte-compatible with TypeSafe.
- **CPU pick:** **Laya** (`NandhaKishorM/laya`) — 421M + 322M multilingual, 136 ms/request on a 16-thread CPU.

## 2. Test machine (generic description)

- **GPU:** 8 GB discrete GPU (AMD, standard Vulkan driver) + an integrated GPU. No CUDA; no full ROCm stack.
- x86_64 Linux, 16-thread CPU, 32 GB RAM.
- Reminder: **never use the raw llama-server** (the runtime's binary) with Spark GGUFs — plain llama.cpp fails on Vulkan with the hybrid KV cache ("pre-allocated tensor (cache...) cannot run the operation"). The right path is `rizzo serve`, which uses its own ctypes bindings for commit `161755f`.
- Kev is PyTorch-based: great on NVIDIA/Mac; on this AMD-8GB box it would run on CPU or require manual ROCm — hence the pick here is Rizzo.

## 3. Measured numbers (source: this lab, Oct 14 2026)

| Metric | Value |
|---|---|
| Peak VRAM (Rizzo 4B Q8_0, 8k KV) | **5.99 GiB** |
| Warmup (1st request) | ~2 s (compilation) |
| p50 / p95 (official smoke.jsonl, 17 req) | 0.21 s / 0.68 s |
| Throughput | 4.2 decisions/s (local Vulkan) |
| Smoke **accuracy** (categorical) | **0.95** (same as the project's report) |
| 3-question steady-state call | ~0.31 s |
| Laya CPU 16t: 1 request × 4 questions | **~136 ms** (34 ms/question) |
| Laya CPU: batch 20×4 | **1.66 s → 83 ms/request** |
| Laya same ticket in PT | refund 0.996 ✅ / churn **0.029 ❌** (confidently wrong) |
| Laya same ticket in EN | refund 0.90 ✅ / churn 0.886 ✅ |

## 4. Operational assets in the folder

```
repo/
├── CLAUDE.md       # agent instructions: tutor mode (guide a human through the lesson)
├── RUNBOOK.pt-BR.md      # human runbook (setup)           ├ RUNBOOK.md
├── LESSON.pt-BR.md         # class material with labs        ├ LESSON.md
├── try-rizzo.sh    # test 1 categorization via Rizzo's API (needs the server up)
├── try-laya.py     # test 1 categorization with Laya in-process (auto re-execs the venv)
├── AGENTS.md       # this dossier (English)
├── rizzo-flow/     # repo clone, uv-synced venv (gitignored)
│   ├── models/rizzo-flow/spark-x2.5-4b-rizzo-flow-lora-q8_0.gguf
│   └── runtimes/llama-b11081-linux-x64-vulkan/
├── laya-cpu/.venv  # separate venv (laya pulls torch 2.14 / transformers 5) (gitignored)
└── lambda/         # CDK app + Dockerfile of the Lambda experiment (gitignored artifacts)
```

Start/stop rizzo: `uv run rizzo serve` (Ctrl+C to stop) or `./start.sh` / `./stop.sh`. Diagnostics: `uv run rizzo devices`; signature: `curl http://127.0.0.1:8017/health`.

**Unified interface of the two test scripts** (`try-rizzo.sh` / `try-laya.py`): input `{"state": "...", "options": {...}}` → output `{"engine", "choice", "confidence", "probabilities", "empty_choice"}`; the `_vazia` ("empty") option is always guaranteed in the payload. **Bake-off on 3 sample transactions (learning use case: "given a bank-statement line, pick one category from a shortlist"):** Rizzo 4B Q8_0 = 3/3 (conf. 0.74–0.99); Laya multilingual zero-shot = 1/3 (missed "UBER TRIP" and "MERCADO ZAFFARI" to `_vazia` in PT-BR — the same weakness as the churn case). Takeaway for transaction-categorization use cases: **Rizzo 4B is the default candidate; Laya joins after a PT fine-tune**.

## 5. Recorded pitfalls (expected frequency order)

1. **SDK `von-sdk` → 400 `api_usage_error`**: von sends `model="von-1.3.0"`; Rizzo only accepts `rizzo-latest`, the local id and `jev-*` names. Fix: pass `model="rizzo-latest"`.
2. **Raw llama-server with Spark GGUF** dies on Vulkan (hybrid KV cache). Not a config bug: the ready path is Rizzo's own ctypes bindings (b11081, commit `161755f`).
3. **Confidently wrong Portuguese on Laya multilingual** (discrete noul): churn 0.029. Moral: check which model decided (`r['routing']['model']`) and test on your own data. `Router(device='cpu')` with OMP 16 threads (28+ over-subscribes).
4. **Laya must not be imported inside rizzo-flow's venv** (pinned torch versions collide) — install it in `laya-cpu/`.
5. **Port**: 8017 by default; services unit in `~/.config/systemd/user/rizzo.service`; `--host 0.0.0.0` + `RIZZO_API_KEY` for networking. 401 on `/health` = key set; send `Authorization: Bearer <key>`.
6. **Restartable download**: `rizzo download` resumes if interrupted; sha256-verified.
7. **Q8 vs Q4**: on the 4B, `q4_k_m` (2.6 GB) **ties** Q8_0 accuracy on the project's benchmark; on the 1.7B it loses 5 points. bf16 (8.2 GB) blows past the 8 GB card.
8. **`--ctx`**: reserves KV at startup (~144 KiB/token); raising `--ctx 16384` needs VRAM; mitigate with `--kv-type q8_0`.

## 6. Platform variants (condensed from the official docs)

- **Linux AMD/Intel:** **Vulkan** runtime (default). With an NVIDIA driver, `--runtime cuda`; professional AMD: `--runtime rocm`; Intel: `--runtime sycl`.
- **Linux with no GPU:** `rizzo serve --device cpu` (or Laya CPU — better cost/benefit).
- **macOS (Apple Silicon):** `rizzo download --backend mlx` + `rizzo serve --backend mlx` (Metal automatic). Laya: device `mps` (fp32; the first call pays ~13 s of Metal compilation; warm up before timing). Intel Mac: pinned stack `"numpy<2" "torch==2.2.2" "transformers==4.57.6" laya` (PyTorch drops x86_64 wheels at 2.3).
- **Windows:** PowerShell uses `.venv\Scripts\activate`; launcher `py -3.11`. NVIDIA GPU → CUDA runtime; AMD/Intel → Vulkan (current driver is enough). Laya: `py -3.11 -m venv .venv` etc.
- **Kev (if you ever get CUDA ≥4 GB):** `git clone github.com/jaredpalmer/kev && uv sync --extra serve && uv run python -m kev.serve --run jaredpalmer/kev-0.8b --port 8009`. For bigger GPUs: `kev-4b`, `kev-9b`, `kev-27b` (24/40/80 GB). Do not install from PyPI — the `kev` package there is something else (an old ORM).

## 7. Benchmark pipeline (to reproduce)

```bash
# rizzo (in /JEV/rizzo-flow)
uv run rizzo evaluate benchmarks/smoke.jsonl --output results/first-smoke.json
uv run pytest -q                        # 65+ unit tests with no network
RIZZO_REAL=1 uv run pytest -q -m integration   # uses the real runtime + GGUF
# laya (in /JEV/laya-cpu)
OMP_NUM_THREADS=16 .venv/bin/python -c "..."   # see RUNBOOK "CPU mode"
```

## 8. Key sources (prefer official docs over blogs)

- Jev/System One: typesafe.ai/blog/introducing-system-one-models-and-jev · docs.typesafe.ai · Wikipedia "Jev (AI model)".
- Rizzo Flow: github.com/Rizzo-AI-Academy/rizzo-flow (hardware table in the README; docs/training.md is in Italian).
- Laya: github.com/NandhaKishorM/laya · huggingface.co/convaiinnovations/laya(-multilingual) · the repo's BENCHMARKS.md.
- Comparison of 7: datacamp.com/blog/top-open-source-jev-alternatives.
- Independent review (honest anti-Laya limits): flowtivity.ai/blog/laya-open-source-jev-alternative.
- JevBench: github.com/fstandhartinger/jevbench (I/C/S/K scoreboard).

## 9. Execution log (what was done)

- [x] Rizzo Flow up (8017, playground/snake/docs), local smoke 0.95
- [x] Laya measured on CPU + PT/EN finding documented
- [x] Human runbook; AGENTS dossier; LESSON material
- [x] **Route A executed (Oct 17 2026): Laya inside Lambda + LWA 1.1.0 + Function URL (`lambda/`). Memory matrix: 3 GB = OutOfMemory; 5 GB = cold 252 s / warm 0.6 s; 10 GB = cold 97 s / warm 0.53 s; RAM working set 5.5 GB. Experiment cost ~US$ 0.12.** SnapStart rejected on cost (break-even ≈ 1,500 restores/month). Public endpoint (auth NONE) → **cleanup executed same day: stack destroyed, log group deleted, 4 ECR images removed (0 remaining). Recurring cost: zero.**

---

*Service signature: `rizzo-flow-4b-q8_0`; the weights fingerprint rides the `x_rizzo` header. The model id in the response names the checkpoint that answered.*
