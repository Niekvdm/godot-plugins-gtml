# GtmlView API

*Complete reference for the `GtmlView` node: state, signals, public methods, and exports.*

---

## State

`view.state` is a `GtmlState` (`RefCounted`). Writes re-render every binding registered on that key.

Property access uses GDScript `_set`/`_get` virtuals, so all three forms are equivalent:

```gdscript
view.state.set("score", 42)   # named method
view.state["score"] = 42      # subscript
view.state.score = 42         # property syntax
```

| Method | Signature | Description |
|---|---|---|
| `set` | `set(key: String, value: Variant) -> bool` | Write a key; emits `state_changed` only when the value differs from the stored one. Routes through `_set` virtual. |
| `get` | `get(key: String) -> Variant` | Read a key; returns `null` when absent. Routes through `_get` virtual. |
| `set_state` | `set_state(values: Dictionary) -> void` | Batch-write multiple keys. Emits `state_changed` per **changed** key only; no-op keys are silently skipped. |
| `has` | `has(key: String) -> bool` | Returns `true` when the key exists in the store. |
| `keys` | `keys() -> PackedStringArray` | Returns all stored keys as strings. |

### Signal

| Signal | Parameters | When fired |
|---|---|---|
| `state_changed` | `key: String, new_value: Variant, old_value: Variant` | After a write that actually changed the stored value. Wired internally to the binding registry; consumers may also connect to it directly. |

---

## Signals

| Signal | Parameters | When fired |
|---|---|---|
| `button_clicked` | `method_name: String` | A `<button @click="handler">` or bare `<a @click="handler">` is pressed. `method_name` is the attribute value. |
| `link_clicked` | `href: String` | An `<a href="…">` without `@click` is clicked. `href` is the attribute value. |
| `input_changed` | `input_id: String, value: String` | A `<input>`, `<textarea>`, `<input type="range">`, or `<input type="radio/checkbox">` value changes. `input_id` is the element's `id` or `name`. |
| `selection_changed` | `select_id: String, value: String` | A `<select>` selection changes. `select_id` is the element's `id` or `name`. |
| `form_submitted` | `form_data: Dictionary` | A `<input type="submit">` button is clicked. `form_data` is the snapshot from `get_form_data()`. |
| `key_pressed` | `handler: String, event: InputEvent` | A `<input @keydown="handler">` receives a key-down event. `event` is the raw `InputEventKey`. |
| `item_clicked` | `handler: String, args: Array` | An `@event="handler(args…)"` with arguments fires. Bare `@event="handler"` (no parentheses) continues to route through `button_clicked`/`link_clicked` instead. |

---

## Public Methods

| Method | Signature | Returns / Notes |
|---|---|---|
| `get_element_by_id` | `get_element_by_id(element_id: String) -> Control` | Returns the **inner** `Control` (e.g. `Label`, `Button`, `LineEdit`) for the given `id`, or `null`. Use for reading/modifying content properties such as `text` or `disabled`. |
| `get_wrapper_by_id` | `get_wrapper_by_id(element_id: String) -> Control` | Returns the **outermost wrapper** (`MarginContainer`, `PanelContainer`, …) that contains the element, or the inner control if no wrapper exists. Use for toggling `visible` / `display:none`. |
| `get_radio_group` | `get_radio_group(group_name: String) -> ButtonGroup` | Returns (or creates) the `ButtonGroup` for radio inputs sharing `name`. |
| `get_form_data` | `get_form_data() -> Dictionary` | Snapshot of all registered input values keyed by `id`. Types: `LineEdit`/`TextEdit` → `String`; `HSlider` → `float`; `CheckBox` (no group) → `bool`; `OptionButton` → selected item text; radio groups → selected radio's `value` attribute, keyed by group name. |
| `focus_first` | `focus_first() -> bool` | Grabs focus on the first tab-order-eligible control in the view. Returns `false` when nothing is focusable. Useful for seizing keyboard focus when a menu opens. |
| `get_tag_defaults` | `get_tag_defaults() -> Dictionary` | Returns the current tag-default settings as a dictionary (keys: `h1_font_size`, `h2_font_size`, `h3_font_size`, `p_font_size`, `default_font_color`, `default_gap`, `default_margin`, `default_padding`, `fonts`). Used internally by the renderer; also callable for inspection. |

---

## Exports

### Core

| Export | Type | Default | Description |
|---|---|---|---|
| `html_path` | `String` (`@export_file("*.html")`) | `""` | Path to the HTML template. Setting this queues a rebuild. |
| `css_path` | `String` (`@export_file("*.css")`) | `""` | Path to the CSS stylesheet. Setting this queues a rebuild. |
| `auto_reload_in_editor` | `bool` | `true` | Hot-reload the view in the editor whenever the HTML or CSS file changes on disk. |

### Debug

| Export | Type | Default | Description |
|---|---|---|---|
| `show_nodes_in_editor` | `bool` | `false` | Makes generated nodes visible in the Scene dock for inspection. Setting this queues a rebuild in the editor. |

### Tag Defaults

Override the baseline sizes used when an element has no explicit `font-size` CSS rule.

| Export | Type | Default |
|---|---|---|
| `h1_font_size` | `int` | `32` |
| `h2_font_size` | `int` | `24` |
| `h3_font_size` | `int` | `20` |
| `p_font_size` | `int` | `16` |
| `default_font_color` | `Color` | `Color.WHITE` |
| `default_gap` | `int` | `8` |
| `default_margin` | `int` | `0` |
| `default_padding` | `int` | `0` |

### Fonts

| Export | Type | Default | Description |
|---|---|---|---|
| `fonts` | `Dictionary` | `{}` | Maps font-family name strings to `Font` resources. Example: `{"Orbitron": preload("res://assets/Fonts/Orbitron-Regular.ttf")}`. Bold variants are resolved by convention (`Roboto-Bold`, `RobotoBold`, `Roboto Bold`, `Roboto-700`) before falling back to the base family. |

---

## Lifecycle

- **Build**: called in `_ready`. Parses HTML, resolves CSS, and builds the `Control` tree. At runtime a single frame is awaited first so the `GtmlView`'s size is stable.
- **Hot-reload**: when `auto_reload_in_editor` is `true`, the editor polls file modification times each process frame and also subscribes to `EditorFileSystem.filesystem_changed`. A rebuild is queued whenever either HTML or CSS is modified.
- **State survival**: `view.state` is created once in `_init` and survives rebuilds. Bindings are re-registered against the same state store after each rebuild, so reactive values are preserved across hot-reloads.

---

## See also

- [../guide/reactivity.md](../guide/reactivity.md)
- [../guide/bindings.md](../guide/bindings.md)
- [../guide/forms-and-inputs.md](../guide/forms-and-inputs.md)
