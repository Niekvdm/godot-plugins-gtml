![GML Header](header.png)

# GML - Godot Markup Language

A Godot 4.x addon that allows you to build UI from HTML files with external CSS styling. Create game menus, HUDs, and UI panels using familiar web technologies.

## Features

- HTML-based UI structure
- External CSS styling with cascade support
- Live reload in editor
- SVG rendering support
- Form elements with signals
- Pseudo-class support (:hover, :active, :focus)
- Gradient backgrounds
- Custom font support

## Installation

1. Copy the `addons/gml/` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings → Plugins → GML - Godot Markup Language

## Usage

1. Add a `GmlView` node to your scene
2. Set the `Html Path` property to point to your `.html` file
3. Optionally set the `Css Path` property for styling
4. The UI will be built and displayed in both editor and runtime

### Event Handling

Use the `@click` attribute on buttons and anchors:

```html
<button @click="on_play">Play Game</button>
<a @click="on_settings">Settings</a>
```

Connect to signals in your script:

```gdscript
func _ready():
    $GmlView.button_clicked.connect(_on_button_clicked)
    $GmlView.link_clicked.connect(_on_link_clicked)
    $GmlView.input_changed.connect(_on_input_changed)
    $GmlView.selection_changed.connect(_on_selection_changed)

func _on_button_clicked(method_name: String):
    match method_name:
        "on_play":
            get_tree().change_scene_to_file("res://game.tscn")
        "on_quit":
            get_tree().quit()

func _on_link_clicked(href: String):
    print("Link clicked: ", href)

func _on_input_changed(input_id: String, value: String):
    print("Input %s changed to: %s" % [input_id, value])

func _on_selection_changed(select_id: String, value: String):
    print("Selection %s changed to: %s" % [select_id, value])
```

### Accessing Elements by ID

```gdscript
# Get the inner control (Label, Button, etc.)
var label = $GmlView.get_element_by_id("status-label")
label.text = "Connected!"

# Get the wrapper (for visibility control)
var wrapper = $GmlView.get_wrapper_by_id("error-message")
wrapper.visible = true
```

## Supported HTML Tags

### Container Elements

| Tag | Description | Godot Control |
|-----|-------------|---------------|
| `<div>` | Generic container | VBoxContainer / HBoxContainer |
| `<section>` | Section container | VBoxContainer / HBoxContainer |
| `<header>` | Header section | VBoxContainer / HBoxContainer |
| `<footer>` | Footer section | VBoxContainer / HBoxContainer |
| `<nav>` | Navigation section | VBoxContainer / HBoxContainer |
| `<main>` | Main content | VBoxContainer / HBoxContainer |
| `<article>` | Article section | VBoxContainer / HBoxContainer |
| `<aside>` | Sidebar content | VBoxContainer / HBoxContainer |
| `<form>` | Form container | VBoxContainer / HBoxContainer |

### Text Elements

| Tag | Description | Godot Control |
|-----|-------------|---------------|
| `<p>` | Paragraph | Label (autowrap) |
| `<span>` | Inline text | Label |
| `<h1>` - `<h6>` | Headings | Label (sized) |
| `<label>` | Form label | Label |
| `<strong>`, `<b>` | Bold text | Label (outline simulated) |
| `<em>`, `<i>` | Italic text | Label (metadata stored) |

### Interactive Elements

| Tag | Description | Godot Control |
|-----|-------------|---------------|
| `<button>` | Button | Button |
| `<a>` | Anchor/link | LinkButton |
| `<input>` | Form input | LineEdit / CheckBox / HSlider / Button |
| `<textarea>` | Multi-line input | TextEdit |
| `<select>` | Dropdown | OptionButton |
| `<option>` | Select option | (handled by select) |

### Media Elements

| Tag | Description | Godot Control |
|-----|-------------|---------------|
| `<img>` | Image | TextureRect |
| `<svg>` | Vector graphics | SvgDrawControl (custom) |

### List Elements

| Tag | Description | Godot Control |
|-----|-------------|---------------|
| `<ul>` | Unordered list | VBoxContainer |
| `<ol>` | Ordered list | VBoxContainer |
| `<li>` | List item | HBoxContainer |

### Other Elements

| Tag | Description | Godot Control |
|-----|-------------|---------------|
| `<br>` | Line break | Control (spacer) |
| `<hr>` | Horizontal rule | HSeparator |
| `<progress>` | Progress bar | ProgressBar |

## Supported HTML Attributes

### Global Attributes
- `id` - Sets the node name, enables `get_element_by_id()`
- `class` - For CSS class selectors

