# Foundry CRT-Terminal Reskin (design spec)

**Date:** 2026-05-28
**Status:** Approved (brainstorm)
**Type:** Visual reskin of the `foundry` showcase demo

## Goal

Make the `foundry` idle demo look like a proper game/demo by reskinning it as a
**CRT terminal** ("commits on a green phosphor console") — on-theme with the
Godot/commit/code premise. Game logic is unchanged; this is presentation plus
two trivial display additions.

Constraints respected (from `docs/reference/css-properties.md`):
- Padding is uniform per side (use `padding-*` for asymmetry).
- `box-shadow` requires a background/border to attach to.
- No absolute positioning / z-index — so no floating overlay; the refactor
  confirm swaps in as a full screen instead.

## Palette & typography

- Background near-black green `#020600`; panels `#04140a`, borders `1px solid #1f7a45`, dashed dividers.
- Phosphor green: `#39ff8a` (bright), `#1faf5f` (dim), `#0e6b3a` (faint).
- Glow via `text-shadow` on the counter and section/heading text.
- One accent: **amber `#ffcf4d`** — Insight, the `×` multiplier, earned achievements, toast. No red.
- Font: **Courier Prime** (SIL OFL). Copy `CourierPrime-Regular.ttf`,
  `CourierPrime-Bold.ttf`, and `OFL.txt` from `addons/gut/fonts/` into
  `addons/gtml/examples/showcase/foundry/fonts/` (no cross-addon dependency).
  Wire on the GtmlView node: `fonts = {"Mono": <Regular>, "Mono-Bold": <Bold>}`.
  CSS uses `font-family: Mono` globally; `font-weight: bold` picks `Mono-Bold`
  (GtmlStyles resolves `"<family>-Bold"`).

## Layout (keeps header + scroll body)

**Header → console**
- Faint prompt line `foundry@godot:~$`.
- Big glowing counter `{{ commits_display }} commits`, then `▸ {{ per_sec_display }}/s`.
- `[ COMMIT +{{ per_click_display }} ]` and `[ REFACTOR ]` as bracketed commands
  with a green `box-shadow` glow on `:hover`/`:focus`.
- `Insight: {{ insight }}` and `×{{ mult_display }}` in amber.

**Body sections**
- Section header = bold label with a dashed `border-bottom` (ASCII-rule feel),
  e.g. `── GENERATORS ─────────`.
- Generator / upgrade rows: bordered terminal boxes. Name bold green; desc + stat
  dim. Cost button `[ {{ g.cost_display }} ]`. `:class="{ affordable }"` →
  bright border + glow; unaffordable → dim + `:disabled`.
- Achievements: a checkbox list, one line each: `{{ a.mark }} {{ a.name }}`
  where `mark` is `[x]` (earned, amber via `:class`) or `[ ]` (locked, dim).
- Toast: a log line `{{ toast }}` in amber with glow (text already carries the
  `>> unlocked: ` prefix from `demo.gd`).

**Refactor confirm (screen swap, not overlay)**
- Body wrapped with `v-show="!show_refactor"`.
- A sibling `v-if="show_refactor"` centered confirm screen: the prompt
  `REFACTOR? reset this run for {{ refactor_gain }} Insight` and
  `[ CONFIRM ]` / `[ CANCEL ]` (Confirm `autofocus`, container `focus-trap`).
- The existing `.modal-overlay` markup is replaced by this confirm screen.

## demo.gd changes (minimal)

- `build_achievements_view()` adds a `mark` field: `"[x]"` when earned, else `"[ ]"`.
- The achievement toast string is prefixed `>> unlocked: ` (in `_show_toast`'s
  caller `_derive`, or `_show_toast`).
- Everything else — tick loop, cost scaling, purchases, prestige, the
  diff-guarded `_derive`, the `_last_gens`/`_last_ups` caches — is unchanged.

## Files touched

- `addons/gtml/examples/showcase/foundry/style.css` — full reskin.
- `addons/gtml/examples/showcase/foundry/index.html` — console header, ASCII
  section headers, checkbox achievements, confirm-screen swap.
- `addons/gtml/examples/showcase/foundry/demo.gd` — `mark` field + toast prefix.
- `addons/gtml/examples/showcase/foundry/demo.tscn` — `fonts` dict on GtmlView.
- `addons/gtml/examples/showcase/foundry/fonts/` — Courier Prime Regular + Bold + OFL.txt (new).

## Testing

- Existing GUT suite (427) stays green; logic is unchanged. Update the
  `build_achievements_view` test to assert the new `mark` field (`"[ ]"` when
  not earned, `"[x]"` when earned).
- The scene integration smoke test still asserts a built tree + working tap.
- Manual (human, needs the editor GUI): reload the scene, confirm Courier Prime
  renders, affordability glow, amber Insight/achievements, checkbox list, and
  the refactor confirm-screen swap. (Cannot be verified headless.)

## Out of scope

- Scanlines / CRT curvature / bloom shaders (GTML can't layer overlays).
- Blinking cursor animation (no per-frame CSS animation primitive).
- Any change to game balance or mechanics.
