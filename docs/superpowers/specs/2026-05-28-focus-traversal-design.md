# GTML v0.8.3 — Focus traversal (keyboard / gamepad navigation)

**Date:** 2026-05-28
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.8.3 (fourth v0.8 production-readiness PR; the perf bench is a separate follow-up)

## Summary

GTML produces Godot Controls but does nothing to make them keyboard- or
gamepad-navigable. Native form controls (Button, LineEdit, …) are
accidentally Tab-reachable because Godot defaults them to `FOCUS_ALL`,
but every GTML mouse-clickable — `@click` labels, `<a>` anchors,
clickable `<div>`s, v-for item rows — is `FOCUS_NONE` and unreachable
without a mouse. There is no deterministic Tab order, no initial focus,
and no focus trap for modals. This blocks console / Steam Deck use,
where there is no pointer.

v0.8.3 adds a focus-traversal layer: every interactive element becomes
focusable, a deterministic Tab chain is wired in document order (with
full HTML `tabindex` semantics), `autofocus` grabs initial focus,
`focus-trap` cycles focus within a modal subtree, and the chain stays
correct across v-for reconciliation.

```html
<div focus-trap>
  <input v-model="search" autofocus>
  <button @click="confirm">OK</button>
  <button @click="cancel">Cancel</button>
</div>
```

Tab cycles search → OK → Cancel → search; the search input owns focus
on open; a gamepad's next/prev follows the same chain.

## Goals

- Make every interactive element keyboard/gamepad reachable.
- Deterministic Tab order from document order + `tabindex`.
- `autofocus` initial focus; `focus-trap` modal cycling.
- Chain stays correct after `_rebuild` AND v-for reconciliation.
- Preserve focus across reconciliation (consistent with v0.8.1).

## Non-goals

- **Directional (arrow / d-pad) neighbor wiring.** We set `focus_next`/
  `focus_previous` (sequential) only; Godot's built-in geometry-based
  neighbor search handles up/down/left/right. Reimplementing that is out
  of scope.
- **Roving tabindex / composite widgets** (a grid that's one Tab stop
  with internal arrow nav). Each focusable is its own Tab stop.
- **Focus-visible styling.** `:focus` CSS already exists (v0.x); this PR
  is traversal only.
- **Perf benchmark harness.** Separate follow-up PR.
- **Screen-reader / accessibility tree.** Unrelated.

## Architecture

```
addons/gtml/src/focus/GmlFocusManager.gd   # NEW — wire_focus(root) (~160 LOC)
addons/gtml/src/html_renderer/GmlRenderer.gd  # MODIFY — _stamp_focus_meta in _build_node
addons/gtml/src/GmlView.gd                 # MODIFY — call wire_focus post-build; focus_first() API
tests/unit/test_focus_manager.gd           # NEW — ~12 tests
tests/unit/test_binding_integration.gd     # MODIFY — +6 tests
docs/bindings.md or docs/focus.md          # focus docs
CHANGELOG.md                               # 0.8.3 entry
addons/gtml/plugin.cfg                     # 0.8.2 → 0.8.3
```

Two-phase design:
- **Build-time (per element):** `_stamp_focus_meta(control, node)` decides
  *what is focusable* and stamps focus metadata + sets `focus_mode`.
- **Post-build (whole tree):** `GmlFocusManager.wire_focus(root)` decides
  *the order* — needs the full tree, so it's a separate pass.

This split keeps per-element classification local and global ordering
centralized + unit-testable.

## §1 — Focusability + meta stamping

`_stamp_focus_meta(control, node)` is called in `GmlRenderer._build_node`
after dispatch (alongside the existing `_register_bindings_for_node`).

An element is **focusable** if any of:
- native form control: `Button`, `LineEdit`, `TextEdit`, `CheckBox`,
  `OptionButton`, `HSlider` (control-type check on the built control),
- `node.tag == "a"` (anchor),
- node has any `@event` / `@click` attribute (classified v-on),
- node has `tabindex` >= 0.

Stamped meta on the Control:
- `_gml_focusable: bool`
- `_gml_tabindex: int` — parsed from `tabindex` attr; default `0` for
  focusables without an explicit value.