### Interactive Attributes
- `@click` - Event handler name (buttons and anchors)
- `href` - Link target (anchors)

### Image Attributes
- `src` - Image source path (`res://` paths)

### Input Attributes
- `type` - Input type: `text`, `password`, `email`, `number`, `checkbox`, `range`, `submit`
- `placeholder` - Placeholder text
- `value` - Initial value
- `checked` - Checkbox checked state
- `min`, `max`, `step` - Range input constraints
- `name` - Alternative to id for form identification

### Textarea Attributes
- `rows` - Number of visible rows
- `cols` - Number of visible columns
- `placeholder` - Placeholder text

### Select/Option Attributes
- `selected` - Pre-selected option
- `value` - Option value (defaults to text content)

### Progress Attributes
- `value` - Current value
- `max` - Maximum value (default: 100)

### SVG Attributes
- `viewBox` - SVG viewport (e.g., "0 0 24 24")
- `width`, `height` - SVG dimensions
- `stroke` - Stroke color
- `fill` - Fill color
- `stroke-width` - Stroke width

## Supported CSS Properties

### Layout

| Property | Values | Description |
|----------|--------|-------------|
| `display` | `flex`, `block`, `none` | Layout mode |
| `flex-direction` | `row`, `column` | Flex direction |
| `align-items` | `flex-start`, `center`, `flex-end`, `stretch` | Cross-axis alignment |
| `justify-content` | `flex-start`, `center`, `flex-end`, `space-between`, `space-around`, `space-evenly` | Main-axis alignment |
| `gap` | `Npx` | Spacing between children (ignored with space-* justify) |
| `flex-grow` | `N` | Flex grow factor (axis-aware) |
| `flex-shrink` | `0`, `N` | Flex shrink factor (0 = prevent shrinking) |

### Dimensions

| Property | Values | Description |
|----------|--------|-------------|
| `width` | `Npx`, `N%` | Element width |
| `height` | `Npx`, `N%` | Element height |
| `min-width` | `Npx`, `N%` | Minimum width |
| `max-width` | `Npx`, `N%` | Maximum width |
| `min-height` | `Npx`, `N%` | Minimum height |
| `max-height` | `Npx`, `N%` | Maximum height |

### Spacing

| Property | Values | Description |
|----------|--------|-------------|
| `margin` | `Npx` | All sides margin |
| `margin-top` | `Npx` | Top margin |
| `margin-right` | `Npx` | Right margin |
| `margin-bottom` | `Npx` | Bottom margin |
| `margin-left` | `Npx` | Left margin |
| `padding` | `Npx` | All sides padding |
| `padding-top` | `Npx` | Top padding |
| `padding-right` | `Npx` | Right padding |
| `padding-bottom` | `Npx` | Bottom padding |
| `padding-left` | `Npx` | Left padding |

### Background

| Property | Values | Description |
|----------|--------|-------------|
| `background-color` | `#RRGGBB`, `#RGB`, `rgb()`, `rgba()`, color names | Solid background |
| `background` | `linear-gradient()`, `radial-gradient()`, `url()` | Complex backgrounds |
| `background-image` | `linear-gradient()`, `radial-gradient()`, `url()` | Background image/gradient |

**Gradient syntax:**
```css
/* Linear gradient */
background: linear-gradient(to right, #ff0000, #0000ff);
background: linear-gradient(45deg, red, blue);
background: linear-gradient(to bottom, #000 0%, #333 50%, #000 100%);

/* Radial gradient */
background: radial-gradient(circle, #ffffff, #000000);
```

### Border

| Property | Values | Description |
|----------|--------|-------------|
| `border` | `Npx solid #color` | Border shorthand |
| `border-width` | `Npx` | Border width (all sides) |
| `border-color` | `#RRGGBB`, color names | Border color |
| `border-top` | `Npx solid #color` | Top border |
| `border-right` | `Npx solid #color` | Right border |
| `border-bottom` | `Npx solid #color` | Bottom border |
| `border-left` | `Npx solid #color` | Left border |
| `border-top-width` | `Npx` | Top border width |
| `border-right-width` | `Npx` | Right border width |
| `border-bottom-width` | `Npx` | Bottom border width |
| `border-left-width` | `Npx` | Left border width |
| `border-radius` | `Npx` | Corner radius (all corners) |
| `border-top-left-radius` | `Npx` | Top-left corner radius |
| `border-top-right-radius` | `Npx` | Top-right corner radius |
| `border-bottom-left-radius` | `Npx` | Bottom-left corner radius |
| `border-bottom-right-radius` | `Npx` | Bottom-right corner radius |

