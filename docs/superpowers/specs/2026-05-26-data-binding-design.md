# GTML v0.7 — Data binding + interpolation + list rendering

**Date:** 2026-05-26
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.7.0

## Summary

GTML today is excellent for static menus, settings panels, dialogs, and
cutscenes. Dynamic content (HUDs, inventories, leaderboards) currently
requires per-element GDScript glue: `view.get_element_by_id("score").text
= str(score)`. This is workable for one or two values but unfeasible for
a real inventory grid or chat list.

v0.7 adds a Vue-style reactive binding layer so authors declare the data
flow in HTML and game code only updates state:

```html
<h1>Welcome, {{ player.name }}!</h1>
<ul>
  <li v-for="item in inventory" @click="select(item)">
    <img :src="item.icon">
    <span :class="['name', item.rarity]">{{ item.name }}</span>
    <span class="qty" v-show="item.qty > 1">{{ item.qty }}</span>
  </li>
</ul>
<button :disabled="!selected_item">Use</button>
```

```gdscript
view.state.set("player.name", "Ada")
view.state.set("inventory", [...])
view.state.set("selected_item", null)
view.item_clicked.connect(func(handler, args):
    if handler == "select":
        view.state.set("selected_item", args[0])
)
```

## Goals

- Make dynamic UIs (HUDs, inventories, leaderboards, dialog trees)
  feasible without per-element binding code.
- Adopt Vue-style directives so devs leverage existing knowledge.
- Keep the engine layer modular + unit-testable (same pattern as
  CSS / editor engines).
- Single sample (`showcase/inventory/`) demonstrates every directive
  end-to-end + shows the real game-integration pattern (the first sample
  with a GDScript demo script).

## Non-goals

- Computed properties / arithmetic in expressions (no `score + 1`,
  no `size === 'lg'`). Authors compute in GDScript and `set(...)`.
- Diff-based `v-for` reconciliation (rebuild on collection change).
- Cross-view shared state / global store. Each `GmlView` has its own
  `GmlState`.