- `_gml_tab_skip: bool` — `true` when `tabindex == -1` (focusable via
  `grab_focus` / click, excluded from the Tab chain).
- `_gml_autofocus: bool` — from presence of `autofocus` attr.
- `_gml_focus_trap: bool` — from presence of `focus-trap` attr (stamped
  on the container control).

Focusables get `control.focus_mode = Control.FOCUS_ALL`. For natives this
normalizes (already FOCUS_ALL); for clickable labels/anchors/divs it is
the opt-in that makes them keyboard-reachable. A `tabindex == -1` element
is still focusable (FOCUS_ALL) but `_gml_tab_skip = true`.

**HTML parser**: `tabindex`, `autofocus`, `focus-trap` are plain attribute
names (no `:` / `@` / `v-` prefix) — already parsed into `node.attrs` by
the existing parser. No parser change. `tabindex` value is read via
`node.get_attr("tabindex", "")` and `.to_int()` (Godot returns 0 for
non-numeric, so guard the "absent vs 0" distinction by checking presence
first).

## §2 — GmlFocusManager.wire_focus

```gdscript
class_name GmlFocusManager
extends RefCounted

## Walk a built Control tree and set up keyboard/gamepad focus traversal
## from the _gml_* focus meta stamped at build time. Idempotent — safe to
## re-run after every rebuild / v-for reconcile.
static func wire_focus(root: Control) -> void

## Collect focusables in document (pre-order) order. Each entry:
##   {control, doc_order, tabindex, tab_skip, trap_group}
## trap_group = the nearest ancestor Control with _gml_focus_trap, or null
## (the root group).
static func _collect(root: Control) -> Array

## The control that should receive initial focus (first _gml_autofocus in
## doc order), or null.
static func find_autofocus(root: Control) -> Control
```

Algorithm:

1. **Collect** via pre-order walk (= DOM order, since children are added
   in document order). Record `doc_order` (walk index), `tabindex`,
   `tab_skip`, and `trap_group` (nearest `_gml_focus_trap` ancestor or
   null).

2. **Group** focusables by `trap_group` (null = root group).

3. **Per group**, compute the Tab order with HTML `tabindex` rules,
   excluding `tab_skip` controls:
   - Bucket A: `tabindex > 0`, sorted ascending; ties by `doc_order`.
   - Bucket B: `tabindex == 0` (or absent-on-interactive), in `doc_order`.
   - order = A ++ B.

4. **Wire** each group's ordered list:
   - `list[i].focus_next = list[i+1].get_path()`,
     `list[i].focus_previous = list[i-1].get_path()`.
   - Mirror onto `focus_neighbor_bottom` / `focus_neighbor_top` so a
     gamepad's sequential next/prev matches Tab.
   - Clear (`NodePath("")`) the dangling ends per the wrap rule below.

