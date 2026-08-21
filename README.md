# claude-statusline

Status line for [Claude Code](https://claude.com/claude-code) showing model, rate-limit
usage with reset countdowns, context-window utilization, and session cost — color-coded
so limits are visible at a glance.

```
[Opus 5 1M] | 5h: 68% | 7d: 35% (4d16h) | $0.00
```

| Field | Meaning |
| --- | --- |
| `[Opus 5 1M]` | Current model display name, compacted (`(1M context)` → `1M`) |
| `5h: 68%` | 5-hour rate-limit usage, with time until reset when available |
| `7d: 35% (4d16h)` | 7-day rate-limit usage and time until reset |
| `ctx: 31%` | Context-window utilization |
| `$0.00` | Session cost in USD |

Percentage colors: green under 50%, yellow 50–79%, red 80%+.

Every segment is optional — if the session JSON omits a field (older Claude Code
versions, or a window with no data), that segment is skipped rather than erroring.

## Files

| File | Platform | Notes |
| --- | --- | --- |
| `statusline.sh` | WSL / Linux / macOS | bash wrapper around inline `python3`; no `jq` dependency |
| `statusline.ps1` | Windows | PowerShell port; same output format |

## How it works

Claude Code's `statusLine` setting supports `type: command`. Claude pipes a JSON blob of
session state to the configured command on stdin; whatever the command writes to stdout
becomes the status line. The script parses that JSON, applies ANSI escapes, and prints
the assembled line.

```
Claude Code --(JSON via stdin)--> statusline script --(ANSI via stdout)--> terminal
```

Relevant JSON paths consumed:

- `model.display_name`
- `rate_limits.five_hour.used_percentage` / `.resets_at` (unix seconds)
- `rate_limits.seven_day.used_percentage` / `.resets_at`
- `context_window.used_percentage`
- `cost.total_cost_usd`

## Setup

### WSL / Linux / macOS

Copy `statusline.sh` to `~/.claude/statusline-command.sh`, make it executable, and add to
`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /home/<USER>/.claude/statusline-command.sh"
  }
}
```

Requires `python3` (preinstalled on Ubuntu).

### Windows

Copy `statusline.ps1` to `~/.claude/statusline.ps1` and add:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/<USERNAME>/.claude/statusline.ps1"
  }
}
```

`-NoProfile -ExecutionPolicy Bypass` matters — without it, PowerShell profile load adds
noticeable latency to every status-line refresh.

Restart Claude Code after editing `settings.json`.

## Testing without Claude Code

```bash
echo '{"model":{"display_name":"Opus 5 (1M context)"},
       "rate_limits":{"five_hour":{"used_percentage":68},
                      "seven_day":{"used_percentage":35,"resets_at":1755000000}},
       "cost":{"total_cost_usd":0}}' | bash statusline.sh
```

Note `resets_at` is an absolute unix timestamp — a past value renders no countdown.
