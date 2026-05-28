# GTML v0.8.2 — Dynamic :class CSS re-resolution

**Date:** 2026-05-28
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.8.2 (third of four v0.8 production-readiness PRs)

## Summary

Since v0.7, `:class` bindings only write a `dynamic_classes` meta on the
Control — they do NOT re-resolve CSS. Adding a class at runtime pulls in
nothing. Authors work around this by declaring every state in a separate
explicit class at build time and toggling with `v-show`/`v-if`, or by
precomputing the styled outcome. That's the documented v0.7/v0.8.1
limitation.

v0.8.2 makes dynamic `:class` actually restyle the element. When a
`:class` binding changes the active class set, the element's **visual**
properties (color, background, border, opacity, font-size) are
recomputed from the merged class list and re-applied in place — through
the same transition system that `:hover` uses, so changes animate when a
`transition` is declared and snap otherwise.

```html
<span :class="{ rare: is_rare }">{{ item.name }}</span>
```
```css
.rare { color: #b59aff; }
```
```gdscript
view.state.set("is_rare", true)   # span's font color now actually turns purple
```

## Goals

- Dynamic class changes restyle the bound element's visual properties.
- Reuse the existing transition/stylebox-mutation path (no new
  animation system, consistent with `:hover`).
- No structural re-wrapping — the v0.8.1 Control-identity guarantees
  (focus/scroll/animation) are preserved.
- Retain the parsed CSS rules on the view so re-resolution has the data.

## Non-goals

- **Layout / structural properties** in dynamic classes (`display`,
  `flex-*`, `width`, `height`, `padding`, `margin`, `gap`, `position`).
  These need re-wrapping; ignored + warned. Authors keep using
  `v-if`/`v-show` for layout swaps.
- **Descendant re-resolution from an ancestor's dynamic class.**
  `.card.selected .name { … }` does NOT restyle the child `.name` when
  `selected` toggles on the card. Only the element carrying the `:class`
  binding restyles. Documented limitation (see §6).
- **Hover-bucket recompute against the new class set.** If hovering when
  a dynamic class changes, hover wins until it ends, then the new base
  shows. Documented (see §3).
- **Font-family swaps.** Only `font-size` is re-applied; family stays as
  resolved at build.

## Architecture

```
addons/gtml/src/css/GmlClassRestyler.gd   # NEW — recompute visual style
                                          #   for (node, dynamic_classes) +
                                          #   apply deltas in place (~120 LOC)
addons/gtml/src/GmlView.gd                # MODIFY — retain _css_rules after _rebuild
addons/gtml/src/html_renderer/GmlRenderer.gd  # MODIFY — thread ancestor_chain;
                                          #   register restyle callback; base snapshot
addons/gtml/src/binding/GmlBindingApplier.gd  # MODIFY — register_class_binding
                                          #   gains optional on_change callback
addons/gtml/src/css/GmlStyleResolver.gd   # (reuse) _compute_style as recompute seam
tests/unit/test_class_restyler.gd         # NEW — ~10 tests
tests/unit/test_binding_integration.gd    # MODIFY — +6 tests
```

### Data flow on `:class` change

1. The `:class` binding's `apply` runs (existing): writes `dynamic_classes`
   meta. THEN invokes the new `on_change` callback (if provided).
2. The callback calls `GmlClassRestyler.restyle(control, node,
   ancestor_chain, dynamic_classes, css_rules, base_snapshot,
   transition_manager)`.
3. The restyler re-runs `GmlStyleResolver._compute_style` with the merged
   class list (static + dynamic), extracts the visual-property subset,
   and applies it through the transition manager.

## §1 — Component split

`GmlClassRestyler` is a static `RefCounted` (matches the project's
engine convention). It owns recompute + apply. The renderer wires it
because only the renderer holds node + ancestor_chain + css_rules +
transition_manager together at build time.

Public API:

