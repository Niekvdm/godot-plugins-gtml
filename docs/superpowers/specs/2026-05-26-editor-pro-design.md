# GTML Editor — v0.6 Professional Upgrade

**Date:** 2026-05-26
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.6.0

## Summary

The GML editor panel today is a toolbar + tabbed CodeEdit (HTML/CSS) with
basic search and the v0.4 parse-warnings overlay. This spec adds five
power-tools that match the VSCode/Sublime expectation: autocomplete,
find & replace, jumps (class↔rule, var↔decl, id↔rule), color picker on
hex/rgb literals, and multi-cursor selection.

Scope explicitly excludes a side-by-side live preview — the user prefers
to rely on the existing scene tab + v0.4 hot reload rather than carve
panel real-estate.

## Goals

- Eliminate context-switches to look up CSS property names, value
  keywords, declared classes, and custom-property names.
- Make find & replace a one-pass operation instead of manual scrolling.
- Enable IDE-style navigation across the HTML↔CSS pair (class jumps,
  `var()` jumps).
- Surface colors as visual swatches in the gutter with a click-to-edit
  picker.
- Enable CodeEdit's existing multi-caret capability with the standard
  VSCode keybinds.

## Non-goals

- Live rendered preview pane (use existing GmlView scene + hot reload).
- Cross-file find (only the active buffer).
- LSP / network-protocol compatibility (everything is in-process).
- Code formatting / prettify (defer).
- Custom completion popup UI (use CodeEdit's native popup).
- Multi-tab open-arbitrary-file (only the current GmlView's pair).

## Architecture

Five new pure-data engines under `addons/gtml/src/editor/` (new subdir,
keeps editor-only code separate from runtime renderer):

```
addons/gtml/src/editor/
  GmlAutocompleteSource.gd    # candidate generator
  GmlJumpResolver.gd          # cursor-context → target {file, line, col}
  GmlSearchEngine.gd          # find/replace ops on a string
  GmlColorTokens.gd           # color-literal scanner
  GmlEditorContext.gd         # shared "current buffer state" struct
```

Each module is a `RefCounted` with static methods only. None touch
`EditorInterface` or scene nodes. They operate on `(text, cursor, …)`
and return data. This makes them unit-testable without instantiating
the editor panel.

The existing `addons/gtml/editor/gml_editor_panel.gd` becomes the wiring
layer: instantiates the engines, hooks CodeEdit signals to them,
renders results. Target ≤ 900 LOC (currently ~700; we add ~200 of
wiring and offload ~200 of logic to engines).

## §1 — Autocomplete

### Context detection

A cheap regex on the line up to the cursor classifies the context:

| Buffer | Context | Completions |
|---|---|---|
| HTML | inside `<` and before space/`>` | element tag names |
| HTML | inside `<tag ` after space | attributes valid for `tag` |
| HTML | inside `type="…"` (or other enumerated attr) | known values for that attr |
| HTML | inside `class="…"` | class names declared in the CSS buffer |
| CSS | start of declaration block | property names |
| CSS | after `:` in a declaration | value keywords for that property |
| CSS | inside `var(` | `--name` declarations from the CSS buffer |
| CSS | start of selector | tag names + `.` + `#` + structural pseudos |

### Lookup tables

Sources of truth, in priority order:

- **Element tags:** union of `GmlRenderer._dispatch`'s match arms
  (`div`, `section`, `header`, `p`, `h1-h6`, `button`, `input`,
  `textarea`, `select`, `option`, `img`, `br`, `hr`, `progress`, `svg`,
  `ul`, `ol`, `li`, `a`, `label`, `strong`, `b`, `em`, `i`, `span`).
- **Attributes per tag:** a hand-curated map (~20 entries). For unknown
  tags → core attrs (`class`, `id`, `title`, `aria-node`).
- **Enumerated attribute values:** `type` → text/password/email/number/
  checkbox/radio/range/submit. `cursor`-like attrs: none for HTML.
- **CSS property names:** union of `GmlCssParser.PASSTHROUGH_PROPS`,
  `SIZE_PROPS`, `DIMENSION_PROPS`, `COLOR_PROPS`, `BORDER_PROPS`,
  `FLOAT_PROPS`, `TRANSITION_PROPS`. Plus `transform`,
  `background-color`, `color`, `font-family`, `font-weight`, etc.
- **CSS property values:** hand-curated map keyed by property name.
  Falls back to nothing for unknown properties.
- **Class names + `--vars`:** parsed live from the current CSS buffer
  on each completion request. Cheap regex (`\.\w[\w-]*` / `--\w[\w-]*`).

### Wiring

`CodeEdit.code_completion_enabled = true`. Trigger chars (set via
`code_completion_prefixes`): `<`, ` `, `"`, `:`, `.`, `#`, `(`.

Editor panel handles `code_completion_requested` → builds the context →
calls `GmlAutocompleteSource.get_candidates(context)` → calls
`add_code_completion_option(kind, display, insert_text)` for each →
`update_code_completion_options(true)` to show the popup.

For snippet-style insertions (e.g. typing `div` completes to
`<div></div>` with caret between), the panel listens to
`code_completion_inserted` and adjusts caret column.

## §2 — Find & Replace

Existing search bar at top of editor gains a collapsed second row:

```
[ Search:    [______________]  Aa  [.*]  [< >]  3/12  [×]  ]
[ Replace:   [______________]  [Replace] [Replace All]      ]
```

- `Aa` — existing match-case toggle.
- `.*` — new regex toggle.
- `Replace` — replace current match + advance.
- `Replace All` — replace all in active buffer, report count via the
  match-count label.

Bound to **Ctrl+H** to reveal the replace row; **Ctrl+F** continues to
just show the find row.

Engine in `GmlSearchEngine.gd`:

```gdscript
class_name GmlSearchEngine
extends RefCounted

static func find_all(text: String, query: String, case_sensitive: bool, use_regex: bool) -> Array
  # Returns [{line, col, length}, ...]

static func replace_all(text: String, query: String, replacement: String, case_sensitive: bool, use_regex: bool) -> Dictionary
  # Returns {new_text: String, count: int}

static func replace_one(text: String, match: Dictionary, replacement: String) -> String
```

Cross-buffer find (search HTML + CSS simultaneously) is deferred.

## §3 — Jumps

Triggers: **Ctrl+Click** anywhere in the editor, or **F12** when the
caret is on a jumpable token. Both routed through:

```gdscript
GmlJumpResolver.resolve(
    html_text: String,
    css_text: String,
    source: "html"|"css",
    line: int,
    col: int,
) -> Dictionary | null   # {target_source, line, col} or null
```

Jump table:

| Cursor on… | Jumps to… |
|---|---|
| HTML `class="card"` | first `.card` rule in CSS |
| HTML `id="x"` | `#x` rule in CSS (if present) |
| CSS `.card { ... }` selector | first HTML element with class containing `card` |
| CSS `#x { ... }` selector | HTML element with `id="x"` |
| CSS `var(--brand)` | the `--brand: ...;` declaration line |
| CSS `--brand: ...;` declaration | first `var(--brand)` use |

The panel switches tab if `target_source != current_source`, then moves
the caret. A `_jump_history` array on the panel records every jump;
**Alt+Left** pops the history and returns to the previous position.

A small ◇ gutter glyph marks lines that contain a known jump source so
the user discovers the feature without reading docs.

## §4 — Color picker

`GmlColorTokens.scan(text)` returns a list of color literals:

```gdscript
class_name GmlColorTokens
extends RefCounted

static func scan(text: String) -> Array
  # [{line: int, col: int, length: int, color: Color, kind: "hex"|"rgb"|"name"}]

static func format(color: Color, kind: String) -> String
  # Render back to the original kind: "#rrggbb" / "rgba(r,g,b,a)" / etc.
```

Recognizes: `#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb(r,g,b)`, `rgba(r,g,b,a)`,
and named colors via `Color.html_is_valid(name)`.

After every text-change debounce (200ms), the panel re-scans and
populates a dedicated CodeEdit gutter:

- `code_edit.add_gutter(0)` once on init.
- For each scanned literal, `set_line_gutter_icon(line, gutter_idx,
  swatch_texture)` where the swatch is a generated 12×12 Texture2D
  filled with the color.
- `set_line_gutter_clickable(line, gutter_idx, true)`.

On gutter click → spawn a `ColorPicker` popup positioned next to the
gutter pixel. On `color_changed`, write back the new value via
`GmlColorTokens.format(color, original_kind)` so authors keep their
chosen literal style (hex stays hex, rgba stays rgba).

## §5 — Multi-cursor + selection

CodeEdit supports multi-caret natively via `multiple_carets_enabled`.
We enable it + wire these keybinds in the panel's `_input`:

- **Ctrl+D** — add next match of selected text as a new caret.
- **Ctrl+Alt+Up / Ctrl+Alt+Down** — add caret one line above / below.
- **Ctrl+L** — select current line (use Godot's binding if present;
  otherwise wire ourselves).
- **Ctrl+Shift+L** — select all occurrences of current selection.

No new engine module — just keybind dispatch. The "find next match" for
Ctrl+D reuses `GmlSearchEngine.find_all`.

## Testing

Mirrors existing GTML test patterns. All engines are pure → testable
without instantiating the panel.

| File | Tests |
|---|---|
| `tests/unit/test_autocomplete_source.gd` | ~15: each context (HTML tag/attr/value, CSS prop/value/var/class/selector) feeds `(text, cursor)` → asserts candidate list contents |
| `tests/unit/test_jump_resolver.gd` | ~10: each jump type, dual buffers + cursor → assert target |
| `tests/unit/test_search_engine.gd` | ~12: find_all, replace_all, regex on/off, case on/off, count returned, edge cases (zero matches, overlapping) |
| `tests/unit/test_color_tokens.gd` | ~8: scan hex (3/6/8 digit) / rgb / rgba / named, malformed, format round-trip |
| `tests/unit/test_editor_panel_v06.gd` | ~5: integration — load panel, simulate `gui_input`, assert popup fires, jump moves caret, replace updates text |

## File budget

| File | Target LOC |
|---|---|
| `GmlAutocompleteSource.gd` | ~250 |
| `GmlJumpResolver.gd` | ~150 |
| `GmlSearchEngine.gd` | ~120 |
| `GmlColorTokens.gd` | ~100 |
| `GmlEditorContext.gd` | ~40 |
| `gml_editor_panel.gd` | currently ~700; target ≤ 900 after wiring |

Total new code ≈ 1000 LOC; total test code ≈ 600 LOC.

## Phasing

Single bundled v0.6 PR. Suggested commit order, each commit shippable
in isolation:

1. **Engine scaffold** — `GmlEditorContext.gd` + empty modules + test
   scaffolds with one trivial test each. Locks the file layout.
2. **Autocomplete engine + tests** — `GmlAutocompleteSource.gd`
   complete, with all 15 unit tests. Panel wiring deferred.
3. **Autocomplete wiring** — hook CodeEdit `code_completion_requested`
   to the source. Manual editor test confirms popup.
4. **Search engine + replace UI** — `GmlSearchEngine.gd` + tests + add
   the replace row to the search bar + wire keybinds.
5. **Jump resolver + UI** — `GmlJumpResolver.gd` + tests + Ctrl+Click /
   F12 / Alt+Left wiring + gutter glyph.
6. **Color tokens + picker** — `GmlColorTokens.gd` + tests + gutter
   swatches + ColorPicker popup.
7. **Multi-cursor keybinds** — enable multi-caret + Ctrl+D / Ctrl+L /
   Ctrl+Alt+Up/Down handlers.
8. **Bump 0.6.0 + CHANGELOG + docs page** (`docs/editor.md`).

## Known unknowns

- CodeEdit's `multiple_carets_enabled` and per-platform key chord
  detection vary across Godot 4.x patch versions. Spike during phase 7;
  may need to fall back to capturing keys at `_unhandled_input`.
- Gutter icon click-region behavior with theme overrides — verify the
  ColorPicker can be positioned in screen-space.
- `update_code_completion_options(true)` cancellation behavior — if the
  user types past a trigger before our async-ish lookup returns, the
  popup may stale. All our lookups are synchronous + sub-millisecond on
  ~1000-line files, so this shouldn't trigger; document the assumption.

## Out of scope (deferred to a later release)

- Live rendered preview pane.
- Cross-buffer find / find in files.
- Code formatting.
- Snippet library beyond the implicit tag→`<tag></tag>` completion.
- LSP / external protocol support.
- Outline / symbol panel.
- Diff vs disk indicator.
- Tabs for multiple HTML/CSS files (only the active GmlView's pair).
