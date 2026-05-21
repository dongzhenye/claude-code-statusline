# claude-code-statusline

A design-driven status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). One shell script, zero dependencies (besides `jq`), opinionated design framework.

```
project(feat/auth) │ sonnet-4.5 │ ████░░░░░░ 42% $1.23 │ ████████░░ 82% 1d 🔥
╰─── Location ───╯ ╰── Model ──╯ ╰── Session Usage ────╯ ╰─── User Usage ────╯
```

Project name and non-default model are bold; non-default branch is green; the pace bar warms up as weekly consumption climbs and earns a 🔥 stamp past 80%. The boring defaults (main branch, plan-default model, fresh week) sit dim — your eye lands only on what's worth reacting to.

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

### Highlight Rules — Bright Earns Attention

Earlier iterations colored everything that was instrumented. The problem: when nothing is dim, nothing pops. Color stops being signal and starts being decoration.

This version inverts the rule. The default / boring state sits dim; only deviations get a visual nudge. And the palette is intentionally small and semantic — each token does one job:

| Token | Meaning |
|---|---|
| **DIM** | Default / baseline — don't interrupt the eye |
| **BOLD** | Identity anchor or deviation from default — look here |
| **GREEN** | Clean / behind pace (cool, positive) |
| **YELLOW** | Dirty / on pace (caution, in-progress) |
| **ORANGE** | Ahead of pace / context 70-90% (warm) |
| **RED** | Context >90% / 5h alert above 80% (hot) |

Applied across the line:

| Element | Default (dim) | Deviation (highlighted) |
|---|---|---|
| Project name | — | always BOLD (the anchor where you are) |
| Branch | `main` / `master` clean | non-default → GREEN; dirty tree → YELLOW |
| Model | matches `$CC_STATUSLINE_DEFAULT_MODEL` (default `opus`) | any other model → BOLD (same "deviation matters" semantic) |
| Session bar | <50% → GREEN (cool) | 50→70→90% → YELLOW→ORANGE→RED |
| Pace bar | behind pace → GREEN | on pace → YELLOW → ahead → ORANGE |
| Fast mode | off (no marker) | on → ORANGE+BOLD `↯FAST` after the model |

Glance at the line: if everything is dim, you're on the rails. Color or weight means look here.

The Fast-mode marker earns its loudness: [Fast mode](https://platform.claude.com/docs/en/build-with-claude/fast-mode) bills at roughly $30/$150 per Mtok — the same Opus underneath, trading a large cost premium for lower latency. Easy to leave on by accident, so the line flags it explicitly (`↯` mirrors Claude Code's own indicator). The model slug is unchanged, since the model itself hasn't.

### Two Usage Bars, One Visual Language

Both bars use identical `█░` characters and the same warm-up direction (cool = headroom, warm = burning through it). The difference is what fuels the temperature:

**Session bar** — context fullness (threshold-based):
- Green (<50%) → Yellow (50-70%) → Orange (70-90%) → Red (>90%)

**User bar** — 7-day pace (delta-based):
- Green (behind ≤-5%) → Yellow (on pace) → Orange (ahead ≥5%)

Same form, same direction, different semantics. When both are cool, you have plenty of context *and* plenty of weekly headroom. When both are warm, you're using what you paid for.

### Subscription as Investment, Not Budget

The User Usage bar is built on a specific value judgment: on a Max subscription, unused tokens are wasted value, not saved budget.

The pace formula compares actual usage against expected usage for this point in the 7-day window:

```
pace_delta = used_percentage - elapsed_percentage
elapsed    = (window_total - time_remaining) / window_total × 100
```

Earlier versions colored "ahead of pace" green to celebrate strong utilization. Lived-in use turned that into a friction: warm colors instinctively read as warnings, and fighting that instinct every glance is cognitive tax for no payoff. So the color rule was flipped to match popular psychology — ahead of pace = orange, behind = green — and a 🔥 easter egg was added past `$CC_STATUSLINE_EASTER_EGG_AT` (default 80%) as the quiet counter-signal: *that "scary" color is success.* Set `CC_STATUSLINE_EASTER_EGG=""` to disable, or pick your own stamp.

### 5-Hour Alert

The 5-hour burst window appears only when usage exceeds 80%. It shows two dynamic values:

```
91% 3h    (usage percentage + countdown to reset)
```

No static "5h" label — that's a window name, not useful data. The countdown tells you how long until the constraint lifts.

## Customization

This is a shell script, not a framework. Fork it, edit it, make it yours.

Three env vars are honored out of the box:

| Variable | Default | Effect |
|---|---|---|
| `CC_STATUSLINE_DEFAULT_MODEL` | `opus` | substring match — models whose slug contains this string render dim |
| `CC_STATUSLINE_EASTER_EGG` | `🔥` | stamp appended when 7d usage crosses the threshold; set to `""` to disable |
| `CC_STATUSLINE_EASTER_EGG_AT` | `80` | integer percentage threshold for the stamp |

A few internals worth knowing if you start hacking:

- **Git cache**: Branch/dirty state is cached for 5 seconds to avoid blocking on large repos
- **Dynamic assembly**: Sections join with `│` only when non-empty — no ghost separators
- **`project_dir` not `cwd`**: Location uses the launch directory, not the current `cd` path — the anchor should be stable
- **User Usage requires a Claude.ai subscription** (Pro/Max) — the `rate_limits` field is absent for free-tier users; the zone simply won't appear

## Background

Each release is driven by a specific design problem, not feature accumulation:

- **v0.1.0** — Four-zone information architecture; pace-aware 7d bar with "ahead = green" investment framing
- **v0.2.0** — Highlight inversion (bright = deviation, dim = default); pace colors flipped to match popular psychology; 🔥 easter egg added as the counter-signal that high consumption on a Max plan is success, not a warning

See [`docs/roadmap.md`](docs/roadmap.md) for what's next.

Full design rationale and iteration history: [Designing a Claude Code Status Line](https://dongzhenye.com/posts/claude-code-statusline) | [Rate Limits: An Investment, Not a Budget](https://dongzhenye.com/posts/claude-code-statusline-subscription-utilization)

## License

MIT
