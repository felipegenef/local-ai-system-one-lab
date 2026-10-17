#!/usr/bin/env bash
# START the local System One server (Rizzo Flow)
# Playground once ready: http://127.0.0.1:8017/playground
# (model + runtime are already downloaded — nothing re-pays)
cd "$(dirname "$0")/rizzo-flow"
exec uv run rizzo serve "$@"
