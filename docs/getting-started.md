# Getting Started with GTML

GTML (Godot Markup Language) lets you build Godot UI using HTML and CSS. This guide covers installation, basic setup, and core concepts.

## Installation

1. Copy the `addons/gtml/` folder to your project's `addons/` directory
2. Enable the plugin in **Project Settings → Plugins → GTML - Godot Markup Language**
3. The `GmlView` node type is now available in your scene tree

## Basic Setup

### 1. Add a GmlView Node

Add a `GmlView` node to your scene. This is the main component that renders HTML/CSS to Godot controls.

### 2. Create Your HTML File

Create an HTML file (e.g., `res://ui/menu.html`):

```html
<div class="menu">
    <h1>My Game</h1>
    <button @click="on_play">Play</button>
    <button @click="on_quit">Quit</button>
</div>
```

### 3. Create Your CSS File

Create a CSS file (e.g., `res://ui/menu.css`):

```css
.menu {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 32px;
    background-color: #1a1a2e;
}

h1 {
    font-size: 32px;
    color: #ffffff;
}

button {
    padding: 12px 24px;
    background-color: #00d4ff;
    border-radius: 4px;
    color: #000000;
}

button:hover {
    background-color: #00a8cc;
}
```

### 4. Configure the GmlView

In the Inspector, set:
- **Html Path**: `res://ui/menu.html`
- **Css Path**: `res://ui/menu.css`

The UI will automatically render in both the editor and at runtime.

## Event Handling

### Button Clicks

Use the `@click` attribute to specify a method name:

```html
<button @click="on_play">Play Game</button>
```

Connect to the `button_clicked` signal in your script:

```gdscript
extends Control

func _ready():
    $GmlView.button_clicked.connect(_on_button_clicked)

func _on_button_clicked(method_name: String):
    match method_name:
        "on_play":
            get_tree().change_scene_to_file("res://game.tscn")
        "on_quit":
            get_tree().quit()
```

### Link Clicks

Use the `href` attribute on anchors:

```html
<a href="settings">Settings</a>
```

```gdscript
func _ready():
    $GmlView.link_clicked.connect(_on_link_clicked)

func _on_link_clicked(href: String):
    print("Link clicked: ", href)
```

### Form Input Changes

```html
<input type="text" id="username" placeholder="Enter name">
```

```gdscript
func _ready():
    $GmlView.input_changed.connect(_on_input_changed)

func _on_input_changed(input_id: String, value: String):
    print("Input %s changed to: %s" % [input_id, value])
```

### Select Changes

```html
<select id="difficulty">
    <option value="easy">Easy</option>
    <option value="normal" selected>Normal</option>
    <option value="hard">Hard</option>
</select>
```

```gdscript
func _ready():
    $GmlView.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(select_id: String, value: String):
    print("Selection %s changed to: %s" % [select_id, value])
```

## Accessing Elements by ID

### Get the Inner Control

Use `get_element_by_id()` to access the actual Godot control (Label, Button, etc.):

```gdscript
var label = $GmlView.get_element_by_id("status-label")
label.text = "Connected!"
```

### Get the Wrapper

Use `get_wrapper_by_id()` to access the wrapper container (useful for visibility control):

```gdscript
var wrapper = $GmlView.get_wrapper_by_id("error-message")
wrapper.visible = true
```

## Live Reload

When `auto_reload_in_editor` is enabled (default), the GmlView automatically rebuilds when HTML or CSS files are modified. This allows you to see changes instantly in the editor.

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

## Signals Reference

| Signal | Parameters | Description |
|--------|------------|-------------|
| `button_clicked` | `method_name: String` | Emitted when a button with `@click` is pressed |
| `link_clicked` | `href: String` | Emitted when an anchor is clicked |
| `input_changed` | `input_id: String`, `value: String` | Emitted when input value changes |
| `selection_changed` | `select_id: String`, `value: String` | Emitted when select option changes |
| `form_submitted` | `form_data: Dictionary` | Emitted when a submit button is clicked |

## Example Files

Check out the example files in `addons/gtml/examples/`:
- `basic.html/css` - Simple menu example
- `all_elements.html/css` - Showcase of all HTML elements
- `css_features.html/css` - CSS property demonstrations
- `flex_layout.html/css` - Flexbox layout examples
- `transitions.html/css` - CSS transition animations

## Next Steps

- [HTML Elements](html-elements.md) - All supported tags and attributes
- [CSS Properties](css-properties.md) - Complete CSS reference
- [Layout & Flexbox](layout-and-flexbox.md) - Layout system guide
- [Forms & Inputs](forms-and-inputs.md) - Form element details
