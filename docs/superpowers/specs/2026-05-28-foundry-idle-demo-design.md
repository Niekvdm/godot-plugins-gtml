# Foundry — Commit Idle Demo (design spec)

**Date:** 2026-05-28
**Status:** Approved (brainstorm)
**Type:** New showcase example for the GTML addon

## Goal

Add a *fully fledged* game example to `addons/gtml/examples/showcase/` — an
idle/clicker game — that exercises GTML's headline reactive features end to end
in a real game loop. The existing showcases are single-screen UI panels;
`inventory` is the only one with a game script. `foundry` is the first showcase
that is an actual playable game.

The demo stays a **GTML/UI showcase**: all interesting behavior is expressed as
markup + bindings; the GDScript side holds only the minimal game math (tick
accrual, purchase logic, derived display strings). Session-only — no disk I/O.

## Theme

Godot-meta. You write **Commits**. Hire auto-producers, buy one-time
**Upgrades** that multiply output, unlock **Achievements**, and **Refactor**
(prestige) to reset for a permanent multiplier.

Folder name: `foundry` (single word, matches atlas / atelier / forge / kitchen /
inventory).

## Files

```
addons/gtml/examples/showcase/foundry/
  index.html      markup + all bindings
  style.css       Godot-dark palette, flex, transitions, :class buckets
  demo.gd         game logic (tick loop, purchases, derived state)
  demo.gd.uid     tracked alongside the script
  demo.tscn       a GtmlView wired to html_path + css_path
```

`demo.tscn` follows the other showcases: one `GtmlView` node, script
`res://addons/gtml/src/GtmlView.gd`, with `html_path`/`css_path` pointing at the
sibling `index.html` / `style.css`. The game script `demo.gd` is attached to the
scene root (a `Control`) and references the view via `@onready var view: GtmlView`.

## Reactive flow (the showcase core)

`demo.gd` is the single source of truth. State pushed into `view.state`:

| Key | Type | Purpose |
|---|---|---|
| `commits_display` | String | Headline counter, pre-formatted (e.g. `1.23K`) |
| `per_sec_display` | String | Production rate label |
| `per_click_display` | String | Commits per tap |
| `insight` | int | Prestige currency held |
| `mult_display` | String | Current global multiplier label |
| `generators` | Array[Dictionary] | Auto-producer rows (see shape below) |
| `upgrades` | Array[Dictionary] | **Unpurchased** upgrades only |
| `achievements` | Array[Dictionary] | All achievements with `earned` flag |
| `toast` | String | Transient achievement-unlock message (`""` when hidden) |
| `show_refactor` | bool | Prestige confirmation modal visibility |
| `refactor_gain` | String | Insight the pending refactor would grant |

**Generator row shape:**
`{ id, name, desc, owned, cost_display, rate_display, affordable }`

**Upgrade row shape:**
`{ id, name, desc, cost_display, affordable }`

**Achievement row shape:**
`{ id, name, desc, earned }`

### Tick loop

`_process(delta)`:
1. Accrue `commits += per_sec * delta` (float; `per_sec` derived from owned
   generators × their base rate × global multiplier).
2. Push the **headline counter every frame**: `state.set("commits_display", fmt(commits))`
   and `per_sec_display`. This is the live idle-game hook — a per-frame
   `state.set` driving an interpolated `{{ }}`.
3. **Throttled derive (~10 Hz):** an accumulator recomputes affordability flags
   + cost strings and re-sets the `generators` / `upgrades` arrays only ~10×/sec,
   not every frame, so the `v-for` reconciler is not hammered at 60fps. The
   diff-and-set keeps focus/scroll stable and is itself a performance talking
   point. (If a purchase happens between ticks, derive runs immediately so the
   UI never looks stale after a click.)

### Number formatting

