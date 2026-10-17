#!/usr/bin/env bash
# Measure cold/warm against the Laya Lambda Function URL.
# Usage: ./bench.sh 'https://xxxx.lambda-url.us-east-1.on.aws/'
set -euo pipefail
URL="${1:?usage: ./bench.sh 'https://<id>.lambda-url.<region>.on.aws/'}"
URL="${URL%/}"
PAYLOAD='{"state": "PAGTO CONTA LUZ CELESC 156,70", "questions": {"categoria": {"type": "choice", "instructions": "Which category best describes this transaction?", "criteria": {"house": "fixed bills: power, water, internet", "food": "grocery, bakery", "_vazia": "matches nothing"}}}}'

echo "== COLD (1st call; includes model load) =="
curl -s -o /tmp/laya_cold.json -w 'time: %{time_total}s  http: %{http_code}\n' --max-time 300 \
  -X POST "$URL/v1/systemone" -H 'content-type: application/json' -d "$PAYLOAD" || true
head -c 300 /tmp/laya_cold.json 2>/dev/null; echo

echo "== WARM (3 calls) =="
for i in 1 2 3; do
  curl -s -o /tmp/laya_warm.json -w "warm$i: %{time_total}s  http: %{http_code}\n" --max-time 60 \
    -X POST "$URL/v1/systemone" -H 'content-type: application/json' -d "$PAYLOAD"
done
python3 -c "import json;d=json.load(open('/tmp/laya_warm.json'));print('answer:', d.get('answers',{}).get('categoria',{}).get('choice'))" 2>/dev/null || true
