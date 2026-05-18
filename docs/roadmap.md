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

## Backlog (next phase TBD)

Things noticed but not yet in flight. Promoted to a real phase when batchable.

- Tiered easter egg (🔥 → 🚀 → 💎 across thresholds) — open question whether one-tier is enough
- Optional dual-layer pace bar (top = actual, bottom = expected) using `▀` with fg/bg — `expected_filled` was wired up in Phase B but not rendered
- `develop` / `trunk` as default-branch synonyms (currently only `main`/`master` get the dim treatment)
- Width-aware truncation for very long project names or branch names
