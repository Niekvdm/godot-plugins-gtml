# Focus & navigation

*Keyboard and gamepad navigation: focusable elements, Tab order, focus traps, and v-for.*

## What is focusable

An element is automatically made focusable (`FOCUS_ALL`) if it is any of:

- A native form control: Button, LineEdit, TextEdit, CheckBox, OptionButton, HSlider.
- An `<a>` anchor element.
- Any element with an `@event` / `@click` attribute.
- Any element with `tabindex >= 0`.

Everything else is non-interactive (`FOCUS_NONE`) and skipped by Tab.

An element with `tabindex="-1"` is focusable (can receive focus via
`grab_focus()` or a click) but is excluded from the Tab chain.

## Tab order and tabindex

GTML follows the HTML `tabindex` specification:

1. **Bucket A:** elements with `tabindex > 0`, sorted ascending. Ties
   broken by document (DOM) order.
2. **Bucket B:** all other tabbable elements (`tabindex == 0` or absent),
   in document order.
3. Tab traversal is A then B. Within each bucket the order is stable and
   deterministic.

```html
<button tabindex="2">Second</button>
<button>Fourth (natural order)</button>
<button tabindex="1">First</button>
<button>Third (natural order)</button>
```

Tab visits: First → Second → Third → Fourth.

Avoid positive `tabindex` values in new code — they force a global
ordering that is easy to break as the document grows. Natural document
order plus `tabindex="-1"` for elements that need programmatic focus is
the recommended pattern.

## autofocus

Add `autofocus` to a single element. On every full rebuild (not on
subsequent v-for reconciliations) GtmlView grabs focus on that element
after the tree is ready:

```html
<div focus-trap>
  <input autofocus v-model="search" placeholder="Search…">
  <button @click="close">Cancel</button>
</div>
```

If multiple elements declare `autofocus`, the first in document order
wins. In the editor, `autofocus` is intentionally suppressed during
hot-reload so it does not yank focus out of your code editor.

## focus-trap

Add `focus-trap` to a container to cycle Tab focus within that subtree:

```html
<div class="modal" focus-trap>
  <h2>Confirm</h2>
  <p>Are you sure?</p>
  <button @click="confirm">Yes</button>
  <button @click="cancel">No</button>
</div>
```

Tab at the last element in the trap loops back to the first; Shift-Tab at
the first loops to the last.

**Nested traps** are supported. Each `focus-trap` container forms its own
independent Tab group. Elements inside a nested trap do not leak into the
outer group; outer elements are excluded from the inner group.

The root (non-trap) group does NOT wrap: Tab at the last element stays
put, and Shift-Tab at the first stays put. There is no browser chrome to
cycle to.

## Seizing focus from code

Call `view.focus_first()` to programmatically grant focus to the first
Tab-order element in the root group (positive-`tabindex` elements first,
then natural order; trap subtrees excluded):

```gdscript
func _on_menu_opened() -> void:
    view.focus_first()
```

Returns `false` if no focusable element is found.

## Focus traversal after v-for reconciliation

When a v-for list is reconciled (items added, removed, or reordered),
`GtmlFocusManager.wire_focus` runs again on the content root. The chain
is recomputed from the live tree:

- Inserted clones join the chain at the correct position.
- Removed clones drop out.
- Surviving clones keep their focus state.

Focus is never stolen during reconciliation. If the focused element was
removed, focus clears naturally; game code is responsible for re-grabbing
it if needed.

## Gamepad and directional navigation

`focus_next` / `focus_previous` are wired to `focus_neighbor_bottom` /
`focus_neighbor_top` respectively. This means a gamepad's sequential
next/prev matches Tab exactly.

Directional navigation (up / down / left / right, d-pad) uses Godot's
built-in geometry-based neighbor search. For straight vertical lists this
is exact; for wrapped or flex layouts the geometry search may pick
non-obvious neighbors. There is no explicit grid model.

## Known limitations

- Directional (arrow/d-pad) navigation uses Godot's geometry search, not
  an explicit grid model. Sequential Tab/next-prev is deterministic.
- No roving-tabindex composite widgets. Each focusable element is its
  own Tab stop.
- The root group does not wrap at the ends. Tab at the last element stays
  put.
- Multiple `autofocus` declarations: the first in document order wins.
  All others are silently ignored.

## See also

- [Bindings](bindings.md) — directive catalog and expression grammar
- [../reference/gtmlview-api.md](../reference/gtmlview-api.md) — GtmlView API
