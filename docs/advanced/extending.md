# Extending GTML

_Where to hook new HTML elements and CSS properties without touching the renderer core._

---

## Adding an HTML element

GTML maps tag names to element builders through a single `match` block in
`GtmlRenderer._dispatch`. The pattern is:

```gdscript
func _dispatch(node, ctx: Dictionary) -> Dictionary:
    match node.tag:
        "div", "section", ...:
            return GtmlContainerBuilder.build_div(node, ctx)
        "my-tag":                          # <-- add your arm here
            return MyElementBuilder.build(node, ctx)
        _:
            push_warning("GtmlRenderer: unknown tag '%s', treating as div" % node.tag)
            return GtmlContainerBuilder.build_div(node, ctx)
```

Each arm must return `{"control": Control, "inner": Control}`. `inner` is
the focusable / style-target child (e.g. a `LineEdit` inside a wrapper
`PanelContainer`); use `inner = control` when there is no wrapping layer.

### The element builder pattern

Element builders live under `addons/gtml/src/html_renderer/elements/`.
Each is a static `RefCounted` (same convention as the CSS engines). The
builder receives:

- `node` — the parsed DOM node. `node.tag`, `node.attrs` (Dictionary),
  `node.children` (Array), `node.get_id()`, `node.get_classes()`.
- `ctx` — a build-context Dictionary with these callables and values:

| Key | Type | Purpose |
|---|---|---|
| `styles` | Dictionary | Full `node → resolved-style` map |
| `defaults` | Dictionary | Tag default sizes and font colors from `GtmlView.get_tag_defaults()` |
| `gml_view` | GtmlView | The owning view (may be null in headless tests) |
| `build_node` | Callable | Recurse into a child node |
| `get_style` | Callable | `get_style.call(node) -> Dictionary` |
| `wrap_with_margin_padding` | Callable | Wraps a control in a `GtmlWrap`-managed container |
| `transition_manager` | GtmlTransitionManager | For pseudo-class transitions |

A minimal builder looks like this:

```gdscript
class_name MyElementBuilder
extends RefCounted

static func build(node, ctx: Dictionary) -> Dictionary:
    var style: Dictionary = ctx.get_style.call(node)
    var control := MyControl.new()
    # … configure control from style and node.attrs …
    GtmlStyles.apply_text_color(control.label, style, ctx.defaults)
    var wrapped = ctx.wrap_with_margin_padding.call(control, style)
    return {"control": wrapped, "inner": control}
```

After `_dispatch` returns, `GtmlRenderer._build_node` automatically:

- Calls `_register_element_with_id` (wires `id`, `aria-node`, `title`).
- Calls `_apply_node_styles` (opacity, visibility, overflow, background-color).
- Calls `GtmlDimensions.apply` (width, height, flex-*, cursor, transform).
- Calls `GtmlTransitionSetup.setup` for pseudo-class transitions.
- Calls `_register_bindings_for_node` (`:attr`, `v-show`, `v-model`, `@event`).
- Calls `_stamp_focus_meta` (tabindex, autofocus, focus-trap).

You do not need to implement any of those in the builder.

---

## Adding a CSS property

CSS properties flow through three layers: the parser, the value converters,
and the style applier.

### 1 — Parser allowlist

`GtmlCssParser` holds six constant arrays (`addons/gtml/src/css/`) that
determine what gets type-converted and what is passed through as a raw
string:

| Constant | Parsed to |
|---|---|
| `PASSTHROUGH_PROPS` | `String` (returned as-is) |
| `SIZE_PROPS` | `int` (pixel/point integer) |
| `DIMENSION_PROPS` | `Dictionary` `{value, unit}` (supports `%`, `px`, `vw`, `vh`) |
| `COLOR_PROPS` | `Color` |
| `BORDER_PROPS` | `Dictionary` (width + color per side) |
| `FLOAT_PROPS` | `float` |

Add your property name to the appropriate constant. Properties whose values
are enumerable keywords belong in `PASSTHROUGH_PROPS`. Properties that hold
a numeric length belong in `SIZE_PROPS` (fixed integers) or
`DIMENSION_PROPS` (supports percent and viewport units).

For a completely custom type, add a branch at the bottom of
`GtmlCssParser._convert_property_value_static`:

```gdscript
if prop_name == "my-prop":
    return MyValues.parse_my_prop(value)
```

The parser stores custom properties (`--name`) as raw strings. Values
containing `var()` or `calc()` are deferred as `{_lazy, raw, prop}`
dictionaries and resolved by `GtmlCssEval` at compute-style time, so you
do not need to handle those in your converter.

### 2 — Style applier

Parsed property values land in the resolved style Dictionary passed to
element builders as `ctx.get_style.call(node)`. Read your key from that
Dictionary and apply it to the Control:

```gdscript
# Inside your element builder or a shared static helper
if style.has("my-prop"):
    control.some_property = style["my-prop"]
```

`GtmlStyles` contains shared applier helpers for borders, text,
decorations, shadows, and outlines. `GtmlDimensions.apply` handles all
sizing and flex properties centrally — you do not need to replicate that
logic.

---

## See also

- [HTML elements reference](../reference/html-elements.md)
- [CSS properties reference](../reference/css-properties.md)