### Typography

| Property | Values | Description |
|----------|--------|-------------|
| `color` | `#RRGGBB`, `rgb()`, `rgba()`, color names | Text color |
| `font-size` | `Npx` | Font size |
| `font-family` | `'Font Name'` | Font family (see Font Configuration) |
| `font-weight` | `100`-`950`, `bold`, `normal`, etc. | Font weight |
| `letter-spacing` | `Npx`, `Nem` | Letter spacing |
| `text-align` | `left`, `center`, `right`, `justify` | Text alignment |

**Font weight keywords:** `thin`, `light`, `normal`, `medium`, `semibold`, `bold`, `extrabold`, `black`

### Effects

| Property | Values | Description |
|----------|--------|-------------|
| `box-shadow` | `Xpx Ypx blur spread color` | Box shadow |
| `opacity` | `0` - `1` | Element opacity |

**Box shadow example:**
```css
box-shadow: 4px 4px 8px rgba(0, 0, 0, 0.5);
box-shadow: 0 2px 4px 2px #000000;
```

### Form Element Styling

Form elements (`input`, `textarea`, `select`) support background and border styling:

| Property | Support | Description |
|----------|---------|-------------|
| `background-color` | ✅ Full | Input background color |
| `border` | ✅ Full | Border shorthand |
| `border-radius` | ✅ Full | Corner radius |
| `border-color` | ✅ Full | Border color |
| `border-width` | ✅ Full | Border width |
| `color` | ✅ Full | Text/font color |
| `font-size` | ✅ Full | Text size |
| `font-family` | ✅ Full | Custom font |
| `padding` | ✅ Full | Internal spacing |
| `:focus` | ✅ Pseudo | Focus state styling |

**Example:**
```css
input, textarea, select {
    background-color: #1a1a28;
    border: 1px solid #3a3a5e;
    border-radius: 6px;
    padding: 10px;
    color: #ddddee;
    font-size: 14px;
}

input:focus, textarea:focus, select:focus {
    border-color: #00d4ff;
    background-color: #1e1e2e;
}
```

**Slider styling:** Range inputs (`<input type="range">`) use `background-color` for the track and `color` for the filled area.

### Overflow & Visibility

| Property | Values | Description |
|----------|--------|-------------|
| `overflow` | `visible`, `hidden`, `scroll`, `auto` | Content overflow |
| `overflow-x` | `visible`, `hidden`, `scroll`, `auto` | Horizontal overflow |
| `overflow-y` | `visible`, `hidden`, `scroll`, `auto` | Vertical overflow |
| `visibility` | `visible`, `hidden` | Element visibility |

## CSS Selectors

### Supported Selectors

- **Tag selector:** `div`, `p`, `button`
- **Class selector:** `.classname`
- **ID selector:** `#idname`
- **Comma-separated:** `h1, h2, h3 { ... }`

### Pseudo-classes

**Buttons:**
- `:hover` - Mouse hover state
- `:active` - Pressed state
- `:focus` - Focused state
- `:disabled` - Disabled state

**Form Elements (input, textarea, select):**
- `:focus` - Focused state (when input has keyboard focus)

```css
button {
    background-color: #333;
    color: white;
}

button:hover {
    background-color: #555;
}

button:active {
    background-color: #222;
}
```

### Cascade Priority

1. Tag selectors (lowest)
2. Class selectors
3. ID selectors (highest)

## SVG Support

GML supports inline SVG with rendering to Godot's drawing API.

### Supported SVG Elements

| Element | Attributes |
|---------|------------|
| `<polygon>` | `points`, `fill`, `stroke`, `stroke-width` |
| `<polyline>` | `points`, `stroke`, `stroke-width` |
| `<line>` | `x1`, `y1`, `x2`, `y2`, `stroke`, `stroke-width` |
| `<circle>` | `cx`, `cy`, `r`, `fill`, `stroke`, `stroke-width` |
| `<ellipse>` | `cx`, `cy`, `rx`, `ry`, `fill`, `stroke`, `stroke-width` |
| `<rect>` | `x`, `y`, `width`, `height`, `rx`, `ry`, `fill`, `stroke`, `stroke-width` |
| `<path>` | `d`, `fill`, `stroke`, `stroke-width` |
| `<g>` | Groups child elements with inherited styles |

### SVG Path Commands

- `M`, `m` - Move to
- `L`, `l` - Line to
- `H`, `h` - Horizontal line
- `V`, `v` - Vertical line
- `Z`, `z` - Close path
- `C`, `c` - Cubic bezier (simplified to endpoint)
- `S`, `s` - Smooth cubic bezier (simplified)
- `Q`, `q` - Quadratic bezier (simplified)
- `T`, `t` - Smooth quadratic bezier (simplified)

