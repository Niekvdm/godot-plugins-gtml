# Extending GTML

GTML is designed with a modular architecture that makes it easy to add new CSS properties, HTML elements, or customize existing behavior.

## Project Structure

```
addons/gtml/src/
├── GmlView.gd                    # Main component (signals, API)
├── css/
│   ├── GmlCssParser.gd           # CSS parsing and dispatch
│   ├── GmlStyleResolver.gd       # Resolves CSS rules to nodes
│   └── values/                   # CSS value parsers
│       ├── GmlColorValues.gd     # Colors (hex, rgb, rgba, named)
│       ├── GmlDimensionValues.gd # Dimensions (px, %, auto)
│       ├── GmlFontValues.gd      # Font properties
│       ├── GmlBackgroundValues.gd # Gradients, images
│       ├── GmlBorderValues.gd    # Borders, box-shadow
│       └── GmlTransitionValues.gd # Transitions
├── html_parser/
│   ├── GmlHtmlParser.gd          # HTML tokenizer/parser
│   └── GmlNode.gd                # DOM node class
└── html_renderer/
    ├── GmlRenderer.gd            # Main renderer (dispatch)
    ├── GmlStyles.gd              # Shared style utilities
    ├── GmlTransitionManager.gd   # CSS transitions
    ├── SvgDrawControl.gd         # SVG drawing control
    └── elements/                 # Element builders
        ├── GmlContainerElements.gd
        ├── GmlTextElements.gd
        ├── GmlButtonElements.gd
        ├── GmlInputElements.gd
        ├── GmlMediaElements.gd
        ├── GmlListElements.gd
        └── GmlAnchorElements.gd
```

## Adding a New CSS Property

### Step 1: Identify the Property Category

CSS properties fall into these categories:

| Category | Module | Example Properties |
|----------|--------|-------------------|
| Passthrough | Direct string | `display`, `flex-direction`, `text-align` |
| Size | Integer pixels | `gap`, `padding-*`, `margin-*`, `font-size` |
| Dimension | `{value, unit}` dict | `width`, `height`, `min-width`, `max-width` |
| Color | Godot Color | `color`, `background-color`, `border-color` |
| Float | Float number | `opacity`, `flex-grow`, `flex-shrink` |
| Border | Complex dict | `border`, `border-top`, etc. |
| Transition | Timing dict | `transition`, `transition-duration` |
| Custom | Special handling | `background`, `font-family`, `box-shadow` |

### Step 2: Add the Parser

For simple passthrough properties, add to the constant array in `GmlCssParser.gd`:

```gdscript
# In GmlCssParser.gd
const PASSTHROUGH_PROPS = [
    "display", "flex-direction", "align-items", "justify-content",
    "text-align", "overflow", "visibility", "flex-wrap", "align-self",
    "cursor", "list-style-type", "text-transform", "white-space",
    "text-overflow",
    # Add your new property here:
    "my-new-property",
]
```

For properties needing custom parsing, add a value parser:

```gdscript
# In css/values/GmlFontValues.gd
static func parse_text_transform(value: String) -> String:
    value = value.strip_edges().to_lower()
    match value:
        "uppercase", "lowercase", "capitalize", "none":
            return value
        _:
            return "none"
```

Then register in `GmlCssParser._convert_property_value()`:

```gdscript
func _convert_property_value(prop_name: String, value: String):
    # ... existing code ...

    if prop_name == "text-transform":
        return GmlFontValues.parse_text_transform(value)

    # ... rest of function ...
```

### Step 3: Apply the Property

Apply in the relevant element builder or `GmlStyles.gd`:

```gdscript
# In GmlStyles.gd or element builder
static func apply_text_styles(label: Label, style: Dictionary, defaults: Dictionary) -> void:
    # ... existing code ...

    # Apply text-transform
    if style.has("text-transform"):
        match style["text-transform"]:
            "uppercase":
                label.text = label.text.to_upper()
            "lowercase":
                label.text = label.text.to_lower()
            "capitalize":
                label.text = label.text.capitalize()
```