```gdscript
class_name GmlClassRestyler
extends RefCounted

## Recompute the bound element's visual style for the given dynamic
## class set and apply the visual-property deltas in place.
##
## control          — the built Control to restyle
## node             — the DOM node carrying the :class binding
## ancestor_chain   — node's ancestor chain (for descendant selectors that
##                    target THIS node, e.g. ".parent .me")
## dynamic_classes  — PackedStringArray of currently-active dynamic classes
## css_rules        — the view's retained parsed rules
## base_snapshot    — Dictionary of visual props resolved from static
##                    classes only (captured at build)
## transition_manager — the view's GmlTransitionManager (may be null)
static func restyle(control: Control, node, ancestor_chain: Array, dynamic_classes: PackedStringArray, css_rules: Array, base_snapshot: Dictionary, transition_manager) -> void


## Resolve the visual-property subset for a node with an explicit class
## list. Used at build time to capture the base snapshot and at runtime
## to compute the target. Returns a Dictionary of allowlisted keys only.
static func resolve_visual_props(node, ancestor_chain: Array, class_list: PackedStringArray, css_rules: Array) -> Dictionary
```

## §2 — Visual property allowlist + structural boundary

The restyler holds an explicit allowlist of re-resolvable keys:

```
color              → add_theme_color_override("font_color", …)
background-color   → mutate the control's StyleBoxFlat.bg_color
border-color       → stylebox border color (all sides)
border-width       → stylebox border_width_* fields
border-radius      → stylebox corner_radius_* fields
outline-color      → stylebox
outline-width      → stylebox
opacity            → control.modulate.a
font-size          → add_theme_font_size_override("font_size", …)
```

Any key in the recomputed style that is NOT in the allowlist AND differs
from the base snapshot's value for that key triggers a one-time
`GmlBindingApplier._warn`:

> "dynamic :class changed layout prop '<key>' — ignored; v0.8.2
> re-resolves visual props only (color/bg/border/opacity/font-size)."

The base snapshot stores resolved values for exactly the allowlist keys,
so revert restores them precisely.

## §3 — Application through the transition manager

The renderer's `GmlTransitionSetup` already caches each control's base
stylebox props (`_stylebox_props` meta) and the transition manager
animates between the base bucket and pseudo (hover/focus) buckets. The
restyler integrates with that, not around it.

On a class change:

1. **Compute target** via `resolve_visual_props(node, chain, merged, rules)`.
   - If the merged set yields no dynamic overrides (e.g. all dynamic
     classes removed), the target IS `base_snapshot`.
2. **Update the cached base bucket**: overwrite the control's
   `_stylebox_props` base values with the new target so that when a
   hover/focus ends, the control reverts to the *new* dynamic base — not
   the stale static one.
3. **Apply now**:
   - If the element has a `transition` declared covering a changed
     property → `transition_manager.transition_style(control, current,
     target, transitions)` (animate).
   - Else mutate the stylebox fields + theme overrides directly (snap).
4. **Font color / opacity / font-size**: theme overrides / `modulate`
   applied directly; the transition manager already tweens `color` for
   declared transitions — reuse that path for animated color.

**Hover + dynamic-class collision** (documented edge case): if the
pointer is hovering AND a dynamic class changes the same property, the
hover target wins visually until hover ends, then the new dynamic base
shows. v0.8.2 does NOT recompute the hover bucket against the new class
set — that's a deeper cascade interaction, deferred.

**No transition declared** → snap, matching first-paint behavior.

**Null transition_manager** (headless/edge): snap directly, skip the
animated path.

## §4 — Context capture + GmlView retention

`_compute_style(node, ancestor_chain, rules, scope)` needs the ancestor
chain, built during the renderer's descent. The `:class` binding fires
later, so the chain is captured at registration time in the closure.

Changes:

- **GmlView**: retain `_css_rules: Array` (currently a local in
  `_rebuild`). Repopulate each `_rebuild`; clear when no CSS. Expose it
  to the renderer.
- **GmlRenderer**: thread an `ancestor_chain: Array = []` parameter
  through `_build_node` and `_register_bindings_for_node`. Each level
  appends the current node before descending. When registering a
  `:class` binding:
  - capture `ancestor_chain` and `_transition_manager`,
  - compute `base_snapshot = resolve_visual_props(node, chain,
    static_classes, css_rules)` (static classes only — from
    `node.get_classes()`, excluding dynamic),
  - pass an `on_change` callback to `register_class_binding` that calls
    `GmlClassRestyler.restyle(...)`.
