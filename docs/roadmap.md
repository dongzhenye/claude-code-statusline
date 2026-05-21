# Roadmap

Phase letters track investment milestones; release tags track code contracts. See [`meta/WORKFLOW.md §2`](https://github.com/dongzhenye) for the convention.

## Phase A — Initial Release ✅ (released as v0.1.0, 2026-04-06)

- [x] Four-zone information architecture (Location / Model / Session / User)
- [x] Single-script implementation, `jq` as only external dependency
- [x] Git cache for branch + dirty state (5-second TTL)
- [x] Pace-aware 7d bar (delta vs elapsed window)
- [x] Conditional 5h alert above 80%
- [x] Public release: README, MIT license, blog post

## Phase B — Highlight Rules & Pace Color Flip (will release as v0.2.0)

Driven by lived-in feedback after several weeks of daily use. The original design colored everything that was instrumented; the eye then has nothing to land on. This phase makes "default / boring" the dim baseline so highlighted things actually signal something.

- [x] Project name bold (the anchor of where you are)
- [x] Branch: main/master clean dim, other branches green, dirty yellow
- [x] Model: matches `$CC_STATUSLINE_DEFAULT_MODEL` (default "opus") dim, others cyan
- [x] Pace bar colors flipped: high consumption = orange (matches popular "warning" reading, even though high consumption on Max is the goal)
- [x] Heavy-consumption easter egg 🔥 (env-configurable symbol + threshold) — counter-signal to the inverted color
- [x] README rewritten to reflect new color semantics
- [ ] Tag v0.2.0 + GitHub release

## Phase C — Fast-Mode Cost Indicator (will release as v0.3.0)

Fast mode (toggled via `/fast`) runs the same Opus but bills at ~$30/$150 per Mtok — easy to leave on by accident. The status line was blind to it: `model.id` / `display_name` are identical whether Fast is on or off, so the model zone rendered the same dim `opus-4.7-1m` either way. Claude Code 2.1.x exposes the state as a top-level `fast_mode` boolean in the status line JSON (confirmed empirically; undocumented as of 2026-05).

- [x] Read `fast_mode` from status line JSON
- [x] Append ORANGE+BOLD `↯FAST` after the model when active (matches CC's own `↯` indicator; "warm = warrants attention" semantic)
- [x] README highlight table + Fast-mode rationale
- [ ] Tag v0.3.0 + GitHub release

## Backlog (next phase TBD)

Things noticed but not yet in flight. Promoted to a real phase when batchable.

- Tiered easter egg (🔥 → 🚀 → 💎 across thresholds) — open question whether one-tier is enough
- Optional dual-layer pace bar (top = actual, bottom = expected) using `▀` with fg/bg — earlier draft started the wiring but reverted before merge; full implementation deferred to a real phase
- `develop` / `trunk` as default-branch synonyms (currently only `main`/`master` get the dim treatment)
- Width-aware truncation for very long project names or branch names
