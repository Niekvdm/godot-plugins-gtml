# Limitations

_Known constraints in the current release, and items explicitly deferred to a future version._

---

## Reactivity and state

**No computed properties or watchers.**
There is no `computed: {}` equivalent and no `$watch`. Derived values must
be precomputed in GDScript and pushed via `state.set`. Godot signals serve
the role of lifecycle hooks.

**No cross-view shared state or global store.**
Each `GtmlView` has its own `GtmlState`. There is no equivalent of Vuex or
Pinia. Share data between views through your own GDScript layer.

---

## Expression grammar

Expressions support arithmetic (`+`, `-`, `*`, `/`, `%`), comparison
(`>`, `<`, `>=`, `<=`, `==`, `!=`), logical (`&&`, `||`, `!`), ternary
(`cond ? then : else`), and indexing (`array[i]`, `obj.key`).

**Function and method calls are not supported in binding expressions.**
`str(x)`, `items.size()`, and `Math.floor(x)` are not valid expression
syntax. The only call form that is parsed is `@event="handler(arg)"` for
event dispatching. Precompute any function results in GDScript and expose
them as state keys.

---

## Dynamic `:class` re-resolution

When a `:class` binding changes the active class set, only **visual
properties** are re-resolved: `color`, `background-color`,
`border-color`, `border-width`, `border-radius`, `opacity`, `font-size`.

Layout and structural properties in a dynamic class — `display`,
`flex-*`, `width`, `height`, `padding`, `margin`, `gap` — are silently
ignored (a one-time warning is pushed). Use `v-if` / `v-show` for layout
swaps.

**Descendant re-resolution from an ancestor's `:class` is not
supported.** If you toggle a class on `.card` and your CSS reads
`.card.selected .name { color: … }`, the child `.name` element will not
restyle. Only the element that carries the `:class` binding restyles.
Workaround: put the `:class` (and the selector) on the element you
actually want to restyle, or expose a precomputed state key that the child
binds to directly.

**`font-family` is not re-resolved on class change.** Only `font-size`
is included in the visual-property allowlist. Family stays as resolved at
build time.

---

## Focus traversal

**Directional navigation (arrow / d-pad) uses Godot geometry.**
`GtmlFocusManager` wires sequential `focus_next` / `focus_previous`
only. Up/down/left/right neighbor resolution is delegated to Godot's
built-in geometry-based search, which follows screen position rather than
an explicit grid definition.

**No roving tabindex / composite widgets.**
Every focusable element is its own Tab stop. A grid of items that should
behave as a single Tab stop with internal arrow navigation is not
supported.

**The root (non-trap) focus chain does not wrap.**
Tab on the last focusable element in the root group stays put;
Shift+Tab on the first stays put. Only `focus-trap` groups wrap their
chain.

---

## Pseudo-classes

`:active`, `:disabled`, and `:checked` parse and resolve correctly — CSS
rules using them are stored and matched. However, the transition system
only wires signals for `:hover` and `:focus`. Rules for `:active`,
`:disabled`, and `:checked` are never applied at runtime. Wiring those
state signals is deferred.

---

## CSS edge cases

**`text-indent` is parsed but not rendered.**
The value is stored as metadata on the Label (`label.set_meta("text_indent", …)`)
for future use, but `Godot 4`'s `Label` has no native text-indent
property. No visual indentation occurs.

**`cubic-bezier()` timing function falls back to `ease`.**
The `transition-timing-function` parser recognises the `cubic-bezier(…)`
token and does not emit a warning, but the Tween path maps it to
`Tween.TRANS_SINE` / `Tween.EASE_IN_OUT` (the same values as `ease`).

**SVG path arcs (`A` / `a`) are not rendered.**
`SvgDrawControl._parse_path_data` tokenises arc commands and skips their
seven parameters. The arc segment is omitted from the drawn path without
a warning.

**`calc()` does not support nested parentheses inside the expression.**
`GtmlCssEval.evaluate_calc` handles only the outer `calc(…)` wrapper.
An expression like `calc(100% - (20px + 4px))` will not evaluate
correctly. Unnested forms like `calc(100% - 24px)` work as expected.

---

## Forms

**`v-model` on `<select>` is single-selection only.**
`GtmlBindingApplier.register_v_model` wires `OptionButton.item_selected`
and reads `get_item_text(idx)`. Multiple-selection `<select>` is not
supported.

---

## What is shipped and not a limitation

`v-for :key` reconciliation is fully implemented. `GtmlVForReconciler.diff`
computes a keyed LIS-based op list; `GtmlRenderer._reconcile_v_for_region`
applies insert/remove/move ops to the scene tree. Multiple sibling `v-for`
regions within the same parent container have a known offset-drift bug
when an earlier region changes size (see the inline comment in
`_init_vfor_state`); single `v-for` per parent is unaffected.

---

## See also

- [Bindings guide](../guide/bindings.md)
- [Focus guide](../guide/focus.md)
