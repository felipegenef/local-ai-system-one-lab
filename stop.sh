#!/usr/bin/env bash
# STOP the local System One server (frees the VRAM)
# Tries the systemd unit first (if installed), then kills the loose process.
systemctl --user stop rizzo.service 2>/dev/null || true
pkill -f "rizzo serve" 2>/dev/null || true
sleep 1
curl -s --max-time 2 -o /dev/null http://127.0.0.1:8017/health \
  && echo "⚠ still responding — run again" \
  || echo "server stopped. VRAM freed."
