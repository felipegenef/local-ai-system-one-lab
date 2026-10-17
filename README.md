# local-ai-system-one-lab — System One models (Jev-style), open-weights, running locally for free

Small lab for the **System One** model class — AI engines that return **typed decisions with probabilities** (yes/no, pick-one, scale, number) in a single forward pass, no text generation. The famous closed model in this class is TypeSafe's **Jev**; this folder runs and teaches its **open-weights equivalents for free**.

> 🇧🇷 Este repositório tem documento-irmão em português do Brasil: `README.pt-BR.md`. Os materiais para humanos também existem nos dois idiomas (`RUNBOOK.pt-BR.md` PT + `RUNBOOK.md` EN; `LESSON.pt-BR.md` PT + `LESSON.md` EN).

## What is in the box

| File | Role |
|---|---|
| `CLAUDE.md` | agent instructions: tutor mode — an agent opening this repo can guide a human step by step through the lesson, in their language |
| `RUNBOOK.pt-BR.md` / `RUNBOOK.md` | runbook for humans: install, run, playground, API — 3 copy-paste commands each |
| `LESSON.pt-BR.md` / `LESSON.md` | class material: analogies, the 4 primitives (noul/choice/score/numeric), 6 hands-on labs |
| `AGENTS.md` | technical dossier for AI agents: measured numbers, pitfalls, platform variants (Linux/Mac/Windows), benchmarks |
| `start.sh` `/` `stop.sh` | start/stop the local Rizzo Flow server (playground at http://127.0.0.1:8017/playground) |
| `try-rizzo.sh` · `try-laya.py` | test **one** categorization through either engine — same JSON contract in/out |
| `lambda/` | CDK app + Dockerfile that puts the Laya engine inside an AWS Lambda (executed and measured; results inside) |
| `LAMBDA-LAYA.md` | plan + measured results of the cloud experiment (route A; routes B/C) |

## Want a more interactive ride? Bring an AI agent.

Open your favorite AI agent in this folder — **Claude Code, Codex, OpenCode, or any other that reads `CLAUDE.md` / `AGENTS.md`**. Those two files carry the instructions: the agent reads and understands this material and **teaches you, in your native language**, step by step — the basic System One concepts, the hands-on experiments of the lesson, and answers to every question you ask along the way. Because the instructions are auto-loaded when the agent starts in this folder, it will **proactively offer to teach you**: you just say which language you prefer and whether you want the guided walkthrough — then follow the lesson order together, run the commands, and discuss the results as they appear.

Prefer to study on your own? Read `LESSON.md` (English) or `LESSON.pt-BR.md` (Portuguese) — the lesson is self-contained.

## Quick start (Linux + an AMD/NVIDIA GPU; no GPU → CPU mode in the runbook)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
git clone https://github.com/Rizzo-AI-Academy/rizzo-flow.git && cd rizzo-flow && uv sync --locked
uv run rizzo download        # ~5 GB, resumable, sha256-checked
uv run rizzo serve           # → http://127.0.0.1:8017/playground
```

Or with no GPU (Laya on CPU): see `RUNBOOK.md` → "CPU mode".

## Measured highlights (this lab)

- Rizzo Flow 4B (Q8_0, Vulkan, 8 GB card): **5.99 GiB VRAM**, warm p50 0.21 s, smoke accuracy 0.95.
- Laya on a 16-thread CPU: **136 ms per full request**; batch 20×4 → 83 ms/request.
- Laya in an AWS Lambda (10 GB): cold **97 s** / warm **0.53 s**; JSON API identical to TypeSafe's Jev.
- Honest quality finding: Laya zero-shot in **Portuguese** fails discrete intents confidently (churn 0.029 where EN gives 0.886) — always benchmark on your own data.