### Complete Example: Adding `text-transform`

**1. Add to GmlCssParser.gd:**

```gdscript
const PASSTHROUGH_PROPS = [
    # ... existing ...
    "text-transform",
]
```

**2. Apply in GmlTextElements.gd:**

```gdscript
static func _build_text_inner(node, ctx: Dictionary, default_size: int, autowrap: bool) -> Control:
    # ... existing code ...

    if style.has("text-transform"):
        match style["text-transform"]:
            "uppercase":
                text = text.to_upper()
            "lowercase":
                text = text.to_lower()
            "capitalize":
                text = text.capitalize()

    label.text = text
    # ... rest of function ...
```

## Adding a New HTML Element

### Step 1: Create the Element Builder

Add to an existing module or create a new file:

```gdscript
# In html_renderer/elements/GmlCustomElements.gd
class_name GmlCustomElements
extends RefCounted

## Build a custom <video> element
static func build_video(node, ctx: Dictionary) -> Dictionary:
    var inner = _build_video_inner(node, ctx)
    var style = ctx.get_style.call(node)
    var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
    return {"control": wrapped, "inner": inner}

static func _build_video_inner(node, ctx: Dictionary) -> Control:
    var style = ctx.get_style.call(node)
    var defaults: Dictionary = ctx.defaults

    # Create your Godot control
    var video_player := VideoStreamPlayer.new()

    # Get attributes
    var src = node.get_attr("src", "")
    if not src.is_empty() and ResourceLoader.exists(src):
        video_player.stream = load(src)

    var autoplay = node.has_attr("autoplay")
    video_player.autoplay = autoplay

    # Apply dimension styles
    if style.has("width"):
        var dim = style["width"]
        if dim is Dictionary and dim.get("unit", "") == "px":
            video_player.custom_minimum_size.x = dim["value"]

    if style.has("height"):
        var dim = style["height"]
        if dim is Dictionary and dim.get("unit", "") == "px":
            video_player.custom_minimum_size.y = dim["value"]

    return video_player
```

### Step 2: Register in GmlRenderer.gd

```gdscript
func _build_node(node) -> Control:
    # ... existing code ...

    match node.tag:
        # ... existing cases ...

        # Add your new element
        "video":
            result = GmlCustomElements.build_video(node, ctx)

        # ... rest of match ...
```

### Step 3: Add to Self-Closing Tags (if applicable)

In `GmlHtmlParser.gd`:

```gdscript
const SELF_CLOSING_TAGS = [
    "img", "br", "hr", "input", "meta", "link",
    # SVG elements
    "circle", "ellipse", "line", "path", "polygon", "polyline", "rect", "use",
    # Add if self-closing:
    "video",
]
```

## The Context Dictionary

Element builders receive a `ctx` dictionary with utilities and data:

| Key | Type | Description |
|-----|------|-------------|
| `styles` | Dictionary | All resolved styles (node → style dict) |
| `defaults` | Dictionary | Default values from GmlView |
| `gml_view` | GmlView | Reference to the GmlView node |
| `build_node` | Callable | Recursively build child nodes |
| `get_style` | Callable | Get resolved style for a node |
| `wrap_with_margin_padding` | Callable | Wrap control with margin/padding/bg |
| `transition_manager` | GmlTransitionManager | Transition animator |

### Usage in Element Builders

```gdscript
static func build_my_element(node, ctx: Dictionary) -> Dictionary:
    var style = ctx.get_style.call(node)          # Get this node's style
    var defaults = ctx.defaults                    # Access defaults
    var gml_view = ctx.gml_view                   # Access GmlView

    var container := VBoxContainer.new()

    # Build children using the context's build_node callable
    for child in node.children:
        var child_control = ctx.build_node.call(child)
        if child_control != null:
            container.add_child(child_control)

    # Wrap with margin/padding/background
    var wrapped = ctx.wrap_with_margin_padding.call(container, style)

    return {"control": wrapped, "inner": container}
```

