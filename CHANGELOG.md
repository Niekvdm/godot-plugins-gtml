# Changelog

## 0.8.1

### Features — v-for keyed reconciliation

v0.7/v0.8 tore down every v-for child on any array change and rebuilt
the whole region from scratch. That broke focus, scroll, hover state,
and any in-flight animation on a 100-item HUD or chat list.

v0.8.1 replaces the rebuild with a Vue-3-style LIS-based keyed
reconciler that preserves Control identity across array mutations.
Authors opt into stable identity per item via `:key`:

```html
<li v-for="item in items" :key="item.id">
  <input :value="item.name">
</li>
```

After `state.set("items", items_reordered)`, the `<input>` that had
focus still has focus. Only DOM positions move.

Without `:key`, the array index is the default — useful for
stable-order lists, suboptimal for reorderable ones.

### Architecture

- New `GmlVForReconciler` (pure-data LIS diff, no scene access). 15
  unit tests cover all edge cases.
- `GmlBindingRegistry` gains `register(binding, tag)` + `prune_tag(tag)`
  so per-clone bindings can be freed as a group when their clone leaves
  the rendered set.
- `GmlRenderer` replaces its tear-down-rebuild closure with a
  reconcile-in-place flow. Per-host state lives on the parent control's
  meta, keyed by the v-for template node's instance id.

### Backward-incompatible

None. Existing v-for samples (the inventory showcase, all integration
fixtures) work unchanged — default-index reconciliation is
behaviour-compatible with the old tear-down path from the author's POV.

### Tests

25 new tests across reconciler, registry, and integration; 341 → 366.

### Deferred to v0.8.2+

- Item-mutation propagation without key change (currently: keep keys
  stable AND update with new dict instances if you want field updates).
- Cross-list reuse (item moves from one v-for to another).
- Staggered enter/leave animations.

### Next blockers

Two more v0.8 production-readiness PRs remain:
- Dynamic `:class` CSS re-resolution
- Focus traversal + perf bench infrastructure

## 0.8.0

### Features — Expression operators

v0.7 banned every operator inside binding expressions, forcing
authors to precompute booleans in GDScript and re-`set` them as
state. v0.8 lifts that tax with a full Vue-compatible operator set
in the expression mini-language:

- **Arithmetic**: `+ - * / %` (strict types; cross-type returns null + warns)
- **Comparison**: `> < >= <=` (num+num or str+str only)
- **Equality**: `== !=` (cross-type permitted — `x == null` etc.)
- **Logical**: `&& ||` (short-circuit, returns LAST operand not coerced bool)
- **Unary**: `! -`
- **Ternary**: `cond ? then : else`
- **Indexing**: `items[i]`, `dict['k']`, `items[i].name`

Type mismatches return null and emit warnings through a new
injectable `_on_warning` logger (testable from GUT).

### Backward-incompatible

- **Identifier syntax**: hyphens dropped from identifiers in
  binding expressions. State keys themselves still accept any
  string via `state.set("key-with-hyphen", ...)`; only the parser
  rejects them. All in-repo samples already use snake_case.

### Tests

54 new tests across parser, applier, and integration; 286 → 340.

### Inventory sample

Filter buttons now read `:class="{ active: filter == 'all' }"`
directly instead of three precomputed booleans. Demonstrates the
operator payoff.

### Deferred to v0.8.1+

- v-for :key keyed reconciliation
- Dynamic :class CSS re-resolution
- Focus traversal + perf benchmarks

## 0.7.0

### Features — Reactive bindings

GTML graduates from "menu builder" to "real UI framework" with Vue-style
reactive bindings. Dynamic content (HUDs, inventories, leaderboards,
dialog trees) is now feasible without per-element GDScript glue.

- **`GmlView.state`** — a `GmlState` instance per view. `state.set(key,
  value)` writes; `state.get(key)` reads; `state.set_state({...})`
  batches. `state_changed(key, new, old)` signal fires per changed key.
- **`{{ expr }}` text interpolation** — substitutes at render and on
  every change to a referenced state key.
- **`:attr="expr"` one-way attribute binding** — supported targets:
  `disabled`, `value`, `src`, `href`. (Shorthand for `v-bind:attr`.)
