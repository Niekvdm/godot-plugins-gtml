# SVG Support

GTML supports inline SVG (Scalable Vector Graphics) for rendering vector icons and graphics. SVGs are rendered using Godot's drawing API through a custom `SvgDrawControl`.

## Basic Usage

```html
<svg viewBox="0 0 24 24" width="24" height="24">
    <circle cx="12" cy="12" r="10" fill="#00d4ff" />
</svg>
```

## SVG Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `viewBox` | Defines the coordinate system | `"0 0 24 24"` |
| `width` | Display width in pixels | `"32"` |
| `height` | Display height in pixels | `"32"` |
| `stroke` | Default stroke color | `"#ffffff"` |
| `fill` | Default fill color | `"#00d4ff"` |
| `stroke-width` | Default stroke width | `"2"` |

## Supported Elements

### Circle

```html
<svg viewBox="0 0 24 24">
    <circle cx="12" cy="12" r="8" fill="#00d4ff" />
    <circle cx="12" cy="12" r="10" fill="none" stroke="#ffffff" stroke-width="2" />
</svg>
```

**Attributes:** `cx`, `cy`, `r`, `fill`, `stroke`, `stroke-width`

### Ellipse

```html
<svg viewBox="0 0 24 24">
    <ellipse cx="12" cy="12" rx="10" ry="6" fill="#00d4ff" />
</svg>
```

**Attributes:** `cx`, `cy`, `rx`, `ry`, `fill`, `stroke`, `stroke-width`

### Rectangle

```html
<svg viewBox="0 0 24 24">
    <rect x="2" y="2" width="20" height="20" fill="#00d4ff" />
    <rect x="4" y="4" width="16" height="16" rx="4" ry="4" fill="none" stroke="#ffffff" />
</svg>
```

**Attributes:** `x`, `y`, `width`, `height`, `rx`, `ry` (corner radius), `fill`, `stroke`, `stroke-width`

### Line

```html
<svg viewBox="0 0 24 24">
    <line x1="2" y1="2" x2="22" y2="22" stroke="#ffffff" stroke-width="2" />
</svg>
```

**Attributes:** `x1`, `y1`, `x2`, `y2`, `stroke`, `stroke-width`

### Polygon

Closed shape defined by points.

```html
<svg viewBox="0 0 24 24">
    <!-- Triangle -->
    <polygon points="12,2 22,22 2,22" fill="#00d4ff" />

    <!-- Hexagon -->
    <polygon points="12,2 22,8.5 22,15.5 12,22 2,15.5 2,8.5"
             fill="none" stroke="#ffffff" stroke-width="1.5" />
</svg>
```

**Attributes:** `points`, `fill`, `stroke`, `stroke-width`

### Polyline

Open shape defined by points (no automatic closing).

```html
<svg viewBox="0 0 24 24">
    <polyline points="2,12 8,6 14,18 22,12"
              fill="none" stroke="#00d4ff" stroke-width="2" />
</svg>
```

**Attributes:** `points`, `fill`, `stroke`, `stroke-width`

### Path

Complex shapes using SVG path commands.

```html
<svg viewBox="0 0 24 24">
    <!-- Checkmark -->
    <path d="M4,12 L10,18 L20,6" fill="none" stroke="#00ff88" stroke-width="2" />

    <!-- Heart -->
    <path d="M12,21 L10.55,19.7 C5.4,15.1 2,12.1 2,8.4 C2,5.4 4.4,3 7.5,3
             C9.24,3 10.91,3.81 12,5.08 C13.09,3.81 14.76,3 16.5,3
             C19.6,3 22,5.4 22,8.4 C22,12.1 18.6,15.1 13.45,19.7 L12,21 Z"
          fill="#ff4444" />
</svg>
```

**Attributes:** `d` (path data), `fill`, `stroke`, `stroke-width`

### Group

Groups elements with shared styling.

```html
<svg viewBox="0 0 24 24">
    <g fill="none" stroke="#ffffff" stroke-width="2">
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="6" x2="12" y2="12" />
        <line x1="12" y1="12" x2="16" y2="14" />
    </g>
</svg>
```

Child elements inherit `fill`, `stroke`, and `stroke-width` from the group.

## Path Commands

The `d` attribute in `<path>` supports these commands:

| Command | Description | Parameters |
|---------|-------------|------------|
| `M` / `m` | Move to | `x y` |
| `L` / `l` | Line to | `x y` |
| `H` / `h` | Horizontal line | `x` |
| `V` / `v` | Vertical line | `y` |
| `Z` / `z` | Close path | (none) |
| `C` / `c` | Cubic bezier* | `x1 y1 x2 y2 x y` |
| `S` / `s` | Smooth cubic* | `x2 y2 x y` |
| `Q` / `q` | Quadratic bezier* | `x1 y1 x y` |
| `T` / `t` | Smooth quadratic* | `x y` |

Uppercase = absolute coordinates, lowercase = relative coordinates.

> **Note:** Bezier curves (C, S, Q, T) are simplified to straight lines between start and end points. Arc commands (A) are not supported.

### Path Examples

```html
<!-- Simple arrow -->
<path d="M 4 12 L 20 12 M 14 6 L 20 12 L 14 18" />

<!-- Square with rounded corners (manual) -->
<path d="M 6 2 H 18 L 22 6 V 18 L 18 22 H 6 L 2 18 V 6 Z" />

<!-- X mark -->
<path d="M 4 4 L 20 20 M 20 4 L 4 20" />
```

## Color Values