## Element Builder Return Format

All builders must return a dictionary with two keys:

```gdscript
return {
    "control": wrapped,  # Outer wrapper (with margin/padding/bg)
    "inner": inner       # Inner content control (for ID registration)
}
```

This allows:
- The wrapper to have margin, padding, background
- The inner control to be registered by ID
- Access to both via `get_element_by_id()` and `get_wrapper_by_id()`

## Adding Style Utilities

Add reusable functions to `GmlStyles.gd`:

```gdscript
# In GmlStyles.gd
static func apply_cursor_style(control: Control, style: Dictionary) -> void:
    if style.has("cursor"):
        match style["cursor"]:
            "pointer":
                control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            "not-allowed":
                control.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
            "text":
                control.mouse_default_cursor_shape = Control.CURSOR_IBEAM
            "move":
                control.mouse_default_cursor_shape = Control.CURSOR_MOVE
            "grab":
                control.mouse_default_cursor_shape = Control.CURSOR_OPEN_HAND
            "grabbing":
                control.mouse_default_cursor_shape = Control.CURSOR_DRAG
```

Then use in element builders:

```gdscript
GmlStyles.apply_cursor_style(button, style)
```

## Extending SVG Support

Add new SVG elements in `GmlMediaElements._parse_svg_element()`:

```gdscript
static func _parse_svg_element(svg_control, node, parent_stroke, parent_fill, parent_stroke_width) -> void:
    # ... existing code ...

    match node.tag:
        # ... existing cases ...

        "text":
            var x := float(node.get_attr("x", "0"))
            var y := float(node.get_attr("y", "0"))
            var text_content := node.get_text_content()
            svg_control.add_text(Vector2(x, y), text_content, fill)
```

You'll also need to implement `add_text()` in `SvgDrawControl.gd`:

```gdscript
# In SvgDrawControl.gd
var _texts: Array = []

func add_text(position: Vector2, text: String, color: Color) -> void:
    _texts.append({
        "position": position,
        "text": text,
        "color": color
    })
    queue_redraw()

func _draw() -> void:
    # ... existing drawing code ...

    # Draw texts
    for t in _texts:
        draw_string(get_theme_default_font(), t.position, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, t.color)
```

## Best Practices

### 1. Use Static Functions

Element builders and value parsers should be stateless utilities:

```gdscript
# Good - static utility
static func build_element(node, ctx: Dictionary) -> Dictionary:
    # ...

# Avoid - instance methods with state
```

### 2. Return Proper Structure

Always return `{"control": wrapped, "inner": inner}`:

```gdscript
static func build_element(node, ctx: Dictionary) -> Dictionary:
    var inner = _build_inner(node, ctx)
    var style = ctx.get_style.call(node)
    var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
    return {"control": wrapped, "inner": inner}
```

### 3. Use WeakRef for Signals

Prevent memory leaks in lambda closures:

```gdscript
if gml_view != null:
    var view_ref = weakref(gml_view)
    button.pressed.connect(func():
        var view = view_ref.get_ref()
        if view != null:
            view.button_clicked.emit(method_name)
    )
```

### 4. Validate Inputs

Always check for nil/empty values:

```gdscript
var src = node.get_attr("src", "")
if not src.is_empty() and ResourceLoader.exists(src):
    texture_rect.texture = load(src)
```

### 5. Follow Existing Patterns

Look at existing element builders for patterns:

- Container elements → `GmlContainerElements.gd`
- Text elements → `GmlTextElements.gd`
- Interactive elements → `GmlButtonElements.gd`, `GmlInputElements.gd`

## See Also

- [CSS Properties](css-properties.md) - Existing properties
- [HTML Elements](html-elements.md) - Existing elements
- [Limitations](limitations.md) - Known limitations