### SVG Example

```html
<svg viewBox="0 0 24 24">
    <polygon points="12,2 22,8.5 22,15.5 12,22 2,15.5 2,8.5"
             stroke-width="1.5" fill="none" />
    <circle cx="12" cy="12" r="4" fill="#00d4ff" />
</svg>
```

SVG inherits the `color` CSS property for stroke color.

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `button_clicked` | `method_name: String` | Emitted when a button with `@click` is pressed |
| `link_clicked` | `href: String` | Emitted when an anchor is clicked |
| `input_changed` | `input_id: String`, `value: String` | Emitted when input value changes |
| `selection_changed` | `select_id: String`, `value: String` | Emitted when select option changes |
| `form_submitted` | `form_data: Dictionary` | Emitted when a submit button is clicked |

## Font Configuration

To use custom fonts, configure the `fonts` dictionary in the GmlView inspector:

```gdscript
# In the Inspector, set the fonts dictionary:
fonts = {
    "Orbitron": preload("res://assets/fonts/Orbitron-Regular.ttf"),
    "Rajdhani": preload("res://assets/fonts/Rajdhani-Regular.ttf")
}
```

Then reference in CSS:

```css
h1 {
    font-family: 'Orbitron';
    font-size: 32px;
}

p {
    font-family: 'Rajdhani';
    font-size: 16px;
}
```

## Tag Defaults

Configure default values in the GmlView inspector:

| Property | Default | Description |
|----------|---------|-------------|
| `h1_font_size` | 32 | H1 heading size |
| `h2_font_size` | 24 | H2 heading size |
| `h3_font_size` | 20 | H3 heading size |
| `p_font_size` | 16 | Paragraph size |
| `default_font_color` | White | Default text color |
| `default_gap` | 8 | Default gap between elements |
| `default_margin` | 0 | Default margin |
| `default_padding` | 0 | Default padding |

CSS rules override these defaults.

## Live Reload

When `auto_reload_in_editor` is enabled (default), the GmlView automatically rebuilds when HTML or CSS files are modified.

## Example

**menu.html:**
```html
<div class="menu">
    <header class="header">
        <h1>GML</h1>
        <p class="tagline">Godot Markup Language</p>
    </header>

    <div class="buttons">
        <button @click="on_play">Home</button>
        <button @click="on_settings">Options</button>
        <button @click="on_quit">Quit</button>
    </div>

    <footer class="footer">
        <div class="status">
            <div class="status-dot"></div>
            <span>Online</span>
        </div>
    </footer>
</div>
```

**menu.css:**
```css
.menu {
    display: flex;
    flex-direction: column;
    width: 80%;
    max-width: 400px;
    padding: 40px;
    gap: 24px;
    background-color: rgba(10, 14, 20, 0.95);
    border: 1px solid #28354d;
    border-radius: 8px;
}

.header {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
}

h1 {
    font-family: 'Orbitron';
    font-size: 36px;
    font-weight: 900;
    color: #e8eef4;
    letter-spacing: 2px;
}

.tagline {
    font-family: 'Rajdhani';
    font-size: 14px;
    color: #6b7d93;
}

.buttons {
    display: flex;
    flex-direction: column;
    gap: 12px;
}

button {
    font-family: 'Orbitron';
    font-size: 14px;
    padding: 16px;
    background-color: #00d4ff;
    border: none;
    border-radius: 4px;
    color: #030508;
    font-weight: 600;
}

button:hover {
    background-color: #00a8cc;
}

.footer {
    display: flex;
    justify-content: center;
    padding-top: 16px;
    border-top: 1px solid #28354d;
}

.status {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 8px;
}

.status-dot {
    width: 8px;
    height: 8px;
    background-color: #00ff88;
    border-radius: 4px;
}
```

## Extending GML

GML is designed with a modular architecture that makes it easy to add new CSS properties, HTML elements, or customize existing behavior.

### Project Structure

