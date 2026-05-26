# The GML Editor Pane

GTML ships an in-editor pane (visible when a `GmlView` node is selected)
that lets you edit the HTML and CSS files attached to that view without
leaving Godot. As of v0.6 it includes the power-tools you expect from
modern code editors.

## Autocomplete

Triggered automatically when you type one of the prefix characters
(`<`, ` `, `"`, `:`, `.`, `#`, `(`), or manually with **Ctrl+Space**.

Context-aware:

| You type… | You get… |
|---|---|
| `<` in HTML | Element tag names |
| `<tag ` in HTML | Attributes valid for `tag` |
| `class="` in HTML | Class names declared in the paired CSS buffer |
| `type="` in `<input` | The supported input-type keywords |
| Inside a CSS `{ }` block | CSS property names |
| After `: ` on a CSS line | Value keywords for that property |
| `var(` in CSS | `--*` declarations scanned from the buffer |

## Find & Replace

- **Ctrl+F** opens the Find bar.
- **Ctrl+H** also opens the Replace row.
- Toggle **Aa** for case sensitivity, **.\*** for regex mode.
- Replace updates the current match and advances; Replace All reports the
  count.

## Jumps

- **Ctrl+Click** or **F12** on a jumpable token follows it:
  - HTML `class="card"` → first `.card` rule in the CSS tab
  - HTML `id="x"` → `#x` rule
  - CSS `var(--brand)` → `--brand: ...;` declaration
  - CSS `--brand: ...;` declaration → first `var(--brand)` use
  - CSS `.card` / `#x` selector → first matching HTML element
- **Alt+Left** returns to the previous position.

## Color picker

Color literals (`#rrggbb`, `#rrggbbaa`, `rgb(…)`, `rgba(…)`) get a swatch
in the line gutter. Click the swatch → ColorPicker popup. Picked colors
round-trip back to the buffer in the literal's original kind.

## Multi-cursor

- **Ctrl+D** — add caret at the next occurrence of the selection (or word
  under the caret if there's no selection).
- **Ctrl+L** — select the current line.
- **Ctrl+Alt+Up** / **Ctrl+Alt+Down** — add a caret one line above /
  below.
- All standard CodeEdit multi-caret edits work once multiple carets
  exist.

## Parse warnings overlay

(Carries over from v0.4.) Save your file with **Ctrl+S** — if the HTML
or CSS parser emits a warning, a panel appears at the bottom listing
each one. Click an entry to jump the caret to that line.