- **v-for clones**: the reconciler's insert path builds clones via
  `_build_node`; thread the clone's ancestor chain (host container's
  node prepended to parent chain) so dynamic `:class` on a clone resolves
  selectors that target the clone.

## §5 — register_class_binding extension

`GmlBindingApplier.register_class_binding` gains an optional trailing
`on_change: Callable = Callable()` parameter. After it writes the
`dynamic_classes` meta in its apply closure, it invokes
`on_change.call(classes)` when valid. Existing call sites (none pass it)
are unaffected — back-compat preserved.

The tag parameter from v0.8.1 stays; the new parameter goes after it:

```gdscript
static func register_class_binding(control, expr, registry, state, scope = {}, tag = "", on_change: Callable = Callable()) -> void
```

## §6 — Known limitations (documented)

1. **Descendant re-resolution from an ancestor's dynamic class.**
   `.card.selected .name { color: X }` does NOT restyle the child
   `.name` when `selected` toggles on the card. Only the element with the
   `:class` binding restyles. Workaround: put the `:class` (and the
   selector) on the element you want to restyle, or precompute a state
   key the child binds to. A test pins this as intentional behavior.
2. **Layout props in dynamic classes** are ignored + warned.
3. **Hover collision**: hover wins while active; new base shows after.
4. **Font-family** not re-resolved (only font-size).

## §7 — Testing plan

Target: 367 → **~385** (18 new).

### Restyler unit tests (~10) — `test_class_restyler.gd`

- Added class pulls in its `background-color` (stylebox bg_color changes).
- Added class changes `color` (font color override).
- border-color / border-width / border-radius re-applied.
- opacity re-applied to `modulate.a`.
- Removing all dynamic classes reverts to base snapshot exactly.
- Toggle on→off→on lands back on the class style (no drift).
- Layout prop (`display`) in dynamic class ignored + warns (capture via `_on_warning`).
- Unmatched dynamic class → no change, no crash.
- Compound selector `.item.rare` applies only when both classes present.
- Snap path (no transition declared) applies immediately.

### Integration tests (~6) — `test_binding_integration.gd`

- `:class="{ rare: is_rare }"` + `.rare { color: … }` → toggle true/false, font color changes + reverts.
- `:class="{ active: filter == 'all' }"` + `.active { background-color: … }` → bg updates live.
- Low-hp `:class="{ low: hp < 25 }"` + `.low { color: red }` → crossing threshold turns red.
- Array syntax `:class="['badge', rarity]"` where `rarity` is a state string → swapping rarity value restyles.
- v-for clone with dynamic `:class` restyles correctly (validates clone chain threading).
- Descendant-from-ancestor limitation: `.card.selected .name` does NOT update child when `selected` toggles — assert child unchanged (pins §6.1).

### Documented / manual
- Hover + dynamic-class collision.

## §8 — Phasing

Single bundled PR. Tasks:

1. GmlView retains `_css_rules` + 1 test.
2. `GmlClassRestyler.resolve_visual_props` + allowlist + base snapshot + ~5 tests.
3. `GmlClassRestyler.restyle` apply path (stylebox mutation + theme overrides + transition routing) + ~5 tests.
4. Renderer: thread ancestor_chain, register on_change callback, capture base snapshot; `register_class_binding` extension.
5. Integration tests (6).
6. Docs (`bindings.md` — remove the "v0.7 does not re-resolve" caveat, document the visual-only behavior + limitations) + CHANGELOG 0.8.2 + version bump.
7. Push + PR.

## §9 — Out of scope (deferred)

- Descendant cascade from dynamic ancestor classes (would re-resolve a
  subtree per toggle).
- Layout re-resolution (needs re-entrant `GmlWrap`).
- Hover-bucket recompute against dynamic classes.
- `font-family` swaps.
- The fourth v0.8 blocker (focus traversal + perf bench) is a separate PR.
