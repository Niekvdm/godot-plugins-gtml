# CSS Properties

*Exhaustive reference for every CSS property GTML both parses and applies. Properties are grouped by category.*

**Key:** "parsed, not applied" = the parser accepts the property and stores it in the rule, but no applier reads it from the style dictionary at render time.

---

## Layout

| Property | Accepted Values | Notes |
|---|---|---|
| `display` | `block`, `flex`, `none` | `block` → `VBoxContainer` (column); `flex` → layout determined by `flex-direction`; `none` sets `Control.visible = false`. |
| `flex-direction` | `row`, `column` | `row` → `HBoxContainer`; `column` → `VBoxContainer`. Only meaningful when `display:flex`. |
| `flex-wrap` | `nowrap`, `wrap`, `wrap-reverse` | `wrap`/`wrap-reverse` → `FlowContainer` instead of `BoxContainer`. |
| `justify-content` | `flex-start`, `flex-end`, `center`, `space-between`, `space-around`, `space-evenly`, `start`, `end` | Main-axis alignment. `space-*` values insert spacer `Control` nodes; `flex-start`/`center`/`flex-end` set `BoxContainer.alignment`. Only applied to `BoxContainer` (not `FlowContainer`). |
| `align-items` | `flex-start`, `flex-end`, `center`, `stretch`, `start`, `end` | Cross-axis alignment applied to all children. `FlowContainer` maps `flex-start`/`center`/`flex-end` to `ALIGNMENT_BEGIN/CENTER/END`. |
| `align-self` | `flex-start`, `flex-end`, `center`, `stretch`, `start`, `end`, `auto` | Per-child cross-axis override. `auto` is ignored. Applied by the parent builder on the child control's `size_flags`. |
| `order` | `<integer>` | Sort order of children within a flex container. Lower values appear first. Parsed as `float`; 0 is default. |
| `gap` | `<integer>px` | Uniform gap between children. Applied as `BoxContainer.separation` (or `FlowContainer.h_separation`/`v_separation`). Also used as list item separation. |
| `row-gap` | `<integer>px` | Gap between rows in a vertical layout or `FlowContainer`. |
| `column-gap` | `<integer>px` | Gap between columns in a horizontal layout or `FlowContainer`. |
| `overflow` | `visible`, `hidden`, `scroll`, `auto` | `hidden` → `clip_contents = true`; `scroll`/`auto` → wraps in `ScrollContainer`; `visible` → `clip_contents = false`. |
| `overflow-x` | `visible`, `hidden`, `scroll`, `auto` | Horizontal scroll axis. `scroll`/`auto` enables `ScrollContainer.horizontal_scroll_mode`. |
| `overflow-y` | `visible`, `hidden`, `scroll`, `auto` | Vertical scroll axis. `scroll`/`auto` enables `ScrollContainer.vertical_scroll_mode`. |
| `visibility` | `visible`, `hidden` | `hidden` → sets `Control.modulate.a = 0.0` (control still occupies space). |

---

## Box / Spacing

| Property | Accepted Values | Notes |
|---|---|---|
| `padding` | `<integer>px` | Uniform padding. Wraps the content in a `MarginContainer`. |
| `padding-top` | `<integer>px` | |
| `padding-right` | `<integer>px` | |
| `padding-bottom` | `<integer>px` | |
| `padding-left` | `<integer>px` | |
| `margin` | `<integer>px` | Uniform outer margin. Wraps in an outer `MarginContainer` (outside padding). |
| `margin-top` | `<integer>px` | |
| `margin-right` | `<integer>px` | |
| `margin-bottom` | `<integer>px` | |
| `margin-left` | `<integer>px` | |

---

## Sizing

| Property | Accepted Values | Notes |
|---|---|---|
| `width` | `<integer>px`, `<percent>%` | `px` → `custom_minimum_size.x`. `100%` → `SIZE_EXPAND_FILL`. `<100%` → per-frame percent sizing via `GtmlPercentSizing`. Height of `0px` hides the control. |
| `height` | `<integer>px`, `<percent>%` | Same as `width` on the vertical axis. |
| `min-width` | `<integer>px` | Clamps `custom_minimum_size.x` upward. Only `px` units applied; `%` units parsed but not yet applied. |
| `min-height` | `<integer>px` | Clamps `custom_minimum_size.y` upward. |
| `max-width` | `<integer>px`, `<percent>%` | Enforced via `GtmlPercentSizing.attach_max_size()`. Stored as `max_width` / `max_width_percent` metadata. |
| `max-height` | `<integer>px`, `<percent>%` | Same as `max-width` on the vertical axis. |
| `flex-grow` | `<number>` | Maps to `size_flags_stretch_ratio` + `SIZE_EXPAND` flag in the parent's main axis direction. Values `<= 0` are ignored. |
| `flex-shrink` | `<number>` | Only `0` is acted upon (sets `SIZE_SHRINK_BEGIN`); values `> 0` rely on default container shrink behavior. |
| `flex-basis` | `<integer>px`, `<percent>%`, `auto` | Sets `custom_minimum_size` on the main axis. `auto` is ignored. |