5. **Trap wrapping**: a `_gml_focus_trap` group's chain wraps —
   `last.focus_next = first`, `first.focus_previous = last`. The root
   (non-trap) group does NOT wrap: `first.focus_previous` and
   `last.focus_next` are cleared (Tab at the last element stays put;
   there's no browser chrome to escape to).

6. **Nested traps**: `trap_group` is the *nearest* trap ancestor, so an
   inner trap's items form their own group and don't leak into the outer
   group; outer items are excluded from the inner group. Innermost wins
   from the nearest-ancestor rule.

7. **Autofocus**: `find_autofocus(root)` returns the first
   `_gml_autofocus` control in doc order; `wire_focus` calls
   `call_deferred("grab_focus")` on it. If none, focus is untouched
   (never steal focus).

`focus_mode` is set at build time (§1), not here — `wire_focus` only
arranges order. A control that lost its `_gml_focusable` meta is simply
not collected.

## §3 — Integration + focus preservation

- **GmlView**: after `renderer.build()` returns `ui_root`, call
  `GmlFocusManager.wire_focus(ui_root)`. Add public
  `focus_first() -> bool` — grabs the first Tab-order focusable (root
  group, order[0]); returns `false` if none. For game code seizing focus
  on menu open.

- **v-for reconcile**: at the end of `_reconcile_v_for_region` (after the
  op-batch), re-run `wire_focus` on the view's content root so inserted
  clones join the chain and removed clones drop out.

- **Focus preservation across reconcile**: `wire_focus` only sets
  neighbor NodePaths — it never calls `grab_focus` except for the
  one-time autofocus on a fresh build. A control that survives a reconcile
  keeps focus. If the focused control was removed, focus clears (game code
  may re-grab). This matches the v0.8.1 Control-identity guarantee.

- **Autofocus only on fresh build, not on reconcile**: track a
  `_focus_initialized` flag on the view so `autofocus` grabs once per
  `_rebuild`, not on every subsequent reconcile (which would yank focus
  back to the autofocus element on every list change).

- **Stale NodePaths**: `focus_next` stores a NodePath; a later reconcile
  that frees a control would dangle it. Mitigated: every reconcile
  re-runs `wire_focus`, recomputing all paths from the live tree
  synchronously before the freed node (`queue_free`, end-of-frame) is
  gone. Idempotent re-wiring clears+rewrites all four neighbor properties
  each run.

## §4 — Testing plan

Target: 385 → **~403** (18 new).

### Focus manager unit tests (~12) — `test_focus_manager.gd`

Build Controls directly, stamp `_gml_*` meta, call `wire_focus`, assert
`focus_next` / `focus_previous`:

- Two focusables in DOM order → forward + backward links correct.
- Non-focusable controls excluded from the chain.
- `tabindex == -1` (tab_skip) focusable but excluded; neighbors route around.
- `tabindex > 0` ordered before natural; e.g. `[b=2, a=0, c=1]` → `c, b, a`.
- positive-tabindex tie broken by doc order.
- `focus-trap` group wraps (last→first, first→last).
- root group does NOT wrap (ends cleared).
- nested trap: inner items isolated from outer group + vice versa.
- `find_autofocus` returns the first autofocus control in doc order.
- empty tree / no focusables → no crash.
- idempotent: two `wire_focus` runs yield identical chains.
- `focus_neighbor_bottom/top` mirror `focus_next/previous`.

### Integration tests (~6) through GmlView

- Two `<button>`s → A.focus_next resolves to B's control.
- `<span @click="x">` becomes focusable (FOCUS_ALL).
- `<a href>` anchor focusable.
- `autofocus` on an input → owns focus after build (await frames,
  `get_viewport().gui_get_focus_owner()`).
- `<div focus-trap>` with two buttons → chain wraps within.
- v-for: focus an item's input, append an item → focused input still
  owns focus AND the new clone is chained (its `focus_previous` resolves
  to the prior last item).

## §5 — Phasing

Single bundled PR. Tasks:

1. `GmlFocusManager.wire_focus` + `_collect` + `find_autofocus` + 12 unit
   tests (pure-ish, synthetic Control trees).
2. Renderer `_stamp_focus_meta` (focusability + meta + focus_mode) — no
   ordering yet; verify natives + clickables get FOCUS_ALL.
3. GmlView wiring (call `wire_focus` post-build; `focus_first()`;
   `_focus_initialized` flag; autofocus once per rebuild).
4. v-for reconcile re-wire hook.
5. Integration tests (6).
6. Docs + CHANGELOG 0.8.3 + version bump.
7. Push + PR.

## §6 — Known limitations (documented)

- Directional (arrow/d-pad) navigation uses Godot's built-in geometry
  search, not an explicit grid model — wrapped/flex layouts may pick
  non-obvious directional neighbors. Sequential Tab/next-prev is exact.
- No roving-tabindex composite widgets (each focusable is its own stop).
- Root group does not wrap (Tab at the last element stays put).
- `autofocus` grabs once per rebuild; if multiple elements declare it,
  the first in doc order wins.

## §7 — Out of scope (deferred)

- Perf benchmark harness (separate PR — the remaining v0.8 item).
- Directional neighbor model / roving tabindex.
- Focus-visible-only styling distinctions.
- Accessibility / screen-reader tree.
