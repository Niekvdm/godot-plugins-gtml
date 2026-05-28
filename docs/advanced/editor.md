# Editor

_Reference for the GTML editor pane's five power-tools: autocomplete, jump navigation, color picker, multi-cursor, and find & replace._

The GTML editor panel exposes a tabbed CodeEdit pair (HTML / CSS). Five
engine classes — `GtmlAutocompleteSource`, `GtmlJumpResolver`,
`GtmlColorTokens`, `GtmlSearchEngine`, and `GtmlEditorContext` — live
under `addons/gtml/src/editor/`. Each is a static `RefCounted` that
operates on plain strings; none touch the scene tree, so they are
unit-testable in isolation.

---

## Autocomplete

`GtmlAutocompleteSource.get_candidates(ctx: GtmlEditorContext)` returns
an `Array` of `{label, kind, insert_text}` dictionaries. `kind` is one
of `"tag"`, `"attr"`, `"value"`, `"property"`, `"var"`, `"class"`.

The editor sets `code_completion_enabled = true` and registers trigger
characters `<`, ` `, `"`, `:`, `.`, `#`, `(` on the CodeEdit. On every
`code_completion_requested` signal the panel builds a `GtmlEditorContext`
snapshot and calls `get_candidates`.

### HTML buffer

| Cursor position | Completions returned |
|---|---|
| Inside `<…` before any whitespace | Element tag names |
| Inside `<tag ` after space | Attributes valid for that tag, plus core attrs (`class`, `id`, `title`, `aria-node`, `@click`, `style`) |
| Inside an attribute value for `class="…"` | All `.classname` selectors found in the CSS buffer (live regex scan) |
| Inside `type="…"` on `<input` | `text`, `password`, `email`, `number`, `checkbox`, `radio`, `range`, `submit` |

### CSS buffer

| Cursor position | Completions returned |
|---|---|
| Inside a declaration block, before `:` | Property names (full union of `GtmlCssParser` constant lists) |
| After `:` in a declaration | Value keywords for that property (enumerable properties only; unknown properties return nothing) |
| Inside an open `var(` call | All `--name` declarations found in the current CSS buffer |

---

## Jump navigation

`GtmlJumpResolver.resolve(ctx: GtmlEditorContext)` returns
`{target_kind, line, col}` or `null`. The panel wires two triggers:

- **Ctrl+Click** — resolve at the click position.
- **F12** — resolve at the current caret.

A small diamond gutter glyph marks lines that contain a jumpable token so
you can discover targets without reading docs.

**Alt+Left** pops the `_jump_history` stack on the panel and returns to
the previous caret position.

### Jump table

| Source buffer | Token under cursor | Destination |
|---|---|---|
| HTML | `class="card"` value token | First `.card` rule in CSS |
| HTML | `id="x"` value token | `#x` rule in CSS (if present) |
| CSS | `.card` selector token | First HTML element with that class |
| CSS | `#x` selector token | HTML element with `id="x"` |
| CSS | `var(--brand)` use | The `--brand:` declaration line (skips current line) |
| CSS | `--brand:` declaration | First `var(--brand)` use (skips current line) |

---

## Color picker

After every text-change debounce `GtmlColorTokens.scan(text)` rescans the
active buffer and returns `{line, col, length, color, kind}` tokens where
`kind` is one of `"hex"`, `"rgb"`, `"rgba"`.

Recognized formats:

- `#rgb` (shorthand — expanded to six-digit equivalent)
- `#rrggbb`
- `#rrggbbaa` (eight-digit with alpha)
- `rgb(r, g, b)`
- `rgba(r, g, b, a)`

For each token the panel stamps a 12×12 filled swatch in a dedicated
CodeEdit gutter. Clicking a swatch opens a `ColorPicker` popup positioned
next to the gutter pixel.

On `color_changed`, `GtmlColorTokens.format(color, kind)` writes the new
value back in the original literal style — hex stays hex, rgba stays rgba.

---

## Multi-cursor

The panel enables `multiple_carets_enabled` on the CodeEdit and wires the
following keybinds in `_input`:

| Key chord | Action |
|---|---|
| **Ctrl+D** | Add next match of the current selection as a new caret (uses `GtmlSearchEngine.find_all`) |
| **Ctrl+L** | Select the current line |
| **Ctrl+Shift+L** | Select all occurrences of the current selection |
| **Ctrl+Alt+Up** | Add a caret one line above |
| **Ctrl+Alt+Down** | Add a caret one line below |

No separate engine module; keybind dispatch lives in the panel's `_input`
handler.

---

## Find & Replace

**Ctrl+F** shows the find bar. **Ctrl+H** reveals the replace row below
it.

Controls: match-case toggle (`Aa`), regex toggle (`.*`), current-match
counter (`3/12`), a **Replace** button (replace current match + advance),
and a **Replace All** button (replaces all in the active buffer and
updates the counter).

The underlying engine is `GtmlSearchEngine`, which exposes three static
methods:

```gdscript
GtmlSearchEngine.find_all(text, query, case_sensitive, use_regex) -> Array
# Returns [{line, col, length}, ...]

GtmlSearchEngine.replace_all(text, query, replacement, case_sensitive, use_regex) -> Dictionary
# Returns {new_text, count}

GtmlSearchEngine.replace_one(text, match_info, replacement) -> String
```

Case-insensitive regex is implemented by prepending `(?i)` to the pattern
before calling Godot's `RegEx`. Find operates on the active buffer only;
cross-buffer find is not supported.

---

## See also

- [Getting started](../guide/getting-started.md)
