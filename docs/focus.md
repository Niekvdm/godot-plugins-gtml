# Focus & keyboard / gamepad navigation (v0.8.3+)

GTML wires keyboard and gamepad focus traversal automatically. Every
interactive element is reachable without a mouse, in a deterministic
order.

## What's focusable

- Native form controls: `<button>`, `<input>`, `<textarea>`, `<select>`,
  checkboxes, sliders.
- `<a>` anchors.
- Any element with an `@event` handler (e.g. `<span @click="pick">`).
- Any element with `tabindex="0"` or higher.

Focusable elements get Godot's `FOCUS_ALL` so Tab, Shift-Tab, and a
gamepad's next/prev move between them. Arrow / d-pad directional
movement uses Godot's built-in geometry neighbor search.

## Tab order

Order follows the document, with HTML `tabindex` rules:

- `tabindex="0"` (or no tabindex on an interactive element) — natural
  document order.
- `tabindex="2"`, `tabindex="5"`, … (positive) — these come **first**,
  in ascending numeric order, before the natural-order elements.
- `tabindex="-1"` — focusable programmatically (and by click) but
  **skipped** by Tab.

## Initial focus

Add `autofocus` to grab focus when the view builds:

```html
<input v-model="search" autofocus>
```

The first `autofocus` element (document order) receives focus once per
build. Game code can also call `view.focus_first()` to grab the first
Tab-order element on demand (e.g. when opening a menu).

## Focus trap (modals / dialogs)

Add `focus-trap` to a container to cycle focus within it — Tab from the
last element returns to the first, and Shift-Tab from the first wraps to
the last:

```html
<div focus-trap>
  <input v-model="name" autofocus>
  <button @click="confirm">OK</button>
  <button @click="cancel">Cancel</button>
</div>
```

Nested traps are supported; the innermost trap owns its elements.

## v-for lists

The Tab chain is re-wired after every list change, so inserting or
removing items keeps the order correct. A focused input inside a list
keeps focus when the list reorders (its Control identity is preserved —
see [bindings](bindings.md)).

## Limitations

- Directional (arrow/d-pad) navigation uses Godot's geometry search, not
  an explicit grid model — sequential Tab/next-prev is exact, directional
  may pick non-obvious neighbors in wrapped layouts.
- No roving-tabindex composite widgets (each focusable is its own stop).
- The root (non-trapped) Tab chain does not wrap — Tab at the last
  element stays put.
