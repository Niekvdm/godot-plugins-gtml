# Limitations

This document lists known limitations of GTML and suggested workarounds.

## CSS Limitations

### No Inline Styles

CSS must be in external files. Inline `<style>` tags and `style` attributes are not supported.

```html
<!-- NOT supported -->
<div style="color: red;">Text</div>
<style>div { color: red; }</style>

<!-- Supported -->
<div class="red-text">Text</div>
```

**Workaround:** Use external CSS files and classes.

### No Descendant Selectors

Complex selectors like descendant, child, or sibling selectors are not supported.

```css
/* NOT supported */
div p { }           /* Descendant */
div > p { }         /* Child */
h1 + p { }          /* Adjacent sibling */
h1 ~ p { }          /* General sibling */
ul li a { }         /* Nested descendant */

/* Supported */
.card-text { }      /* Use classes */
#specific-item { }  /* Use IDs */
```

**Workaround:** Use unique class names or IDs on target elements.

### No Multi-Value Shorthand

Properties like `margin` and `padding` only accept single values.

```css
/* NOT supported */
margin: 10px 20px;           /* Top/bottom, left/right */
margin: 10px 20px 30px;      /* Top, left/right, bottom */
margin: 10px 20px 30px 40px; /* Top, right, bottom, left */
padding: 8px 16px;

/* Supported */
margin: 10px;                /* All sides same */
margin-top: 10px;
margin-right: 20px;
margin-bottom: 30px;
margin-left: 40px;
```

**Workaround:** Use individual side properties.

### Limited CSS Units

Only these units are supported:

- `px` - Pixels (most common)
- `%` - Percentage (for dimensions)
- `em` - Only for `letter-spacing`

```css
/* NOT supported */
width: 10rem;
font-size: 1.5em;
margin: 2vh;
height: calc(100% - 50px);

/* Supported */
width: 160px;
font-size: 24px;
margin: 20px;
```

### No CSS Variables

Custom properties are not supported.

```css
/* NOT supported */
:root {
    --primary-color: #00d4ff;
}
button {
    background-color: var(--primary-color);
}

/* Supported - use direct values */
button {
    background-color: #00d4ff;
}
```

### No CSS Animations

Only transitions are supported. Keyframe animations are not available.

```css
/* NOT supported */
@keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
}
.animate {
    animation: fadeIn 1s ease;
}

/* Supported - use transitions */
.fade {
    opacity: 0;
    transition: opacity 300ms ease;
}
.fade:hover {
    opacity: 1;
}
```

### No !important

The `!important` flag is not supported.

```css
/* NOT supported */
.override {
    color: red !important;
}

/* Workaround - use higher specificity */
#specific-element {
    color: red;  /* ID has highest priority */
}
```

### No Attribute Selectors

```css
/* NOT supported */
[type="text"] { }
[disabled] { }
[data-custom="value"] { }

/* Workaround - use classes */
.text-input { }
.disabled { }
.custom-value { }
```

### No :nth-child Selectors

```css
/* NOT supported */
li:nth-child(odd) { }
li:first-child { }
li:last-child { }
li:nth-of-type(2n) { }

/* Workaround - use classes */
.odd-item { }
.first-item { }
.last-item { }
```

### No Pseudo-Elements

```css
/* NOT supported */
p::before { content: "→ "; }
p::after { }
p::first-line { }
p::selection { }
```

**Workaround:** Add actual elements in HTML.

## SVG Limitations

### Simplified Bezier Curves

Bezier curve commands (C, S, Q, T) render as straight lines between start and end points.

```html
<!-- This curve will be simplified to a line -->
<path d="M 0,0 C 50,0 50,100 100,100" />
```

**Workaround:** Use multiple small line segments or polygon approximations.

### No Arc Command

The arc command (A) is not supported in paths.

```html
<!-- NOT supported -->
<path d="M 10,80 A 45,45 0 0 0 125,125" />
```

**Workaround:** Use `<circle>` or `<ellipse>` for arc shapes, or approximate with line segments.

### No SVG Transforms

```html
<!-- NOT supported -->
<g transform="rotate(45)">
<rect transform="translate(10, 10)" />
```

### No Masks or Filters

```html
<!-- NOT supported -->
<defs>
    <mask id="myMask">...</mask>
    <filter id="blur">...</filter>
</defs>
<rect mask="url(#myMask)" />
```

### No Text Element

```html
<!-- NOT supported -->
<text x="10" y="20">Hello</text>
```

**Workaround:** Use HTML text elements positioned over SVG.

### No Gradients in SVG

