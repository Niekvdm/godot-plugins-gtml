# Changelog

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
