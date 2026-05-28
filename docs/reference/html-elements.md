# HTML Elements

*Authoritative tag list and supported-attribute reference for GTML's HTML renderer.*

---

## Supported Tags

| Tag | Godot Control produced | Notes |
|---|---|---|
| `div` | `VBoxContainer` / `HBoxContainer` / `FlowContainer` | Default `display:block` → `VBoxContainer`. `display:flex; flex-direction:row` → `HBoxContainer`. `flex-wrap:wrap` / `wrap-reverse` → `FlowContainer`. |
| `section` | same as `div` | Semantic alias; identical rendering to `div`. |
| `header` | same as `div` | Semantic alias; identical rendering to `div`. |
| `footer` | same as `div` | Semantic alias; identical rendering to `div`. |
| `nav` | same as `div` | Semantic alias; identical rendering to `div`. |
| `main` | same as `div` | Semantic alias; identical rendering to `div`. |
| `article` | same as `div` | Semantic alias; identical rendering to `div`. |
| `aside` | same as `div` | Semantic alias; identical rendering to `div`. |
| `form` | same as `div` | Semantic alias; identical rendering to `div`. Submit is handled by `<input type="submit">`. |
| `p` | `Label` (autowrap enabled) | Inherits `p_font_size` default. Supports text-shadow and text-decoration wrappers. |
| `span` | `Label` | Inline text node; inherits parent container's font defaults. |
| `h1` | `Label` | Default size: `h1_font_size` (32). |
| `h2` | `Label` | Default size: `h2_font_size` (24). |
| `h3` | `Label` | Default size: `h3_font_size` (20 in renderer; export default is also 20). |
| `h4` | `Label` | Default size: 16. |
| `h5` | `Label` | Default size: 13. |
| `h6` | `Label` | Default size: 11. |
| `label` | `Label` or `HBoxContainer`/`VBoxContainer` | Pure-text label → `Label`. When body contains element children (e.g. `<label><input>…</label>`) → `HBoxContainer`. The `for="id"` attribute wires a click to activate the target input. |
| `strong` / `b` | `Label` (bold simulated via outline) | No separate bold font required; uses `outline_size:1` simulation unless a `*-Bold` font variant is in the `fonts` dict. |
| `em` / `i` | `Label` | Stores `font_style: "italic"` as metadata; actual italic rendering depends on the loaded font. |
| `button` | `Button` | `@click="handler"` emits `button_clicked`. `type="submit"` emits `form_submitted`. |
| `input` | varies by `type` | `text`/`password`/`email`/`number` → `LineEdit`; `checkbox` → `CheckBox`; `radio` → `CheckBox` (in `ButtonGroup`); `range` → `HSlider`; `submit` → `Button`. Unknown types fall back to `LineEdit`. |
| `textarea` | `TextEdit` | `rows` and `cols` attributes set `custom_minimum_size`. |
| `select` | `OptionButton` | Child `<option>` elements populate items; `selected` attribute picks the default. `<option>` tags produce no control on their own. |
| `option` | *(none)* | Consumed by the parent `<select>` builder; dispatched nodes return `null`. |
| `img` | `TextureRect` | `src` attribute loads a `Texture2D`. Responsive by default; fixed when both `width` and `height` are set in CSS. |
| `br` | `Control` (8 px spacer) | Inserts a zero-width, 8 px tall spacer. |
| `hr` | `HSeparator` | `background-color` and `height` CSS properties apply. |
| `progress` | `ProgressBar` | `value` and `max` attributes map to `ProgressBar.value` / `max_value`. |
| `svg` | `SvgDrawControl` (custom `Control`) | Child elements `polygon`, `polyline`, `line`, `circle`, `ellipse`, `rect`, `path`, `g` are parsed into draw commands. `viewBox`, `width`, `height`, `stroke`, `fill`, `stroke-width` attributes read. |
| `ul` | `VBoxContainer` (wraps `<li>` rows) | `list-style-type` CSS property sets bullet style (`disc`, `circle`, `square`, `none`). |
| `ol` | `VBoxContainer` (wraps `<li>` rows) | `list-style-type` sets counter style (`decimal`, `lower-alpha`, `upper-roman`, etc.). |
| `li` | `HBoxContainer` (marker + content column) | Marker label + `VBoxContainer` for content. Marker hidden when `list-style-type:none`. |
| `a` | `LinkButton` (simple text) or `HBoxContainer` (complex children) | `href` emits `link_clicked`. `@click` emits `button_clicked` instead. With non-text children (e.g. an `<svg>` icon) renders as a clickable `HBoxContainer`. |