---

## Color

| Property | Accepted Values | Notes |
|---|---|---|
| `color` | color value | Text / font color. Applied via `Label.add_theme_color_override("font_color", …)`. Also sets the `LinkButton` color and the SVG default stroke color. |
| `background-color` | color value | Wraps the element in a `PanelContainer` with a `StyleBoxFlat`. Skipped on controls that already have a panel stylebox. |
| `border-color` | color value | Sets all four side colors on the `StyleBoxFlat`. |
| `border-top-color` | color value | Individual side override. |
| `border-right-color` | color value | Individual side override. |
| `border-bottom-color` | color value | Individual side override. |
| `border-left-color` | color value | Individual side override. |

Color values accepted: named CSS colors, `#rrggbb`, `#rrggbbaa`, `#rgb`, `rgb(r,g,b)`, `rgba(r,g,b,a)`, `hsl(…)` (parsed by Godot's `Color.from_string`).

---

## Border

| Property | Accepted Values | Notes |
|---|---|---|
| `border` | `<width>px <style> <color>` | Shorthand. Parses width, style keyword (`solid`, `dashed`, `dotted`, `none`), and color. Wraps in `PanelContainer` with `StyleBoxFlat`. |
| `border-top` | same as `border` | Individual side shorthand. |
| `border-right` | same as `border` | Individual side shorthand. |
| `border-bottom` | same as `border` | Individual side shorthand. |
| `border-left` | same as `border` | Individual side shorthand. |
| `border-width` | `<integer>px` | Uniform width; overrides the shorthand width. |
| `border-top-width` | `<integer>px` | |
| `border-right-width` | `<integer>px` | |
| `border-bottom-width` | `<integer>px` | |
| `border-left-width` | `<integer>px` | |
| `border-radius` | `<integer>px` | Uniform corner radius via `StyleBoxFlat.set_corner_radius_all()`. |
| `border-top-left-radius` | `<integer>px` | Individual corner. |
| `border-top-right-radius` | `<integer>px` | Individual corner. |
| `border-bottom-left-radius` | `<integer>px` | Individual corner. |
| `border-bottom-right-radius` | `<integer>px` | Individual corner. |
| `box-shadow` | `<offset-x>px <offset-y>px [<blur>px] [<spread>px] <color>` | Applied to the `StyleBoxFlat` via `shadow_color`, `shadow_size`, and `shadow_offset`. Requires a border or background to be present (otherwise there is no stylebox to attach to). |
| `outline` | `<width>px <style> <color>` | Wraps the element in a custom `OutlineContainer` that draws the outline outside the control bounds. Supports `solid`, `dashed`, `dotted` styles. Not re-resolved by dynamic `:class` (see limitation below). |
| `outline-offset` | `<integer>px` | Spacing between the element's edge and the outline. Only applied when `outline` is also set. |

---

## Effects

| Property | Accepted Values | Notes |
|---|---|---|
| `opacity` | `0.0` – `1.0` | Sets `Control.modulate.a`. Clamped to `[0, 1]`. |

---

## Transition

Transitions interpolate visual pseudo-class changes (`:hover`, `:focus`, `:active`, `:checked`) between StyleBoxFlat snapshots.

| Property | Accepted Values | Notes |
|---|---|---|
| `transition` | `<property> <duration>s [<timing-function>] [<delay>s]`, comma-separated | Shorthand. Parsed into property, duration, timing function, and delay. |
| `transition-property` | property name or `all` | Which property to animate. |
| `transition-duration` | `<number>s` or `<number>ms` | Animation duration. |
| `transition-timing-function` | `linear`, `ease`, `ease-in`, `ease-out`, `ease-in-out` | Easing curve. |
| `transition-delay` | `<number>s` or `<number>ms` | Delay before the transition starts. |

---

## Transform

| Property | Accepted Values | Notes |
|---|---|---|
| `transform` | `translate(<x>px, <y>px)`, `scale(<x>, <y>)`, `rotate(<deg>deg)`, combinations | Applied via `Control.position` offset, `Control.scale`, and `Control.rotation`. `pivot_offset` is set to `size * 0.5` so scale/rotate behave like `transform-origin: 50% 50%`. Position is set deferred (one process frame after layout). |

---

## Gradient / Background Image

| Property | Accepted Values | Notes |
|---|---|---|
| `background` | `linear-gradient(…)`, `radial-gradient(…)`, `url("res://…")` | Wraps the element in a `PanelContainer` containing a `GradientTexture2D`-backed `TextureRect`. Clips corners when `border-radius` is also present. |
| `background-image` | same as `background` | Alias; parsed and applied identically. |

---

## Font / Text

| Property | Accepted Values | Notes |
|---|---|---|
| `font-size` | `<integer>px` | Sets `Label.add_theme_font_size_override("font_size", …)`. |
| `font-family` | font-family name string | Looked up in `GtmlView.fonts` dictionary. Bold variants resolved by convention (see `GtmlView` exports). |
| `font-weight` | `100`–`900`, `normal` (400), `bold` (700) | Bold weights (`>= 600`) without a matching bold font variant fall back to outline simulation. |
| `letter-spacing` | `<integer>px` | Applied via `FontVariation.spacing_glyph`. Wrapped in a `FontVariation` override on the label's font. |
| `word-spacing` | `<integer>px` | Applied via `FontVariation.spacing_space`. Shares the `FontVariation` with `letter-spacing` when both are set. |
| `text-align` | `left`, `center`, `right`, `justify` | Maps to `Label.horizontal_alignment`. `justify` → `HORIZONTAL_ALIGNMENT_FILL`. |
| `text-transform` | `uppercase`, `lowercase`, `capitalize`, `none` | Mutates `Label.text` at build time. Stored as `text_transform` metadata. |
| `white-space` | `normal`, `nowrap`, `pre`, `pre-wrap`, `pre-line` | Controls `Label.autowrap_mode`. `pre`/`pre-wrap` also set `white_space_pre` metadata. |
| `text-overflow` | `ellipsis`, `clip` | Sets `Label.text_overrun_behavior` (`OVERRUN_TRIM_ELLIPSIS` / `OVERRUN_TRIM_CHAR`). Requires `white-space:nowrap` or a fixed width to take effect. |
| `line-height` | `<integer>px` | Applied as `Label.add_theme_constant_override("line_spacing", …)`. |
| `text-decoration` | `underline`, `line-through`, `overline`, `none`, combinations | Wraps the label in a `TextDecorationContainer` that draws lines in `_draw()`. `none` skips the wrapper. |
| `text-shadow` | `<offset-x>px <offset-y>px [<blur>px] <color>` | Wraps the label in a `TextShadowContainer` that stacks shadow `Label` copies behind the real label. |
| `text-indent` | `<integer>px` | **Parsed; stored as `text_indent` metadata on the `Label`. No native Godot indent support — not visually applied.** |
| `list-style-type` | `disc`, `circle`, `square`, `decimal`, `decimal-leading-zero`, `lower-alpha`, `upper-alpha`, `lower-latin`, `upper-latin`, `lower-roman`, `upper-roman`, `none` | Applied on `<ul>`/`<ol>` to set the marker character or counter format for `<li>` items. |
| `cursor` | `default`, `pointer`, `text`, `move`, `grab`, `grabbing`, `not-allowed`, `no-drop`, `wait`, `progress`, `crosshair`, `help`, `n-resize`, `s-resize`, `ns-resize`, `e-resize`, `w-resize`, `ew-resize`, `nw-resize`, `se-resize`, `nwse-resize`, `ne-resize`, `sw-resize`, `nesw-resize`, `col-resize`, `row-resize` | Parsed to a `Control.CursorShape` and applied as `Control.mouse_default_cursor_shape`. `grab`/`grabbing` fall back to `CURSOR_POINTING_HAND`. |

---

## Parsed-Only Properties (no visual effect)

The following properties are accepted by the parser but no applier currently reads them from the resolved style dictionary:

| Property | Status |
|---|---|
| `overflow-x` / `overflow-y` | Applied only when value is `scroll` or `auto` (enables scroll axis in `ScrollContainer`). `hidden`/`visible` values are parsed but not independently applied per-axis. |

---

## Dynamic `:class` Limitation

When a `:class` binding updates at runtime, only the **visual subset** is re-resolved in place:

`color`, `background-color`, `border-color`, `border-width`, `border-radius`, `opacity`, `font-size`

Layout and structural properties (`display`, `flex-*`, `width`, `height`, `padding`, `margin`, `gap`, etc.) are **ignored** by dynamic re-resolution and produce a warning. A full rebuild is required for layout changes.

`outline` and its sub-properties are also **not re-resolved** by dynamic `:class` (noted in `GtmlClassRestyler`).

---

## See also

- [../guide/selectors.md](../guide/selectors.md)
- [../guide/layout.md](../guide/layout.md)
- [../guide/tokens.md](../guide/tokens.md)
