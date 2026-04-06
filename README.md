# claude-code-statusline

A design-driven status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). One shell script, zero dependencies (besides `jq`), opinionated design framework.

```
project(main) │ opus-4.6-1m │ ████░░░░░░ 42% $1.23 │ ████░░░░░░ 42% 4d
╰─ Location ─╯ ╰── Model ──╯ ╰── Session Usage ────╯  ╰── User Usage ────╯
```

## Setup

```sh
# Copy the script
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# Configure Claude Code (in ~/.claude/settings.json)
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Requires `jq` for JSON parsing. Install via `brew install jq` / `apt install jq` if not already present.

## Design

Most status line tools optimize for **features** — more widgets, more themes, more config options. This one optimizes for **information architecture**: deciding what earns a spot on your status line, and why.

### Four Zones

The status line is organized into four zones, ordered by scope and urgency:

| Zone | Shows | Question it answers | Act when... |
|------|-------|-------------------|-------------|
| **Location** | `project(branch)` | Am I in the right place? | Wrong project/branch |
| **Model** | `opus-4.6-1m` | Is the right model running? | Wrong model |
| **Session Usage** | Context bar + $cost | How much has this session consumed? | Context running low |
| **User Usage** | 7d pace bar + 5h alert | Am I utilizing my subscription? | Pace falling behind |

**Urgency decreases left to right.** Wrong project demands immediate action. Subscription pace is a weekly behavioral nudge. Reading direction matches priority.

**Static left, dynamic right.** Location and Model rarely change — they anchor you. Session and User Usage update with every interaction — they show movement.

### Field Selection

Every field must pass three tests:

1. **Glanceable** — understand it in under one second
2. **Actionable** — an abnormal value changes your behavior
3. **Non-redundant** — can't be inferred from another field

Fields that fail: `session_id` (meaningless to humans), `total_tokens` (the bar already shows this), `lines_added/removed` (visually loud, not actionable), `total_duration_ms` (you have a clock).

### Two Usage Bars, One Visual Language

Both bars use identical `█░` characters. The difference is what the color encodes:

**Session bar** — color = context fullness (threshold-based):
- Green (<50%) → Yellow (50-70%) → Orange (70-90%) → Red (>90%)

**User bar** — color = 7-day pace (delta-based):
- Green (ahead ≥5%) → Yellow (on pace) → Orange (behind ≤-5%)

Same form, different semantics. When both are green, that's the best signal: plenty of context *and* strong subscription utilization.

### Subscription as Investment, Not Budget

The User Usage bar is built on a specific value judgment: on a Max subscription, unused tokens are wasted value, not saved budget.

The pace formula compares actual usage against expected usage for this point in the 7-day window:

```
pace_delta = used_percentage - elapsed_percentage
elapsed    = (window_total - time_remaining) / window_total × 100
```

Ahead of pace (green) = getting your money's worth. Behind pace (orange) = under-utilizing. This is the opposite of the "budget anxiety" framing used by most rate limit tools.

### 5-Hour Alert

The 5-hour burst window appears only when usage exceeds 80%. It shows two dynamic values:

```
91% 3h    (usage percentage + countdown to reset)
```

No static "5h" label — that's a window name, not useful data. The countdown tells you how long until the constraint lifts.

## Customization

This is a shell script, not a framework. Fork it, edit it, make it yours. A few things worth knowing:

- **Git cache**: Branch/dirty state is cached for 5 seconds to avoid blocking on large repos
- **Dynamic assembly**: Sections join with `│` only when non-empty — no ghost separators
- **`project_dir` not `cwd`**: Location uses the launch directory, not the current `cd` path — the anchor should be stable
- **User Usage requires a Claude.ai subscription** (Pro/Max) — the `rate_limits` field is absent for free-tier users; the zone simply won't appear

## Background

This status line evolved through five iterations, each driven by a specific design problem:

- **v1-v4**: Establishing the zone framework, field selection criteria, and visual encoding rules
- **v5**: Adding `rate_limits` (new in Claude Code v2.1.80), reclassifying zones by scope (session vs. user), and the investment-framing pace bar

Full design rationale and iteration history: [Designing a Claude Code Status Line](https://dongzhenye.com/posts/claude-code-statusline) | [Rate Limits: An Investment, Not a Budget](https://dongzhenye.com/posts/claude-code-statusline-subscription-utilization)

## License

MIT
