# CSS Selectors

GTML supports basic CSS selectors for targeting elements. This guide covers selector types, pseudo-classes, and cascade priority.

## Selector Types

### Tag Selector

Target elements by their HTML tag name:

```css
div {
    padding: 16px;
}

button {
    background-color: #00d4ff;
}

p {
    font-size: 16px;
    color: #cccccc;
}

h1, h2, h3 {
    font-family: 'Orbitron';
}
```

### Class Selector

Target elements with a specific class:

```css
.container {
    display: flex;
    flex-direction: column;
    gap: 16px;
}

.primary {
    background-color: #00d4ff;
    color: #000000;
}

.danger {
    background-color: #ff4444;
    color: #ffffff;
}
```

HTML:
```html
<div class="container">
    <button class="primary">Save</button>
    <button class="danger">Delete</button>
</div>
```

### ID Selector

Target a specific element by its ID:

```css
#main-menu {
    width: 400px;
    padding: 32px;
}

#title {
    font-size: 48px;
    color: #ffffff;
}

#error-message {
    color: #ff4444;
    background-color: rgba(255, 68, 68, 0.1);
}
```

HTML:
```html
<div id="main-menu">
    <h1 id="title">Game Title</h1>
    <p id="error-message">Error text here</p>
</div>
```

### Comma-Separated Selectors

Apply the same styles to multiple selectors:

```css
h1, h2, h3, h4, h5, h6 {
    font-family: 'Orbitron';
    color: #ffffff;
}

button, a {
    cursor: pointer;
}

input, textarea, select {
    background-color: #1a1a28;
    border: 1px solid #3a3a5e;
    border-radius: 4px;
}
```

## Pseudo-Classes

### :hover

Applied when the mouse is over the element:

```css
button {
    background-color: #00d4ff;
    transition: background-color 200ms ease;
}

button:hover {
    background-color: #00a8cc;
}

a:hover {
    color: #00d4ff;
}
```

### :active

Applied when the element is being pressed:

```css
button:active {
    background-color: #008899;
    transform: scale(0.98);
}
```

### :focus

Applied when the element has keyboard focus:

```css
input:focus {
    border-color: #00d4ff;
    outline: 2px solid rgba(0, 212, 255, 0.3);
}

button:focus {
    outline: 2px solid #00d4ff;
    outline-offset: 2px;
}

textarea:focus {
    border-color: #00d4ff;
    background-color: #1e1e2e;
}
```

### :disabled

Applied when the element is disabled:

```css
button:disabled {
    background-color: #444444;
    color: #888888;
    cursor: not-allowed;
}

input:disabled {
    background-color: #2a2a2a;
    color: #666666;
}
```

## Pseudo-Class Support by Element

| Element | :hover | :active | :focus | :disabled |
|---------|--------|---------|--------|-----------|
| `button` | Yes | Yes | Yes | Yes |
| `a` | Yes | Yes | Yes | - |
| `input` | Yes | - | Yes | Yes |
| `textarea` | Yes | - | Yes | Yes |
| `select` | Yes | - | Yes | Yes |
| `div` (containers) | Yes | - | - | - |

## Cascade Priority

When multiple selectors match an element, styles are applied in this order (lowest to highest priority):

1. **Tag selectors** (lowest)
2. **Class selectors**
3. **ID selectors** (highest)

### Example

```css
/* Priority 1: Tag selector */
button {
    background-color: #333333;
    color: white;
    padding: 8px 16px;
}

/* Priority 2: Class selector - overrides tag */
.primary {
    background-color: #00d4ff;
    color: black;
}

/* Priority 3: ID selector - overrides class and tag */
#submit-btn {
    background-color: #00ff88;
    padding: 12px 24px;
}
```

HTML:
```html
<button>Default Button</button>
<!-- bg: #333333, color: white, padding: 8px 16px -->

<button class="primary">Primary Button</button>
<!-- bg: #00d4ff, color: black, padding: 8px 16px -->

<button class="primary" id="submit-btn">Submit</button>
<!-- bg: #00ff88, color: black, padding: 12px 24px -->
```

## Combining Selectors with Pseudo-Classes

Pseudo-classes work with all selector types:

```css
/* Tag + pseudo-class */
button:hover {
    background-color: #555555;
}

/* Class + pseudo-class */
.primary:hover {
    background-color: #00a8cc;
}

/* ID + pseudo-class */
#submit-btn:hover {
    background-color: #00cc66;
}
```

## Complete Example

```css
/* Base styles */
button {
    font-family: 'Rajdhani';
    font-size: 14px;
    padding: 12px 24px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 200ms ease;
}

/* Default button */
button {
    background-color: #3a3a5e;
    color: #ffffff;
}

button:hover {
    background-color: #4a4a7e;
}

button:active {
    background-color: #2a2a4e;
}

/* Primary variant */
.btn-primary {
    background-color: #00d4ff;
    color: #000000;
}

.btn-primary:hover {
    background-color: #00a8cc;
}

.btn-primary:active {
    background-color: #008899;
}

/* Danger variant */
.btn-danger {
    background-color: #ff4444;
    color: #ffffff;
}

.btn-danger:hover {
    background-color: #cc3333;
}

/* Disabled state */
button:disabled {
    background-color: #444444;
    color: #888888;
    cursor: not-allowed;
}
```

## Limitations

GTML does **not** support:

- Descendant selectors: `div p { }` or `ul li { }`
- Child selectors: `div > p { }`
- Sibling selectors: `h1 + p { }` or `h1 ~ p { }`
- Attribute selectors: `[type="text"] { }`
- Pseudo-elements: `::before`, `::after`
- `:nth-child()`, `:first-child`, `:last-child`
- `:not()` selector

For complex styling needs, use unique classes or IDs on target elements.

## See Also

- [CSS Properties](css-properties.md) - Available properties
- [Transitions](transitions.md) - Animate pseudo-class changes
- [Limitations](limitations.md) - Full list of limitations