SVG elements support these color formats:

```html
<!-- Hex colors -->
<circle fill="#ff5500" stroke="#ffffff" />
<circle fill="#f50" />

<!-- RGB/RGBA -->
<circle fill="rgb(255, 85, 0)" />
<circle fill="rgba(255, 85, 0, 0.8)" />

<!-- Named colors -->
<circle fill="red" />
<circle fill="transparent" />
<circle fill="none" />

<!-- Inherit from CSS -->
<circle stroke="currentColor" />
```

**Named colors:** white, black, red, green, blue, yellow, cyan, magenta, gray, orange, purple, pink, transparent

## CSS Color Inheritance

SVGs inherit the `color` CSS property for stroke:

```html
<button class="icon-button">
    <svg viewBox="0 0 24 24" width="16" height="16">
        <path d="M12,2 L22,22 L2,22 Z" fill="none" stroke="currentColor" stroke-width="2" />
    </svg>
    <span>Warning</span>
</button>
```

```css
.icon-button {
    color: #ffaa00;  /* SVG will inherit this for stroke */
}

.icon-button:hover {
    color: #ffcc00;  /* SVG stroke changes on hover */
}
```

## Sizing

### Fixed Size

```html
<svg viewBox="0 0 24 24" width="48" height="48">
    <!-- Content renders at 48x48 pixels -->
</svg>
```

### CSS Sizing

```html
<svg viewBox="0 0 24 24" class="icon-large">
    <!-- Size controlled by CSS -->
</svg>
```

```css
.icon-large {
    width: 64px;
    height: 64px;
}
```

### ViewBox Scaling

The `viewBox` defines the coordinate system. Content scales to fit the display size while maintaining aspect ratio:

```html
<!-- Same viewBox, different display sizes -->
<svg viewBox="0 0 24 24" width="16" height="16">...</svg>
<svg viewBox="0 0 24 24" width="32" height="32">...</svg>
<svg viewBox="0 0 24 24" width="64" height="64">...</svg>
```

## Complete Examples

### Settings Icon

```html
<svg viewBox="0 0 24 24" width="24" height="24">
    <g fill="none" stroke="currentColor" stroke-width="2">
        <!-- Outer gear -->
        <path d="M12,2 L14,4 L14,6 L16,7 L18,5 L20,7 L18,9 L19,11 L22,12
                 L22,14 L19,14 L18,16 L20,18 L18,20 L16,18 L14,19 L14,22
                 L12,22 L10,19 L8,18 L6,20 L4,18 L6,16 L5,14 L2,14
                 L2,12 L5,11 L6,9 L4,7 L6,5 L8,7 L10,6 L10,4 Z" />
        <!-- Center circle -->
        <circle cx="12" cy="12" r="3" />
    </g>
</svg>
```

### Play Button

```html
<svg viewBox="0 0 24 24" width="32" height="32">
    <circle cx="12" cy="12" r="11" fill="none" stroke="#00d4ff" stroke-width="2" />
    <polygon points="10,8 10,16 16,12" fill="#00d4ff" />
</svg>
```

### Checkmark

```html
<svg viewBox="0 0 24 24" width="24" height="24">
    <circle cx="12" cy="12" r="10" fill="#00ff88" />
    <path d="M7,12 L10,15 L17,8" fill="none" stroke="#000000" stroke-width="2" />
</svg>
```

### Menu Icon (Hamburger)

```html
<svg viewBox="0 0 24 24" width="24" height="24">
    <g stroke="currentColor" stroke-width="2">
        <line x1="3" y1="6" x2="21" y2="6" />
        <line x1="3" y1="12" x2="21" y2="12" />
        <line x1="3" y1="18" x2="21" y2="18" />
    </g>
</svg>
```

### Close Icon (X)

```html
<svg viewBox="0 0 24 24" width="24" height="24">
    <g stroke="currentColor" stroke-width="2">
        <line x1="6" y1="6" x2="18" y2="18" />
        <line x1="18" y1="6" x2="6" y2="18" />
    </g>
</svg>
```

## Using SVGs in Buttons

```html
<button @click="on_settings" class="icon-btn">
    <svg viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="3" fill="currentColor" />
        <circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2" />
    </svg>
</button>

<button @click="on_play" class="play-btn">
    <svg viewBox="0 0 24 24">
        <polygon points="8,6 8,18 18,12" fill="currentColor" />
    </svg>
    <span>Play</span>
</button>
```

```css
.icon-btn {
    width: 40px;
    height: 40px;
    padding: 8px;
    background-color: transparent;
    border: 1px solid #3a3a5e;
    border-radius: 4px;
    color: #ffffff;
}

.icon-btn:hover {
    background-color: #3a3a5e;
    color: #00d4ff;
}

.play-btn {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 8px;
    padding: 12px 20px;
    color: #000000;
    background-color: #00d4ff;
}

.play-btn svg {
    width: 16px;
    height: 16px;
}
```

## Limitations

- **Bezier curves** (C, S, Q, T) render as straight lines to endpoints
- **Arc command** (A) is not supported
- **Transforms** (`transform` attribute) not supported
- **Masks and filters** not supported
- **Text elements** (`<text>`) not supported
- **Gradients** (`<linearGradient>`, `<radialGradient>`) not supported
- **Use/defs** (`<use>`, `<defs>`) not supported

## See Also

- [HTML Elements](html-elements.md) - SVG in context
- [CSS Properties](css-properties.md) - Styling with CSS
- [Limitations](limitations.md) - Full limitations list
