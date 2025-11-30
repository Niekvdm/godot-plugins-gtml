# HTML Elements

GTML supports a variety of HTML elements that map to Godot controls. This reference covers all supported tags and their attributes.

## Container Elements

Container elements create layout structures using Godot's Container nodes.

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

Container direction is determined by CSS `flex-direction`:
- `flex-direction: column` → VBoxContainer (default)
- `flex-direction: row` → HBoxContainer

### Example

```html
<div class="card">
    <header class="card-header">
        <h2>Card Title</h2>
    </header>
    <section class="card-body">
        <p>Card content goes here.</p>
    </section>
    <footer class="card-footer">
        <button @click="on_action">Action</button>
    </footer>
</div>
```

```css
.card {
    display: flex;
    flex-direction: column;
    padding: 16px;
    gap: 12px;
    background-color: #2a2a3e;
    border-radius: 8px;
}

.card-header {
    border-bottom: 1px solid #3a3a5e;
    padding-bottom: 12px;
}

.card-footer {
    display: flex;
    flex-direction: row;
    justify-content: flex-end;
}
```

## Text Elements

Text elements display text content using Godot's Label control.

| Tag | Description | Godot Control | Default Size |
|-----|-------------|---------------|--------------|
| `<p>` | Paragraph | Label (autowrap) | 16px |
| `<span>` | Inline text | Label | 16px |
| `<h1>` | Heading 1 | Label | 32px |
| `<h2>` | Heading 2 | Label | 24px |
| `<h3>` | Heading 3 | Label | 20px |
| `<h4>` | Heading 4 | Label | 16px |
| `<h5>` | Heading 5 | Label | 13px |
| `<h6>` | Heading 6 | Label | 11px |
| `<label>` | Form label | Label | 16px |
| `<strong>`, `<b>` | Bold text | Label (outline) | inherited |
| `<em>`, `<i>` | Italic text | Label | inherited |

### Example

```html
<h1>Main Title</h1>
<h2>Subtitle</h2>
<p>This is a paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
<span class="badge">New</span>
```

## Interactive Elements

### Button

Buttons emit the `button_clicked` signal when pressed.

```html
<button @click="on_play">Play Game</button>
<button @click="on_quit" class="danger">Quit</button>
<button disabled>Disabled</button>
```

**Attributes:**
- `@click` - Method name emitted with the `button_clicked` signal
- `disabled` - Disables the button
- `type` - Button type: `button`, `submit`, `reset`

**Godot Control:** Button

### Anchor (Link)

Links emit the `link_clicked` signal.

```html
<a href="settings">Settings</a>
<a @click="on_help">Help</a>
<a href="https://example.com" target="_blank">External Link</a>
```

**Attributes:**
- `href` - Link target (emitted with `link_clicked` signal)
- `@click` - Method name for button-like behavior
- `target` - Link target behavior

**Godot Control:** LinkButton

### Input

Form inputs with various types. See [Forms & Inputs](forms-and-inputs.md) for details.

```html
<input type="text" id="username" placeholder="Username">
<input type="password" id="password" placeholder="Password">
<input type="checkbox" id="remember" checked>
<input type="range" id="volume" min="0" max="100" value="50">
```

**Godot Controls:** LineEdit, CheckBox, HSlider, Button (for submit)

### Textarea

Multi-line text input.

```html
<textarea id="description" rows="5" cols="40" placeholder="Enter description..."></textarea>
```

**Attributes:**
- `id` / `name` - Element identifier
- `rows` - Number of visible rows
- `cols` - Number of visible columns
- `placeholder` - Placeholder text

**Godot Control:** TextEdit

### Select

Dropdown selection.

```html
<select id="difficulty">
    <option value="easy">Easy</option>
    <option value="normal" selected>Normal</option>
    <option value="hard">Hard</option>
</select>
```

**Attributes:**
- `id` / `name` - Element identifier
- `selected` (on option) - Pre-selected option
- `value` (on option) - Option value (defaults to text content)

**Godot Control:** OptionButton

## Media Elements

### Image

Displays images from resource paths.

```html
<img src="res://assets/logo.png">
<img src="res://icons/star.png" class="icon">
```

**Attributes:**
- `src` - Image source path (must use `res://` format)

**Godot Control:** TextureRect

### SVG

Inline SVG graphics. See [SVG Support](svg-support.md) for details.

```html
<svg viewBox="0 0 24 24" width="24" height="24">
    <circle cx="12" cy="12" r="10" fill="#00d4ff" />
</svg>
```

**Attributes:**
- `viewBox` - SVG viewport definition
- `width`, `height` - SVG dimensions
- `stroke`, `fill`, `stroke-width` - Styling

**Godot Control:** SvgDrawControl (custom)

### Progress Bar

```html
<progress value="75" max="100"></progress>
```

**Attributes:**
- `value` - Current value (default: 0)
- `max` - Maximum value (default: 100)

**Godot Control:** ProgressBar

### Line Break

```html
<p>Line one<br>Line two</p>
```

**Godot Control:** Control (8px spacer)

### Horizontal Rule

```html
<hr>
```

**Godot Control:** HSeparator

## List Elements

### Unordered List

```html
<ul>
    <li>First item</li>
    <li>Second item</li>
    <li>Third item</li>
</ul>
```

**CSS `list-style-type` values:** `disc` (default), `circle`, `square`, `none`

### Ordered List

```html
<ol>
    <li>First step</li>
    <li>Second step</li>
    <li>Third step</li>
</ol>
```

**CSS `list-style-type` values:** `decimal` (default), `decimal-leading-zero`, `lower-alpha`, `upper-alpha`, `lower-roman`, `upper-roman`

**Godot Controls:** VBoxContainer (list), HBoxContainer (item)

## Global Attributes

These attributes work on all elements:

| Attribute | Description |
|-----------|-------------|
| `id` | Unique identifier for `get_element_by_id()` |
| `class` | CSS class names (space-separated) |

## Complex Button Content

Buttons can contain child elements for rich content:

```html
<button @click="on_settings" class="icon-button">
    <svg viewBox="0 0 24 24" width="16" height="16">
        <circle cx="12" cy="12" r="3" fill="currentColor" />
    </svg>
    <span>Settings</span>
</button>
```

```css
.icon-button {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 8px;
}
```

## See Also

- [CSS Properties](css-properties.md) - Style these elements
- [Forms & Inputs](forms-and-inputs.md) - Detailed form element guide
- [SVG Support](svg-support.md) - SVG elements and path commands
- [Layout & Flexbox](layout-and-flexbox.md) - Container layout options