Unknown tags are treated as `div` with a `push_warning`.

---

## Supported Attributes

### Identity and Styling

| Attribute | Applies to | Description |
|---|---|---|
| `id` | any element | Registers the control via `GtmlView.register_element()` for `get_element_by_id()` / `get_wrapper_by_id()` lookups. Also sets `Control.name`. |
| `class` | any element | Matched by the CSS selector engine. Supports multiple space-separated classes. |
| `aria-node` | any element | Sets `Control.name` on the inner control for accessible identification. Overrides the `id`-derived name when both are present. |
| `title` | any element | Sets `Control.tooltip_text`. |

### Form and Input

| Attribute | Applies to | Description |
|---|---|---|
| `type` | `input` | Controls which Godot widget is created: `text`, `password`, `email`, `number`, `checkbox`, `radio`, `range`, `submit`. |
| `placeholder` | `input`, `textarea` | Sets placeholder text on `LineEdit` / `TextEdit`. |
| `value` | `input` | Initial value for `LineEdit` (`text`), default text for `submit` button, initial value for `HSlider`, and the emitted value for radio inputs. |
| `name` | `input`, `select`, `textarea` | Used as the key in `get_form_data()` when `id` is absent. Groups radio inputs into a shared `ButtonGroup`. |
| `disabled` | `input`, `textarea`, `select`, `button` | Sets `editable = false` on `LineEdit`/`TextEdit`/`HSlider`, `disabled = true` on `Button`/`CheckBox`/`OptionButton`. |
| `checked` | `input type="checkbox"`, `input type="radio"` | Sets initial `button_pressed` state. |
| `selected` | `option` | Marks the default selected option in a `<select>`. |
| `rows` | `textarea` | Minimum height in rows (1 row ≈ 24 px). Default `4`. |
| `cols` | `textarea` | Minimum width in columns (1 col ≈ 8 px). Default `40`. |
| `min`, `max`, `step` | `input type="range"` | Map to `HSlider.min_value`, `max_value`, `step`. |
| `for` | `label` | Wires a click on the label to activate the input with the matching `id`. |

### Media

| Attribute | Applies to | Description |
|---|---|---|
| `src` | `img` | Path to a `Texture2D` resource (`res://…`). |
| `href` | `a` | Emitted as `link_clicked(href)` when the anchor is clicked without `@click`. |
| `target` | `a` | Captured alongside `href` but emitted as the second argument to `link_clicked`. Note: the signal declaration on `GtmlView` only declares one parameter (`href: String`); the second argument is passed at the call site — see concern below. |

### Event Handlers

| Attribute | Applies to | Description |
|---|---|---|
| `@click` | `button`, `a`, any element with binding | Emits `button_clicked(value)`. When the value is a call expression (`handler(args)`), emits `item_clicked(handler, args)` instead. |
| `@keydown` | `input` (text types) | Emits `key_pressed(handler, event)` on key-down. |
| `v-on:<event>` | any element | Long-form equivalent of `@<event>`. |

### Binding Directives

| Attribute | Applies to | Description |
|---|---|---|
| `:attr` / `v-bind:attr` | any element | Reactively binds the attribute to a `GtmlState` expression. Re-applies when the dependent key changes. |
| `v-model` | `input`, `textarea`, `select` | Two-way binding: state → control and control → state. Value is the state key name (not an expression). |
| `v-show` | any element | Toggles `Control.visible` based on a state expression. |
| `v-if` | any element | Omits the element from the tree entirely when the expression is falsy. Evaluated at build / reconcile time. |
| `v-for` | any element | Expands the element into N siblings from a state array. Format: `"item in array"` or `"(item, index) in array"`. |
| `:key` | element with `v-for` | Key expression for v-for reconciliation (stable identity across array mutations). |

### Focus

| Attribute | Applies to | Description |
|---|---|---|
| `tabindex` | any element | Sets tab order. `tabindex="0"` → participates normally; `tabindex="-1"` → focusable by script, skipped by Tab. |
| `autofocus` | any element | Calls `grab_focus()` on the first such element after each build (runtime only; suppressed in the editor to avoid yanking focus from the code editor). |
| `focus-trap` | container elements | Confines Tab navigation to the subtree rooted at this element. |

---

## See also

- [../guide/selectors.md](../guide/selectors.md)
- [gtmlview-api.md](gtmlview-api.md)