```
addons/gml/src/
├── GmlView.gd                    # Main component (signals, API)
├── css/
│   ├── GmlCssParser.gd           # CSS parsing and dispatch
│   ├── GmlStyleResolver.gd       # Resolves CSS rules to nodes
│   └── values/                   # CSS value parsers
│       ├── GmlColorValues.gd     # Colors (hex, rgb, rgba, named)
│       ├── GmlDimensionValues.gd # Dimensions (px, %, auto)
│       ├── GmlFontValues.gd      # Font properties
│       ├── GmlBackgroundValues.gd # Gradients, images
│       └── GmlBorderValues.gd    # Borders, box-shadow
├── html_parser/
│   ├── GmlHtmlParser.gd          # HTML tokenizer/parser
│   └── GmlNode.gd                # DOM node class
└── html_renderer/
    ├── GmlRenderer.gd            # Main renderer (dispatch)
    ├── GmlStyles.gd              # Shared style utilities
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

### Adding a New CSS Property

1. **Identify the property category** - Is it a color, dimension, font, background, or border property?

2. **Add the parser** in the appropriate value module:

```gdscript
# Example: Adding 'text-transform' to GmlFontValues.gd
static func parse_text_transform(value: String) -> String:
    value = value.strip_edges().to_lower()
    match value:
        "uppercase", "lowercase", "capitalize", "none":
            return value
        _:
            return "none"
```

3. **Register the property** in `GmlCssParser.gd`:

```gdscript
# Add to the appropriate constant array at the top
const PASSTHROUGH_PROPS = [
    "display", "flex-direction", "text-transform",  # Added here
    # ...
]

# Or add a custom handler in _convert_property_value():
func _convert_property_value(prop_name: String, value: String):
    # ...
    if prop_name == "text-transform":
        return GmlFontValues.parse_text_transform(value)
```

4. **Apply the property** in the relevant element builder or `GmlStyles.gd`:

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

### Adding a New HTML Element

1. **Create the element builder** or add to an existing module:

```gdscript
# In GmlMediaElements.gd or new file GmlCustomElements.gd
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

    # Apply styles
    if style.has("width"):
        var dim = style["width"]
        if dim is Dictionary and dim.get("unit", "") == "px":
            video_player.custom_minimum_size.x = dim["value"]

    return video_player
```

2. **Register the element** in `GmlRenderer.gd`:

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

### The Context Dictionary

Element builders receive a `ctx` dictionary with these callables and data:

| Key | Type | Description |
|-----|------|-------------|
| `styles` | Dictionary | All resolved styles (node → style dict) |
| `defaults` | Dictionary | Default values from GmlView |
| `gml_view` | GmlView | Reference to the GmlView node |
| `build_node` | Callable | Recursively build child nodes |
| `get_style` | Callable | Get resolved style for a node |
| `wrap_with_margin_padding` | Callable | Wrap control with margin/padding/bg |

**Usage in element builders:**

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

### Adding Style Utilities

Add reusable style functions to `GmlStyles.gd`:

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
```

Then use in element builders:

```gdscript
GmlStyles.apply_cursor_style(button, style)
```

### Extending SVG Support

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

You'll also need to implement `add_text()` in `SvgDrawControl.gd`.

### Best Practices

1. **Use static functions** - Element builders and value parsers are stateless utilities
2. **Return `{"control": wrapped, "inner": inner}`** - This allows proper ID registration and wrapper access
3. **Use `ctx.wrap_with_margin_padding()`** - Handles padding, margin, background, border, and scroll
4. **Check for nil/empty** - Always validate attributes and style values
5. **Use weakref for signals** - Prevents memory leaks in lambda closures:

```gdscript
if gml_view != null:
    var view_ref = weakref(gml_view)
    button.pressed.connect(func():
        var view = view_ref.get_ref()
        if view != null:
            view.button_clicked.emit(method_name)
    )
```

## Limitations

### CSS
- No inline `<style>` tags - CSS must be in external files
- No descendant selectors (`div p`) or sibling selectors (`div + p`)
- No CSS shorthand for multi-value properties (`margin: 10px 20px` not supported)
- CSS units limited to `px`, `%`, and `em` (letter-spacing only)
- No CSS animations or transitions
- No CSS variables (`--custom-property`)
- Pseudo-classes: `:hover`, `:active`, `:disabled` work on buttons; `:focus` works on buttons and form elements

### SVG
- Bezier curves (C, S, Q, T) are simplified to straight line endpoints
- Arc command (A) not supported
- No SVG transforms, masks, or filters

### Typography
- Font weight is simulated using outline - requires custom fonts for true weights
- Letter spacing is simulated with Unicode space characters
- No italic support without custom italic font files

### Layout
- ScrollContainer requires explicit height to enable scrolling
- Images must use `res://` paths
- No CSS Grid layout

### Colors
Named colors supported: `white`, `black`, `red`, `green`, `blue`, `yellow`, `cyan`, `magenta`, `gray`/`grey`, `transparent`, `orange`, `purple`, `pink`

## License

MIT License
