# Foundry — Interactive Terminal (REPL) Redesign

**Date:** 2026-05-28
**Status:** Approved (brainstorm)
**Type:** Interaction-model redesign of the `foundry` showcase demo

## Goal

Turn the foundry idle demo into a **pure interactive console (REPL)** that
doubles as a broad showcase of GTML's capabilities. The screen is a terminal:
a scrollback log you drive by running commands — by **typing** them (real
`<input>` + Enter) or by **clicking** command tokens. Game logic is unchanged;
only the view + interaction layer is rebuilt.

## Layout (three stacked zones, no panels/tabs)

```
┌ title bar ─ foundry @ godot · idle console ───────────┐
│ <scrollback log — fills remaining height>             │
│   foundry v0.8 — type `help` or click a command       │
│   $ buy                                                │
│   intern    #12   6.0/s   [10]      ← clickable        │
│   $ buy intern                                         │
│   > hired intern #13 — +0.5/s                          │
│   >> unlocked: Onboarding                              │
├ status ─ commits 1.24K · +18.0/s · insight 0 · ×1.00 ─┤
│ foundry $ [ typed input............ ]                  │
│ help  buy  upgrades  ach  stats  prestige  clear       │  ← clickable tokens
└────────────────────────────────────────────────────────┘
```

- **Title bar** — static header.
- **Scrollback log** — `overflow-y:auto`, fills height. Capped to the last ~28
  entries so the newest stays visible (GTML can't programmatically scroll).
- **Status line** — live, interpolated every frame.
- **Prompt bar** — typed input + clickable command tokens.

## State shape (additions; existing keys stay)

| Key | Type | Purpose |
|---|---|---|
| `log` | Array[Dictionary] | scrollback entries (capped, newest last) |
| `cmd` | String | the typed command (`v-model`) |
| `commits_display`, `per_sec_display`, `per_click_display`, `insight`, `mult_display` | — | reused for the live status line |

**Log entry:** `{ "id": int, "kind": String, "text": String, "actionable": bool, "ref": String }`
- `kind` ∈ `sys` (boot/dim), `cmd` (echoed command, light), `ok` (green), `warn`
  (amber), `info` (secondary), `buy_gen` / `buy_upg` / `confirm` (actionable lines).
- `actionable` lines render with a clickable affordance; clicking dispatches on
  `kind` + `ref`.

## Rendering (`index.html`)

- Log: `<div v-for="line in log" :key="line.id" class="line" :class="{ sys: ..., cmd: ..., ok: ..., warn: ..., info: ..., act: line.actionable }" @click="run_line(line.kind, line.ref)">{{ line.text }}</div>`.
  One uniform template (no nested v-for); `run_line` no-ops for non-actionable kinds.
- Status: interpolated spans.
- Input: `<input v-model="cmd" @keydown="submit" id="cmdline" autofocus>` with a `foundry $` prefix.
- Command tokens: buttons, `@click="cmd_token('help')"` etc.

## demo.gd additions (logic reused, view layer new)

- `var _log_lines: Array = []`, `var _log_id := 0`, `const LOG_CAP := 28`.
- `_log(kind, text, actionable := false, ref := "")` — append, cap, push `log` state (diff-guarded set).
- `run_command(raw: String)` — parse + dispatch:
  - `help` → list commands (sys lines).
  - `buy` → echo `$ buy`, append one `buy_gen` line per generator (`name #owned rate [cost]`, `actionable`, `ref=id`).
  - `buy <id>` → resolve generator **or** upgrade by id, purchase, append `ok`/`warn`.
  - `upgrades` / `upg` → list available upgrades as `buy_upg` lines.
  - `ach` → list achievements (`[x]/[ ]`).
  - `stats` → per-click, total commits, owned counts, insight.
  - `prestige` / `refactor` → echo gain; if `refactor_gain() >= 1` append a
    `confirm` actionable line, else `warn`.
  - `clear` → reset the log.
  - unknown → `warn` (`command not found: <x> — try help`).
- `run_line(kind, ref)` — `buy_gen`→`buy_generator(ref)`, `buy_upg`→`buy_upgrade(ref)`,
  `confirm`→`do_refactor()` + reset; else no-op. Each echoes a result line.
- `_on_key(handler, event)` — on `submit` + Enter keycode: `run_command(cmd)`, clear `cmd`.
- `cmd_token(name)` — routes a clicked token through `run_command(name)`.
- `_ready` connects `key_pressed`, `item_clicked`, `button_clicked`; seeds a boot banner.
- `_process` tick unchanged; status keys updated per frame; achievement unlocks append an `ok` line instead of the old toast.

Reused unchanged: `cost_of`, `effective_rate`, `per_sec`, `buy_generator`,
`buy_upgrade`, `_check_achievements`, `refactor_gain`, `do_refactor`, `fmt`.
The tab/badge view builders are dropped (replaced by command output).

## GTML capabilities showcased (the point)

Keyed `v-for` (growing scrollback), per-frame `{{ }}` interpolation (live
status), `:class` line-kind + affordability coloring, `@click(args)` tokens,
**`v-model` two-way input**, **`@keydown` → run typed command** (`key_pressed`),
`v-show` (cursor/empty states), expressions/comparisons, `autofocus`, opacity
transitions on new lines.

## Testing

- Logic untouched → existing unit tests stay green (drop/replace only the
  `build_achievements_view` `mark`/tab assertions that no longer apply; keep the
  pure-logic tests).
- New unit tests for the view-agnostic helpers on `demo.gd`:
  - `run_command("buy")` populates actionable `buy_gen` log lines for every generator.
  - `run_command("buy intern")` with enough commits purchases (owned +1) and logs `ok`; without enough logs `warn`.
  - `run_command("clear")` empties the log; boot banner present after `_seed_log`.
  - unknown command logs a `warn`.
  - log cap holds at `LOG_CAP`.
  These operate on `_log_lines` (no `view`), keeping them headless.
- Integration smoke test: scene builds, status seeded, a `cmd_token('buy')`
  click adds lines, no label shows literal `{{ }}`.
- Manual (human): typing `buy intern` + Enter, clicking tokens, prestige confirm.

## Risks / mitigations

- **Typed input Enter** — verified `key_pressed` fires with the key event;
  clicking tokens is the always-works fallback if a keycode quirk appears.
- **Auto-scroll** — not available; mitigated by capping visible lines to `LOG_CAP`.
- **`v-model` clear** — `cmd` reset to `""` must push back to the LineEdit;
  verify two-way during build.

## Out of scope

- Command history (up-arrow), tab-completion, free-form aliases.
- Real shell semantics beyond the listed commands.
- Sound, scanlines, cursor blink (no per-frame CSS animation).