- **`:class="..."` class binding** — bare key, object syntax
  `{ name: cond_key }`, and array syntax `['static', dyn_key]`.
  Limitation: stores classes on `dynamic_classes` meta but does NOT
  re-resolve CSS; declare possible classes at build time.
- **`v-if="expr"` / `v-show="expr"`** — conditional rendering /
  visibility.
- **`v-for="item in items"` list rendering** — also `v-for="item, i in
  items"` for indexed form. Rebuilds on collection change (no keyed
  reconciliation in v0.7).
- **`v-model="key"` two-way input binding** — `LineEdit`, `TextEdit`,
  `CheckBox`, `HSlider`, `OptionButton`. Equality-guarded so state ↔
  control updates don't feedback-loop.
- **`@event="handler(args)"` events with arguments** — fires new
  `view.item_clicked(handler: String, args: Array)` signal. Args
  re-evaluated at click time. Bare `@event="handler"` keeps firing
  `button_clicked`.

### Architecture

Five new pure-data engines under `addons/gtml/src/binding/`:

- `GmlState.gd` — reactive key→value store via `_set`/`_get` virtuals,
  no-op skip on equal writes
- `GmlBindingExpr.gd` — mini-expression parser (paths, `!`, object/array
  literals, call exprs, string literals; no arithmetic / comparison)
- `GmlBindingParser.gd` — scans HTML for `{{ }}` + classifies attrs
- `GmlBindingRegistry.gd` — per-view `{key → [bindings]}` reverse index,
  prunes freed-control bindings
- `GmlBindingApplier.gd` — evaluates AST + writes to controls

`GmlRenderer._build_node` gained three hooks: v-for (highest priority,
takes over and clones), v-if (short-circuit return null), and post-build
binding registration. `GmlHtmlParser` now accepts `:` as a first
character of attribute names so `<div :class="x">` parses.

### Showcase

New 5th sample: `addons/gtml/examples/showcase/inventory/` — pause-menu
inventory overlay with filterable item grid, detail panel, search, and
hotbar. **First sample with a real `demo.gd` companion script** —
demonstrates the actual game-integration pattern (`state.set_state` for
initial state, `state_changed` for derived state, `item_clicked` for
per-element actions).

### Tests

63 new tests covering state, expression parser, binding parser,
registry, applier, and end-to-end integration through `GmlView`. Test
count: 223 → 286.

### Deferred / not yet supported

- Arithmetic / comparison / ternary in expressions (compute in GDScript)
- Keyed reconciliation (`:key`) for `v-for`
- Cross-view shared state / global store
- Watchers / lifecycle hooks beyond `state_changed`
- Computed properties / refs
- Dynamic CSS re-resolution when `:class` changes
- `v-bind:[dynamic-attr]` (dynamic attr name binding)

## 0.6.0

### Features — Editor pane "professional upgrade"

- **Autocomplete** (HTML + CSS): element tags, tag-specific attributes,
  enumerated attribute values, CSS property names, value keywords per
  property, `var(--name)` declarations scanned from the buffer, and
  class names scanned from the paired buffer. Triggered by typing
  `<`, ` `, `"`, `:`, `.`, `#`, `(` or by Ctrl+Space.
- **Find & Replace** (Ctrl+H toggles the Replace row). Regex toggle
  (`.*`) and the existing match-case toggle apply to both find and
  replace. Replace All reports the count via the match label.
- **Jumps**: Ctrl+Click or F12 jumps between
  - `class="x"` ↔ `.x` rule
  - `id="x"` ↔ `#x` rule
  - `var(--name)` ↔ `--name: ...;` declaration
  Alt+Left returns to the previous position via a panel-local history
  stack.
- **Color picker on hex / rgb / rgba literals**: a 16px gutter renders
  a swatch next to every line containing a color. Click → ColorPicker
  popup; changes round-trip back to the buffer in the literal's
  original kind (hex stays hex, rgba stays rgba).
