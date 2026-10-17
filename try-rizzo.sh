#!/usr/bin/env bash
# Test ONE categorization with Rizzo Flow (local GPU, 4B Q8_0).
# Usage:  ./try-rizzo.sh '{"state": "...", "options": {"cat1": "desc", "cat2": "desc", ...}}'
# Options may come without "_vazia" ("empty") — the script guarantees it always exists.
# Requirement: server up (./start.sh). API: POST /v1/systemone (Jev-compatible).
set -euo pipefail

INPUT="${1:?Example: ./try-rizzo.sh '{\"state\": \"PAGTO MERCADO ABC 189.90\", \"options\": {\"food\": \"grocery, bakery\"}}'}"
PORT="${RIZZO_PORT:-8017}"

# Build the /v1/systemone payload: one choice question + the guaranteed empty option
PAYLOAD=$(python3 - "$INPUT" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
opts = dict(d.get("options") or {})
opts.setdefault("_vazia", "Matches none of the categories above")
questions = {"categoria": {
    "type": "choice",
    "instructions": d.get("instruction") or "Which category best describes this transaction?",
    "criteria": opts,
}}
json.dump({"state": d["state"], "model": "rizzo-latest", "questions": questions}, sys.stdout, ensure_ascii=False)
PY
)

RESP=$(curl -s "http://127.0.0.1:$PORT/v1/systemone" -H 'Content-Type: application/json' -d "$PAYLOAD")

# Print a single normalized line: engine, choice, confidence, probabilities
python3 - "$RESP" <<'PY'
import json, sys
try:
    r = json.loads(sys.argv[1])
except Exception:
    sys.exit(f"API did not return valid JSON. Check that the server is up (/health). Response: {sys.argv[1][:200]!r}")
answers = list(r.get("answers", {}).values())
a = answers[0] if answers else {}
print(json.dumps({
    "engine": r.get("model"),
    "choice": a.get("choice"),
    "confidence": a.get("confidence"),
    "probabilities": a.get("probabilities"),
    "empty_choice": a.get("choice") == "_vazia",
}, ensure_ascii=False))
PY
