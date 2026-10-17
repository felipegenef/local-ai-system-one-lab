#!/usr/bin/env python3
# Test ONE categorization with Laya (CPU, 421M). Memory frees itself on exit.
# Usage:  ./try-laya.py '{"state": "...", "options": {"cat1": "desc", "cat2": "desc", ...}}'
# Re-execs automatically inside the laya-cpu venv (nothing to activate).
import json, os, sys
os.environ.setdefault("OMP_NUM_THREADS", "16")
HERE = os.path.dirname(os.path.abspath(__file__))
VENV_PY = os.path.join(HERE, "laya-cpu", ".venv", "bin", "python")

if sys.executable != VENV_PY and os.path.exists(VENV_PY):
    # Re-exec inside the dedicated venv (laya's torch pins differ from rizzo-flow's)
    os.execv(VENV_PY, [VENV_PY, __file__] + sys.argv[1:])
if not os.path.exists(VENV_PY):
    sys.exit("Create the environment first:  uv venv --python 3.12 && uv pip install laya  (laya-cpu/ folder, see RUNBOOK 'CPU mode')")

import laya
from laya import Router


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit('Usage: ./try-laya.py \'{"state": "...", "options": {"cat1": "desc", ...}}\'')
    d = json.loads(sys.argv[1])
    opts = dict(d.get("options") or {})
    opts.setdefault("_vazia", "Matches none of the categories above")
    questions = {"categoria": {
        "type": "choice",
        "instructions": d.get("instruction") or "Which category best describes this transaction?",
        "criteria": opts,
    }}
    router = Router(device="cpu")
    r = router.predict(d["state"], questions)
    a = r["answers"]["categoria"]
    print(json.dumps({
        "engine": f"laya ({r.get('routing', {}).get('model')})",
        "choice": a.get("choice"),
        "confidence": a.get("confidence"),
        "probabilities": a.get("probabilities"),
        "empty_choice": a.get("choice") == "_vazia",
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