- **Multi-cursor + selection** (CodeEdit's native multi-caret enabled):
  - Ctrl+D adds caret at next match
  - Ctrl+L selects current line
  - Ctrl+Alt+Up/Down adds caret one line above/below

### Architecture

Five new pure-data engines under `addons/gtml/src/editor/` so the panel
script stays a thin wiring layer and the intelligence is unit-testable
without instantiating Godot UI:

- `GmlEditorContext.gd` — shared {text, cursor, other_text, kind} struct
- `GmlAutocompleteSource.gd` — candidate generator
- `GmlJumpResolver.gd` — cursor-context → jump target
- `GmlSearchEngine.gd` — find / replace_all ops with regex flag
- `GmlColorTokens.gd` — color-literal scanner + formatter

50+ new tests covering all five engines plus integration tests against
the loaded panel scene.

### Deferred / not yet supported

- Live rendered preview pane (use existing GmlView scene + hot reload).
- Cross-buffer find (only the active tab).
- Code formatting / prettify.
- Snippet library beyond the implicit tag→`<tag></tag>` completion.
- LSP / external protocol support.
- Multi-tab file open (only the active GmlView's pair).


## 0.5.0

### Features

- **`transform` is now animated through the transition manager**. Including
  `transform` in a `transition:` declaration interpolates scale, rotation,
  and the layout-relative position offset together through a single tween.
  Absent target transforms revert to the identity, so `:hover` → no-hover
  animates back to neutral without an explicit reverse rule.
- **Kitchen-sink showcase sample** at `addons/gtml/examples/showcase/kitchen/`
  exercises virtually every supported element + CSS property in one scene.
  Useful as both a feature reference card and a regression smoke test.
- **CSS property names accept digits** (`--surface-2`, `--gap-1`). The
  parser previously truncated at the first digit, which broke
  numerically-suffixed token names.

### Polish

- All three v0.3.1 showcase scenes refactored:
  - Palettes extracted to top-level `--*` custom properties
  - `transform: scale(...)` on hover for KPI cards (atlas) + primary
    buttons (atlas/forge) + a 2px translate on Atelier's related-article
    links
  - `:checked` styling on Forge's checkbox + radio rows fills with the
    accent color when toggled on

### Docs

- New pages: `docs/css-tokens.md`, `docs/transforms.md`
- Updated: `docs/css-selectors.md` (combinators, attribute matchers,
  structural pseudos, multi-pseudo), `docs/forms-and-inputs.md`
  (form value collection, `@keydown`, `<label for>`, `:checked` / `:focus`
  styleboxes), `docs/transitions.md` (transform interpolation +
  transparent→opaque flash workaround), `docs/getting-started.md`,
  `docs/limitations.md` (rewrites the now-resolved sections)


## 0.4.0

### Features

- **CSS custom properties + `var()` + `calc()`** (`GmlCssEval`):
  - `--name: value` declarations on any selector cascade through descendants
  - `var(--name)` and `var(--name, fallback)` substitute at compute-style
    time against the inherited scope; recursive resolution of nested vars
  - `calc(...)` evaluates flat arithmetic with `+ - * /` and standard
    precedence. Unit rules: `+`/`-` need matching units, `*`/`/` accept at
    most one unit-bearing operand. Mixed expressions emit a warning and
    leave the substring intact.
- **`:checked` pseudo-class** for CheckBox + radio inputs. Resolver routes
  to a `_checked` bucket; `GmlInputBuilder` installs the bucket on the
  CheckBox `pressed` theme stylebox slot (Godot treats `pressed` as the
  toggle-on visual). Empty `:checked` rule installs `StyleBoxEmpty` for
  explicit opt-out.
- **CSS transforms** (`GmlTransformValues`):
  - `translate(x[, y])` / `translateX` / `translateY` — px values
  - `scale(s)` / `scale(sx, sy)` / `scaleX` / `scaleY` — unitless
  - `rotate(45deg | 0.5rad | 0.25turn)` — normalized to radians
  - Multiple functions compose left-to-right. Pivot defaults to centre
    (`transform-origin: 50% 50%`).
- **Form value collection on submit**: `GmlView.get_form_data()` returns
  `{id|name -> value}` for every registered input — text, textarea,
  checkbox, slider, select, and the *selected* radio per group keyed by
  the group's name. Submit buttons now unconditionally emit
  `form_submitted(get_form_data())` (previously the signal was unused).
- **`@keydown` attribute** on inputs forwards key-down events to a new
  `key_pressed(handler: String, event: InputEvent)` signal on `GmlView`.
  Lets author scripts implement search-as-you-type, autocomplete, hotkeys.
- **Editor inline parse-warnings overlay**: the GML editor panel grows a
  PanelContainer that lists every HTML + CSS parser warning after save.
  Each row is a click-to-jump button that activates the relevant tab and
  positions the caret at the warning's line + column.
- **FileSystem-signal hot reload**: in the editor, `GmlView` subscribes
  to `EditorInterface.get_resource_filesystem().filesystem_changed` and
  re-checks its files only when the project actually changes. The
  per-frame `_process` mtime poll stays as a safety net for changes made
  outside Godot.

### Improvements

- `GmlHtmlParser.get_warnings()` mirrors the CSS parser's contract; every
  push_warning now carries `{line, col, msg}` for editor tooling.

### Limitations / deferred

- Transforms apply at build time and on resize; they do not yet interpolate
  through the transition manager. `transform` inside a `:hover` rule will
  snap instead of animating.
- `calc()` does not yet handle mixed-unit subtraction (e.g.
  `calc(100% - 20px)`). Same-unit and unitless arithmetic only.
- Custom-property declarations inside a state bucket (`p:hover { --x: red; }`)
  are not yet added to the bucket-local scope. The bucket resolves against
  the base scope only.
- GTML has no `<form>` scoping: a bare `<input type="submit">` anywhere in
  the view still fires `form_submitted` with the entire view's input
  snapshot. Intentional given the embedded-UI use case but worth knowing
  if multiple forms coexist in one GmlView.
- Radio inputs without a `name` attribute have no `ButtonGroup` and are
  silently collected by `get_form_data()` as bools under their `id`
  (CheckBox semantics). Always set `name=` on radios.


## 0.3.1

### Fixes

- **HTML parser termination**: stray closing tags for void elements
  (`</input>`, `</br>`) are now skipped as no-ops inside parent loops
  instead of cascading "expected `</X>` but found `</Y>`" warnings and
  corrupting the DOM. Unmatched closing tags at the top level are
  consumed cleanly. `parse()` has a defensive cursor-advance guard so
  it can never spin on a non-advancing return.
- **`<li>` styling pipeline**: `GmlListBuilder.build_list` used to build
  list items inline and silently bypass the central dispatcher, so
  per-item CSS (background, hover transitions, padding, ...) was lost.
  Items now go through `ctx.build_node` and receive the full styling
  pipeline. Marker info travels via meta so the list still owns marker
  resolution.
- **`<label for>` activation**: clicking a label associated with a
  CheckBox now toggles it; with a radio in a `ButtonGroup` it selects
  (never deselects); with a text input or other Control it focuses.
  Cursor shape on for-labels is set to pointing-hand.

### Samples

- New `addons/gtml/examples/showcase/` directory with three crafted
  scenes — `atlas` (mission-control dashboard), `atelier` (editorial
  reader), `forge` (workspace settings) — each demonstrating a distinct
  aesthetic and exercising a different subset of GTML capabilities.

### Notes

- Anything using `background-color: transparent` that transitions to an
  opaque color will visibly "flash" through alpha-blended intermediate
  frames, because the renderer's color tween interpolates alpha as well
  as RGB. Workaround: use an opaque base color matching the parent
  surface. Documented in the showcase CSS comments. A proper fix would
  require pre-compositing the start color against its background before
  the tween — deferred.


## 0.3.0

### Features

- **Selector engine extensions** (`GmlSelector`):
  - Sibling combinators: `.a + .b` (adjacent), `.a ~ .b` (general)
  - Substring attribute matchers: `[class~="bar"]`, `[href^="https://"]`,
    `[src$=".png"]`, `[href*="example"]`
  - Structural pseudo-classes: `:first-child`, `:last-child`, `:only-child`,
    `:nth-child(n|odd|even|an+b)`, `:not(selector)`
  - Specificity unchanged — structural pseudos count as class-level per spec
- **Multi-pseudo combined states**: a selector like `button:hover:focus`
  now resolves into a sorted combined bucket (`_focus+hover`) and the
  renderer applies it only when ALL listed states are simultaneously active.
  Single-pseudo rules continue to emit the legacy `_hover` / `_focus` /
  `_active` / `_disabled` flat keys so existing consumers keep working.
- **Button transitions honor combined buckets**: `GmlButtonBuilder` now
  delegates to the shared `GmlTransitionSetup.setup_with_signals` engine,
  so `button:hover:focus`, `button:hover:active`, etc. transition
  correctly instead of being silently ignored.
- **letter-spacing and word-spacing render natively** via `FontVariation`
  (`spacing_glyph` and `spacing_space`). No more `label.text` mutation
  and no more "metadata only" placeholder.

### Behavior changes

- Rules whose pseudo list contains any unknown state name (e.g. `:hovr`,
  or a typo within `:hover:hovr`) are dropped with a warning instead of
  being silently routed into a known bucket.
- `GmlTransitionSetup` is rewritten around generic state-bucket discovery.
  Same-size buckets now merge in lexicographic key order, making the
  simultaneous-states case deterministic across runs.

### Limitations / deferred

- `text-indent` has no native Label support in Godot 4 and remains
  metadata-only. A future release may route paragraphs through
  `RichTextLabel` for `[indent]` BBCode support.
- `_active` / `_disabled` state buckets resolve correctly for non-button
  elements but the renderer does not yet emit input signals for them on
  inputs/anchors — only buttons drive `active` (via button_down/up).


## 0.2.0

### Breaking changes

- Element builder modules renamed from `Gml*Elements` to `Gml*Builder`
  (`GmlButtonElements` → `GmlButtonBuilder`, etc.). Update any direct call
  sites; the public `GmlView` API is unchanged.
- `GmlRenderer` is now a thin dispatcher. Style/sizing/wrapping logic moved
  to `GmlDimensions`, `GmlPercentSizing`, `GmlBackgrounds`, `GmlWrap`, and
  `GmlTransitionSetup`. Direct callers of the removed private helpers must
  migrate to the new modules.
- `GmlStyles.apply_text_styles` no longer mutates `label.text` for
  `letter-spacing`, `word-spacing`, or `text-indent`. Values are stored as
  metadata; visual application is deferred to v0.3 (RichTextLabel migration).
- `GmlStyles.apply_word_spacing` removed (was the dead helper behind the
  text-mutation path above).
- `_parse_selector` removed from `GmlCssParser`; selector parsing now lives
  in `GmlSelector` and the parser delegates wholesale.

### Features

- **Real CSS selector engine** (`GmlSelector`):
  - Compound selectors: `div.foo#bar`
  - Descendant combinator: `.parent .child`
  - Child combinator: `.parent > .child`
  - Attribute selectors: `[disabled]` and `[type="text"]`
  - Universal selector: `*`
  - Specificity-based cascade `(ids, classes+attrs+pseudos, tags)` with
    source-order tie-breaking, replacing the previous tag<class<id rule.
- **HTML entity decoding**: named (`&amp;`, `&lt;`, `&nbsp;`, …) and numeric
  (`&#65;`, `&#x2603;`) in both text nodes and attribute values.
- **Quote- and paren-aware CSS values**: semicolons inside strings and
  commas inside `url(...)` no longer truncate the value.
- **CSS parser warnings carry line:col**: `parser.get_warnings()` returns
  `[{line, col, msg}]`.
- **Comma-separated CSS rules deep-clone properties** so nested dicts
  (`border`, `transition`, gradient stops) can never bleed between rules.
- **Font weight resolution prefers a real bold variant** from the user's
  fonts dict (`<Family>-Bold`, `<Family>Bold`, `<Family> Bold`,
  `<Family>-700`) before falling back to outline simulation.
- **Renderer split** into focused modules ≤ 250 LOC each (was 915 LOC).
- **GUT vendored** under `addons/gut/` with 54 unit + snapshot + smoke
  tests covering parser, selector engine, resolver, renderer pipeline,
  and style logic fixes.
- `GmlView._clear_children` now snapshots its child list before mutating.
- Plugin display name unified to "GTML".

### Deferred to v0.3

- Sibling combinators (`+`, `~`).
- Substring attribute matchers (`~=`, `^=`, `$=`, `*=`).
- Structural pseudos (`:not()`, `:nth-child()`, `:first-child`).
- Multi-pseudo states (`a:hover:focus` as combined state).
- Visual rendering of `letter-spacing`, `word-spacing`, `text-indent`
  (needs RichTextLabel migration).


## 0.1.1

Last single-file `GmlRenderer` release. See git history.