`fmt(n: float) -> String` lives in GDScript: plain integer below 1000, then
`K`/`M`/`B`/`T` suffixes with two decimals. State stores the pre-formatted
strings (same pattern as `inventory`'s `selected_*` fields). Templates never do
suffix math — they only interpolate ready strings and evaluate simple booleans.

## Layout (header + single scroll)

GTML has no CSS `position: sticky`, so the fixed-header effect is achieved
structurally: a non-scrolling header sibling above a scrolling body.

```
root (flex column, height 100%)
├── header  (flex: none)
│     {{ commits_display }}   ·   {{ per_sec_display }}/s
│     [ Commit ]  @click="tap"          (large primary button)
│     Insight: {{ insight }} · ×{{ mult_display }}   [ Refactor ] @click="open_refactor"
└── body  (overflow-y: auto; flex-grow)
      ├── Generators section
      ├── Upgrades section
      └── Achievements section
└── refactor modal overlay  (v-if="show_refactor", focus-trap)
```

### Generators section
`v-for="g in generators" :key="g.id"`. Each row:
- `{{ g.name }}` · `owned {{ g.owned }}` · `{{ g.rate_display }}/s` · cost `{{ g.cost_display }}`
- Buy button: `:disabled="!g.affordable"`, `:class="{ affordable: g.affordable }"`,
  `@click="buy(g.id)"`.
- Crossing the price threshold restyles the row live (`:class` re-resolution).

### Upgrades section
`v-for="u in upgrades" :key="u.id"` over **unpurchased only**. Buying an upgrade
removes it from the array → keyed reconciliation removes one node while the
siblings keep Control identity (the flagship feature). Buy button uses the same
`:disabled` / `:class` affordability pattern and `@click="buy_upgrade(u.id)"`.

### Achievements section
`v-for="a in achievements" :key="a.id"` badge grid. `:class="{ earned: a.earned }"`
toggles locked → earned styling live. A transient toast
(`v-if="toast"`, with a CSS transition) pops when an achievement unlocks; cleared
after ~3s via a `Timer` / `await`.

### Refactor (prestige) modal
Header **Refactor** button sets `show_refactor = true`. The overlay
(`v-if="show_refactor"`, container marked `focus-trap`) shows the pending
`refactor_gain` Insight and Confirm / Cancel buttons — a keyboard/gamepad focus
showcase. Confirm resets `commits`, all generator `owned`, and the purchased-set;
adds Insight; recomputes the global multiplier; closes the modal.

## Game content

**Generators** (base cost, base rate/s; cost scales ×1.15 per owned):

| id | name | base cost | base rate/s |
|---|---|---|---|
| intern | Intern | 10 | 0.5 |
| compiler | Compiler | 120 | 4 |
| ci_farm | CI Farm | 1 500 | 25 |
| render | Render Server | 20 000 | 160 |
| linter | Quantum Linter | 250 000 | 1 000 |

`cost(owned) = floor(base_cost * 1.15 ^ owned)`.

**Upgrades** (one-time; each gated by a threshold):

| id | name | effect | gate |
|---|---|---|---|
| keyboard | Mechanical Keyboard | per_click ×2 | 50 commits |
| hotreload | Hot Reload | Intern output ×2 | own 5 Interns |
| ssd | NVMe Array | Compiler output ×2 | own 5 Compilers |
| distcc | Distributed Build | CI Farm output ×2 | own 5 CI Farms |
| caffeine | Infinite Caffeine | per_click ×3 | 5 000 commits |
| gpu | GPU Cluster | Render output ×2 | own 5 Render Servers |

Upgrade multipliers apply to the relevant generator's effective rate (or to
`per_click`). Internally each upgrade carries a small effect descriptor the
recompute step reads.

**Achievements** (~8, evaluated each derive tick):

| id | name | condition |
|---|---|---|
| first | First Commit | commits ≥ 1 |
| ten_interns | Onboarding | own 10 Interns |
| kilo | Kilocommit | commits ≥ 1 000 |
| mega | Megacommit | commits ≥ 1 000 000 |
| first_refactor | Tech Debt Paid | refactored ≥ 1 |
| five_gens | Full Stack | own ≥ 1 of every generator |
| upgrader | Optimizer | bought ≥ 3 upgrades |
| insightful | Enlightened | insight ≥ 10 |

**Refactor / prestige:** Insight gained on confirm =
`floor(sqrt(total_commits_this_run / 10_000))`. Global multiplier =
`1 + insight * 0.02` (held insight is cumulative across refactors). Refactor
resets `commits`, generator `owned`, and purchased upgrades; keeps `insight`,
multiplier, and earned achievements.

## Components / responsibilities

- **`index.html`** — pure markup + bindings. No game numbers. Declares the
  header, the three `v-for` sections, and the refactor modal.
- **`style.css`** — palette, flex layout, the `affordable` / `earned` / modal /
  toast buckets, and transitions. Reuses the look of the existing showcases
  (dark Godot-ish theme).
- **`demo.gd`** — game logic, organized as: data tables (consts), `_ready`
  (seed state + connect signals), `_process` (tick + headline push), `_derive`
  (throttled recompute of arrays + achievements), purchase handlers (`tap`,
  `buy`, `buy_upgrade`), refactor handlers, and the `fmt` helper. Signals used:
  `button_clicked` (tap, open/confirm/cancel refactor) and `item_clicked`
  (buy / buy_upgrade with the row id as the arg).
- **`demo.tscn`** — wiring only.

Signal routing follows GTML's contract: `@click="tap"` (no parens) →
`button_clicked("tap")`; `@click="buy(g.id)"` → `item_clicked("buy", [id])`.

## Testing

**Unit** — `tests/unit/test_foundry_demo.gd` (GUT, headless, no rendering).
Instantiate `demo.gd` and assert pure logic:
- `fmt()` boundaries (999 → `999`, 1000 → `1.00K`, 1_500_000 → `1.50M`).
- `cost(owned)` scaling matches `floor(base * 1.15^owned)`.
- Buying deducts cost, increments `owned`, recomputes `per_sec`.
- Buying an upgrade removes it from the unpurchased list and applies its effect.
- Affordability flag flips correctly around the exact cost boundary.
- Refactor insight formula and multiplier; reset clears the right fields and
  preserves insight + achievements.

To keep logic testable in isolation, purchase/derive/format functions must not
depend on `view`/rendering — they operate on the script's own fields and return
plain data. `_ready`/`_process` are the only members that touch `view`.

**Manual** — run `foundry/demo.tscn`: counter ticks smoothly, buying a generator
restyles the row and raises `/s`, buying an upgrade removes its card with
siblings intact, an achievement toast pops, and the Refactor modal traps focus
and resets correctly on Confirm.

## Out of scope (YAGNI)

- Disk persistence / offline progress (session-only by decision).
- Sound, particles, animated sprites — this is a UI showcase.
- Balancing for long-term play; numbers just need to demonstrate the loop.
- A README entry / docs table update — handled separately if desired.