```html
<!-- NOT supported -->
<defs>
    <linearGradient id="grad">...</linearGradient>
</defs>
<rect fill="url(#grad)" />
```

**Workaround:** Use CSS gradients on the container instead.

## Typography Limitations

### Font Weight Simulation

Font weight is simulated using text outline, not true font weight.

**Workaround:** Load separate font files for each weight:

```gdscript
fonts = {
    "Roboto-Light": preload("res://fonts/Roboto-Light.ttf"),
    "Roboto": preload("res://fonts/Roboto-Regular.ttf"),
    "Roboto-Bold": preload("res://fonts/Roboto-Bold.ttf")
}
```

```css
.light { font-family: 'Roboto-Light'; }
.bold { font-family: 'Roboto-Bold'; }
```

### No Italic Support

Italic text requires separate italic font files.

```gdscript
fonts = {
    "Roboto": preload("res://fonts/Roboto-Regular.ttf"),
    "Roboto-Italic": preload("res://fonts/Roboto-Italic.ttf")
}
```

### Letter Spacing Simulation

Letter spacing is simulated using Unicode space characters, which may not be perfectly accurate.

### No Font Fallbacks

Only the first font in a font stack is used.

```css
/* Only 'Roboto' is used, Arial is ignored */
font-family: 'Roboto', Arial, sans-serif;
```

### No Web Fonts

Fonts must be local files. Web font loading (@font-face, Google Fonts) is not supported.

## Layout Limitations

### Scroll Requires Explicit Height

ScrollContainer only works when the container has an explicit height.

```css
/* Scrolling won't work */
.scroll {
    overflow-y: scroll;
}

/* Scrolling works */
.scroll {
    height: 300px;
    overflow-y: scroll;
}
```

### Images Require res:// Paths

All image paths must use Godot's resource path format.

```html
<!-- NOT supported -->
<img src="assets/logo.png">
<img src="/images/icon.png">
<img src="https://example.com/image.png">

<!-- Supported -->
<img src="res://assets/logo.png">
```

### No CSS Grid

Only Flexbox is supported for layout. CSS Grid is not available.

```css
/* NOT supported */
display: grid;
grid-template-columns: 1fr 1fr 1fr;
grid-gap: 16px;

/* Workaround - use flex with wrap */
display: flex;
flex-wrap: wrap;
gap: 16px;
```

### No Absolute/Fixed Positioning

```css
/* NOT supported */
position: absolute;
position: fixed;
position: relative;
top: 10px;
left: 20px;
z-index: 100;
```

**Workaround:** Use Godot's CanvasLayer for overlays.

## Color Limitations

### Limited Named Colors

Only these named colors are supported:

- `white`, `black`
- `red`, `green`, `blue`
- `yellow`, `cyan`, `magenta`
- `gray`, `grey`
- `orange`, `purple`, `pink`
- `transparent`

Other named colors (like `coral`, `navy`, `olive`) are not supported.

**Workaround:** Use hex or RGB values:

```css
/* Instead of 'coral' */
color: #ff7f50;

/* Instead of 'navy' */
color: rgb(0, 0, 128);
```

## Form Limitations

### Limited Input Validation

HTML5 validation attributes like `required`, `pattern`, `minlength` are not enforced.

**Workaround:** Validate in GDScript:

```gdscript
func _on_input_changed(id: String, value: String):
    if id == "email" and not value.contains("@"):
        show_error("Invalid email")
```

### No File Input

```html
<!-- NOT supported -->
<input type="file">
```

**Workaround:** Use Godot's FileDialog.

### No Date/Time Inputs

```html
<!-- NOT supported -->
<input type="date">
<input type="time">
<input type="datetime-local">
```

**Workaround:** Use custom date picker UI or text inputs.

### No Color Picker

```html
<!-- NOT supported -->
<input type="color">
```

**Workaround:** Use Godot's ColorPicker control.

## Browser Features Not Supported

These web features are not available:

- JavaScript
- Local storage / cookies
- Network requests (fetch, XHR)
- History / navigation
- Media queries / responsive design
- Print styles
- Accessibility attributes (aria-*)
- Shadow DOM
- Web components

## Performance Considerations

### Large DOM Trees

Very deep or wide DOM trees may impact performance. Keep nesting reasonable.

### Many Transitions

Multiple simultaneous transitions can be CPU-intensive.

### Live Reload

Live reload in editor adds file system overhead. Disable for production.

## See Also

- [CSS Properties](css-properties.md) - What is supported
- [HTML Elements](html-elements.md) - Supported elements
- [Extending GTML](extending-gtml.md) - Add missing features