- Watchers / lifecycle hooks (Vue's `mounted`, `watch`). Use Godot's
  signal system.
- Async / Promise bindings.

## Architecture

Five new modules under a new subdirectory
`addons/gtml/src/binding/`:

```
addons/gtml/src/binding/
  GmlState.gd               # per-view reactive key→value store
  GmlBindingParser.gd       # find text-interp + classify attribute directives
  GmlBindingExpr.gd         # mini-expression parser
  GmlBindingApplier.gd      # eval expressions + write to controls
  GmlBindingRegistry.gd     # per-view: {key → [bindings]} reverse index
```

`GmlView` gains:

- `var state: GmlState` (exposed property) — created in `_init`, survives
  `_rebuild`
- `signal state_changed(key: String, new_value, old_value)` — re-emitted
  from `state` for convenience
- `signal item_clicked(handler: String, args: Array)` — fires when a
  `@event="handler(arg1, arg2, ...)"` triggers. `args` holds the resolved
  argument values from the current scope (`[item]`, `[item, index]`,
  whatever was specified). Empty array when handler has no args.
- Internal `_binding_registry: GmlBindingRegistry` rebuilt on every
  `_rebuild` walk

`GmlRenderer._build_node` gains three hooks:

1. Before dispatch: check `v-if` — return null if falsy
2. Before dispatch: check `v-for` — take over, clone-and-build per array
   element, register list binding, skip normal path
3. After dispatch: `GmlBindingApplier.register_directives(control, node,
   ctx)` scans attrs + text children, parses, registers, applies initial

`GmlHtmlParser._parse_attribute_name` extended so `:`, `v-`, and `@`
work as first characters of attribute names. The `:` char is already
allowed mid-name (for SVG); adding it as a first-char is one-line.

Engines are static-method-only `RefCounted`s where possible. `GmlState`
and `GmlBindingRegistry` carry state per-view. Same pattern as
`GmlEditorContext` / `GmlAutocompleteSource` etc.

## §1 — State model + public API

`GmlState` stores values in a flat `Dictionary` keyed by dotted paths:

```gdscript
# Internal storage
_values: Dictionary = {
    "score": 42,
    "player.health": 85,
    "player.name": "Ada",
    "inventory": [{...}, {...}],
}
```

Flat storage with dotted keys (not nested dicts) so subscription lookup
is O(1) on the exact key. When the user calls
`state.set("player.health", 90)`, we fire exactly the bindings
registered to that key.

For expressions like `{{ player.health }}`, lookup is direct on the full
path. For loop variables (`{{ item.name }}` inside a `v-for`), the loop
pushes a scope frame; lookup walks scope frames before falling back to
the top-level state.

### Public API on `GmlState`

```gdscript
class_name GmlState
extends RefCounted

signal state_changed(key: String, new_value: Variant, old_value: Variant)

func set(key: String, value: Variant) -> void
func get(key: String) -> Variant                   # returns null if missing
func has(key: String) -> bool
func set_state(values: Dictionary) -> void         # batched; state_changed fires per changed key, bindings fire deduplicated
func keys() -> PackedStringArray
```

### Public API on `GmlView`

```gdscript
var state: GmlState                                # exposed; created in _init
signal item_clicked(handler: String, args: Array)

func refresh_bindings() -> void                    # force re-evaluate all
```

State is exposed AS-IS (`view.state.set("score", 42)`) rather than
wrapped on `GmlView` to avoid colliding with `Object.set()` which
addresses Godot properties. This matches Vue's `vm.$data.x = …` mental
model.

### Lifecycle

- `state` constructed in `_init()` — available before `_ready()`
- `state` survives `_rebuild()` — editor hot-reload doesn't lose values
- `_binding_registry` is rebuilt on each `_rebuild()`
- Bindings hold WeakRef to controls; pruned on next fire when invalid

## §2 — Directive table

Recognized at element-build time:

| Source | Markup | Effect |
|---|---|---|
| Text node | `{{ key }}` / `{{ path.to.key }}` | Replace at render; refresh on key change |
| Attribute | `:disabled="key"` | `Control.disabled = bool(state.get(key))` |
| Attribute | `:value="key"` | `LineEdit.text = str(state.get(key))` |
| Attribute | `:src="key"` | `<img>` reloads texture |
| Attribute | `:href="key"` | `<a>` href |
| Attribute | `:class="key"` | appends `state.get(key)` (str) to resolved class list |
| Attribute | `:class="{ name: cond_key }"` | object syntax — toggle class names |
| Attribute | `:class="['static', dyn_key]"` | array syntax — concat literals + dynamic |
| Attribute | `v-if="key"` / `v-if="!key"` | element omitted when falsy |
| Attribute | `v-show="key"` | element built, `visible = bool(...)` |
| Attribute | `v-for="item in items"` | clone template per array element |
| Attribute | `v-for="item, idx in items"` | indexed variant |
| Attribute | `v-model="key"` | input ↔ state two-way |
| Attribute | `@click="handler"` (existing) | unchanged |
| Attribute | `@click="handler(item, index)"` | NEW: args resolved via current scope |

### Expression mini-language

Only `:class={…}`, `:class=[…]`, and `@event(args)` need real parsing.
Everything else accepts a key path (with optional `!negation`).

Grammar:

```
Expr     := Path | NegPath | ObjectLit | ArrayLit | CallExpr | StringLit
Path     := Ident ('.' Ident)*
NegPath  := '!' Path
ObjectLit:= '{' (Ident ':' Expr (',' Ident ':' Expr)*)? '}'
ArrayLit := '[' (Expr (',' Expr)*)? ']'
CallExpr := Ident '(' (Expr (',' Expr)*)? ')'
StringLit:= "'…'" | '"…"'
Ident    := [a-zA-Z_][\w-]*
```

No arithmetic, comparison, string concat, ternary, or member calls.
Bounded grammar = unambiguous parser, ~150 LOC.

Authors needing computed values do the work in GDScript:

```gdscript
view.state.set("is_low_hp", player.hp < player.max_hp * 0.25)
```

```html
<div :class="{ low: is_low_hp }">
```

Parser returns a tagged Variant:

```gdscript
{type: "path",   parts: ["player", "health"]}
{type: "neg",    inner: {...}}
{type: "object", entries: [{key: "active", value: {...}}, ...]}
{type: "array",  items: [...]}
{type: "call",   name: "handler", args: [...]}
{type: "string", value: "..."}
```

`GmlBindingApplier.eval(expr, state, scope)` resolves the tree, threading
through current `scope` (loop vars `item`, `index`).

## §3 — Render integration + reactivity

### Renderer hooks

`GmlRenderer._build_node` gains three hooks:

1. **`v-if` check**: before dispatch. If present and falsy, return null;
   skip subtree.
2. **`v-for` check**: before dispatch. If present, the renderer takes
   over: clone the node (sans `v-for` attribute), push `{item, index}`
   scope frame, recursively build each clone, register a `v-for`
   binding that knows how to rebuild on collection change. Skip normal
   single-build path.
3. **Post-dispatch**: `GmlBindingApplier.register_directives(control,
   node, ctx)` scans attrs + text children, parses each binding once,
   registers in `ctx.binding_registry`, and applies initial value.

Existing code paths (`_apply_node_styles`, `GmlDimensions.apply`,
transitions) are untouched. Bindings layer on top.

### Reactivity flow

```
view.state.set("score", 42)
  → GmlState records change, captures old
  → emits state_changed("score", 42, prev)
  → GmlBindingRegistry.fire("score")
       → iterates bindings registered to "score"
       → for each valid control: GmlBindingApplier.apply(binding)
       → invalid bindings pruned in the same pass
```

For `set_state({...})`: collect all key changes, build a deduped Set of
affected bindings, fire each once. Prevents an interpolation like
`{{ a }} - {{ b }}` from re-rendering twice in a single batch update.

### Dependency tracking

Each registered binding declares its dependency keys at register time:

```gdscript
{control: label, kind: "text_interp", deps: ["player.health"], template: [...]}
{control: btn,   kind: "class_bind",  deps: ["is_active"], expr: {...}}
{control: ul,    kind: "v_for",       deps: ["inventory"], template_node: ..., as_name: "item"}
```

Registry maintains `Dictionary[key → Array[binding]]`. `fire(key)` is
O(M) where M is bindings reading that key. No reflection, no proxies.

### v-for re-render

On `state.set("inventory", new_array)`:

- Diff-based reconciliation is **out of scope for v0.7**
- Implementation: tear down all child controls of the v-for parent,
  re-build from `new_array`, re-register their bindings
- 50-item inventory rebuilds 50 controls on change — fine for game UIs
- `:key="item.id"` for keyed reconciliation is a v0.8 add if/when
  someone hits perf issues

### v-model two-way

For `<input v-model="email">`:

- At register: write `state.get("email")` into `LineEdit.text`
- Connect `LineEdit.text_changed.connect(func(t): state.set("email", t))`
- Mark binding as two-way: on `state.set("email", x)`, the apply function
  compares `input.text != x` before writing → prevents infinite reentry

Supported elements in v0.7:

- `LineEdit` / `TextEdit` → `String`
- `CheckBox` (no group) → `bool`
- `CheckBox` in group (radio) → string (the input's `value` attribute,
  when pressed)
- `HSlider` → `float`
- `OptionButton` (select) → string (selected item text)

### Lifecycle / cleanup

- `_rebuild()`: clear registry before walking; rebuild populates fresh.
  State persists.
- Node freed: bindings hold WeakRef, pruned on next fire.
- `v-if=false`: bindings never register, no work.
- `v-if` flip back to true: re-runs element builder + registers
  bindings fresh.

## §4 — Sample (Inventory)

5th showcase scene at `addons/gtml/examples/showcase/inventory/`.
Pause-menu inventory overlay: filterable item grid + selected-item
detail panel + hotbar.

Aesthetic: **parchment** — first warm/light sample to balance the
mostly-dark showcase set.

### Bindings exercised

| Directive | Site in sample |
|---|---|
| `{{ }}` | Title, item counts, gold total, selected item name/desc |
| `:class` object | Active filter button (uses precomputed bool) |
| `:class` array | Rarity badge: `:class="['badge', selected_rarity]"` |
| `:disabled` | "Use" button when no item selected |
| `:src` | Selected item icon |
| `v-for` | Item grid + hotbar slots |
| `v-for` indexed | `v-for="slot, i in slots"` for slot numbers |
| `v-if` | Empty-state message when filter returns nothing |
| `v-show` | Detail panel hidden until selection |
| `v-model` | Search input filtering the grid |
| `@click(item)` | Click an item card → `select(item)` |

### Files

```
addons/gtml/examples/showcase/inventory/
  index.html       # ~80 lines
  style.css        # ~150 lines (parchment palette)
  demo.gd          # ~60 lines (game-side integration script)
  demo.tscn        # GmlView + script attached
```

`demo.gd` is the FIRST sample with a real GDScript companion — Atlas /
Atelier / Forge / Kitchen are pure HTML+CSS. This is intentional: the
inventory sample is the "this is how you actually use it in a game"
reference.

### Demo script outline

```gdscript
extends Control

@onready var view: GmlView = $GmlView

const ITEMS := [
    {"id": "sword", "name": "Iron Sword", "rarity": "common", "icon": "...", "desc": "..."},
    # … 12 items
]

func _ready():
    view.state.set("items", ITEMS)
    view.state.set("gold", 1247)
    view.state.set("search", "")
    view.state.set("selected_item", null)
    view.state.set("is_filter_all", true)
    view.state.state_changed.connect(_on_state_changed)
    view.item_clicked.connect(_on_item_clicked)

func _on_state_changed(key: String, new_value, _old):
    if key == "search":
        view.state.set("filtered_items", _filter(new_value))

func _on_item_clicked(handler: String, args: Array):
    if handler == "select":
        view.state.set("selected_item", args[0])
```

## §5 — Testing

### File budget

| File | LOC | Test file | Tests |
|---|---|---|---|
| `GmlState.gd` | ~80 | `test_state.gd` | ~8 |
| `GmlBindingExpr.gd` | ~200 | `test_binding_expr.gd` | ~14 |
| `GmlBindingParser.gd` | ~100 | `test_binding_parser.gd` | ~8 |
| `GmlBindingApplier.gd` | ~250 | `test_binding_applier.gd` | ~12 |
| `GmlBindingRegistry.gd` | ~80 | `test_binding_registry.gd` | ~6 |
| `GmlRenderer.gd` Δ | ~50 | (integration) | — |
| `GmlView.gd` Δ | ~40 | (integration) | — |
| `GmlHtmlParser.gd` Δ | ~10 | parser tests | 2 |
| `test_binding_integration.gd` | (test) | end-to-end | ~10 |

Total engine: ~810 LOC. Tests: ~60 (223 baseline → ~283).

### Test patterns

- Engine tests use the existing GUT scaffold — `extends GutTest`, no
  panel instantiation.
- Integration tests instantiate `GmlView` against fixture files written
  to `tests/snapshots/.actual/binding_fixture/`, mirroring the showcase
  smoke pattern.
- Each directive gets at least one integration test demonstrating the
  end-to-end flow from `state.set(...)` to control mutation.

### Out of scope for tests

- Performance characteristics (manual profiling instead)
- Rendered pixels (snapshot tests already cover DOM/style)
- `v-model` cursor-position preservation (manual editor test)

## File layout summary

```
addons/gtml/src/binding/
  GmlState.gd
  GmlBindingParser.gd
  GmlBindingExpr.gd
  GmlBindingApplier.gd
  GmlBindingRegistry.gd
addons/gtml/src/GmlView.gd                              # MODIFY
addons/gtml/src/html_renderer/GmlRenderer.gd            # MODIFY
addons/gtml/src/html_parser/GmlHtmlParser.gd            # MODIFY
addons/gtml/examples/showcase/inventory/
  index.html
  style.css
  demo.gd
  demo.tscn
tests/unit/
  test_state.gd
  test_binding_expr.gd
  test_binding_parser.gd
  test_binding_applier.gd
  test_binding_registry.gd
  test_binding_integration.gd
docs/
  bindings.md                                            # NEW user-facing doc
  getting-started.md                                     # MODIFY: link bindings.md
```

## Phasing (single bundled v0.7 PR)

1. **Scaffold** — empty modules + `GmlState` real impl + 8 state tests
2. **Expression parser** — `GmlBindingExpr` + 14 expr tests
3. **Binding parser + registry** — scanning HTML + storing bindings + 14 tests
4. **Applier (text interp + simple attrs)** — `{{ }}`, `:disabled`, `:src`, etc + 6 tests
5. **Applier (class binding object + array syntax)** — :class={...} + :class=[...] + 3 tests
6. **v-if + v-show** — renderer hooks + 2 integration tests
7. **v-for** — renderer hook + scope frames + collection-rebuild + 3 tests
8. **v-model + item_clicked signal** — two-way + per-item event context + 4 tests
9. **HTML parser update** — allow `:` and `v-` first-char + 2 tests
10. **Inventory sample** — index.html, style.css, demo.gd, demo.tscn + 1 smoke test
11. **Docs** — `docs/bindings.md` + getting-started link
12. **Bump 0.7.0** + CHANGELOG

Pre-PR code review per the v0.5/v0.6 pattern.

## Known unknowns

- **Performance of full v-for rebuild** on >100 items — never measured.
  v0.7 ships without diff reconciliation; if it bites in real use, v0.8
  adds `:key` support.
- **`@event(item)` argument resolution scope** — needs care so `item`
  resolves to the current loop's frame and not a shadowed global state
  key. Spec says "scope frame walked before global"; tests will pin.
- **`v-model` on multi-select** (Godot OptionButton allows it) — defer
  to v0.8 if needed; v0.7 single-select only.

## Out of scope (deferred)

- Computed properties / arithmetic / comparison in expressions
- `v-bind:[dynamic-attr]="..."` (dynamic attr name binding)
- `v-once` / `v-pre` / `v-html`
- Lifecycle hooks (`v-mounted`, `v-unmounted`)
- Watchers / `$watch`
- Shared state across views / global store
- `:key` diff reconciliation for v-for
- Slot/template composition
- Custom directives API
