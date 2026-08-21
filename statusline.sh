#!/usr/bin/env bash
# Claude Code status line (WSL) — mirrors the Windows PS1 version.
# Uses python3 (preinstalled in Ubuntu) instead of jq.

INPUT=$(cat)
echo "$INPUT" | python3 -c '
import json, re, sys, time

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

ESC   = "\033"
RESET = f"{ESC}[0m"
DIM   = f"{ESC}[38;2;144;144;144m"

def color(pct):
    if pct >= 80: return f"{ESC}[31m"   # red
    if pct >= 50: return f"{ESC}[33m"   # yellow
    return f"{ESC}[32m"                 # green

def fmt_dur(secs):
    if secs <= 0: return None
    d, r = divmod(secs, 86400)
    h, r = divmod(r, 3600)
    m, _ = divmod(r, 60)
    if d: return f"{d}d{h}h"
    if h: return f"{h}h{m}m"
    return f"{m}m"

def get(path):
    cur = d
    for k in path.split("."):
        if not isinstance(cur, dict): return None
        cur = cur.get(k)
        if cur is None: return None
    return cur

now = int(time.time())
parts = []

model = get("model.display_name")
if model:
    short = re.sub(r"\((\d+\w?) context\)", r"\1", model)
    short = re.sub(r"\s+", " ", short).strip()
    parts.append(f"{DIM}[{short}]{RESET}")

for label, base in (("5h", "rate_limits.five_hour"), ("7d", "rate_limits.seven_day")):
    pct = get(f"{base}.used_percentage")
    if pct is None:
        continue
    p = round(pct)
    seg = f"{label}: {color(p)}{p}%{RESET}"
    reset = get(f"{base}.resets_at")
    if reset is not None:
        dur = fmt_dur(int(reset) - now)
        if dur:
            seg += f" {DIM}({dur}){RESET}"
    parts.append(seg)

ctx = get("context_window.used_percentage")
if ctx is not None:
    p = round(ctx)
    parts.append(f"ctx: {color(p)}{p}%{RESET}")

cost = get("cost.total_cost_usd")
if cost is not None:
    parts.append(f"{DIM}${cost:.2f}{RESET}")

print(f"{DIM} | {RESET}".join(parts))
'
