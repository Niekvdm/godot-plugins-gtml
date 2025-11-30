# Layout and Flexbox

GTML uses CSS Flexbox for layout, mapping to Godot's Container system. This guide covers layout concepts, alignment, and practical examples.

## Display Modes

### Flex (Default)

```css
.container {
    display: flex;
}
```

Creates a flex container. Children are arranged according to `flex-direction`.

### Block

```css
.item {
    display: block;
}
```

Standard block display. Element takes full width.

### None

```css
.hidden {
    display: none;
}
```

Hides the element completely.

## Flex Direction

### Column (Default)

```css
.container {
    display: flex;
    flex-direction: column;
}
```

Children stack vertically (VBoxContainer).

```
┌─────────────┐
│   Child 1   │
├─────────────┤
│   Child 2   │
├─────────────┤
│   Child 3   │
└─────────────┘
```

### Row

```css
.container {
    display: flex;
    flex-direction: row;
}
```

Children stack horizontally (HBoxContainer).

```
┌───────┬───────┬───────┐
│ Child │ Child │ Child │
│   1   │   2   │   3   │
└───────┴───────┴───────┘
```

## Flex Wrap

### No Wrap (Default)

```css
.container {
    flex-wrap: nowrap;
}
```

All items stay on one line, may overflow.

### Wrap

```css
.container {
    flex-wrap: wrap;
}
```

Items wrap to new lines when they exceed container width/height.

```
┌───────┬───────┬───────┐
│ Item1 │ Item2 │ Item3 │
├───────┼───────┼───────┘
│ Item4 │ Item5 │
└───────┴───────┘
```

Uses Godot's FlowContainer.

### Wrap Reverse

```css
.container {
    flex-wrap: wrap-reverse;
}
```

Items wrap in reverse order.

## Gap

Space between children.

```css
.container {
    gap: 16px;          /* All gaps */
    row-gap: 12px;      /* Vertical gaps only */
    column-gap: 8px;    /* Horizontal gaps only */
}
```

## Alignment

### Justify Content (Main Axis)

Controls alignment along the main axis (horizontal for row, vertical for column).

```css
/* Pack at start */
justify-content: flex-start;

/* Center items */
justify-content: center;

/* Pack at end */
justify-content: flex-end;

/* Even space between items */
justify-content: space-between;

/* Even space around items */
justify-content: space-around;

/* Equal space everywhere */
justify-content: space-evenly;
```

**Visual examples (row direction):**

```
flex-start:     [A][B][C]
center:              [A][B][C]
flex-end:                     [A][B][C]
space-between:  [A]     [B]     [C]
space-around:    [A]   [B]   [C]
space-evenly:     [A]    [B]    [C]
```

### Align Items (Cross Axis)

Controls alignment along the cross axis.

```css
/* Align to start */
align-items: flex-start;

/* Center alignment */
align-items: center;

/* Align to end */
align-items: flex-end;

/* Stretch to fill (default) */
align-items: stretch;
```

**Visual examples (row direction):**

```
flex-start:          stretch:
┌───────────────┐    ┌───────────────┐
│ [A] [B] [C]   │    │ A │ B │ C │   │
│               │    │ A │ B │ C │   │
│               │    │ A │ B │ C │   │
└───────────────┘    └───────────────┘

center:              flex-end:
┌───────────────┐    ┌───────────────┐
│               │    │               │
│ [A] [B] [C]   │    │               │
│               │    │ [A] [B] [C]   │
└───────────────┘    └───────────────┘
```

### Align Self

Override parent's `align-items` for a specific child.

```css
.container {
    align-items: flex-start;
}

.centered-child {
    align-self: center;
}
```

## Flex Grow & Shrink

### Flex Grow

Allow items to grow to fill available space.

```css
.grow {
    flex-grow: 1;
}
```

```html
<div class="container">
    <div class="fixed">Fixed</div>
    <div class="grow">Grows to fill</div>
    <div class="fixed">Fixed</div>
</div>
```

```
┌────────┬────────────────────────┬────────┐
│ Fixed  │      Grows to fill     │ Fixed  │
└────────┴────────────────────────┴────────┘
```

Multiple items with `flex-grow` share space proportionally:

```css
.grow-1 { flex-grow: 1; }  /* Gets 1/3 */
.grow-2 { flex-grow: 2; }  /* Gets 2/3 */
```

### Flex Shrink

Control whether items shrink when space is limited.

```css
.no-shrink {
    flex-shrink: 0;  /* Don't shrink */
}

.can-shrink {
    flex-shrink: 1;  /* Allow shrinking (default) */
}
```

### Flex Basis

Set the initial size before growing/shrinking.

```css
.item {
    flex-basis: 200px;
    flex-grow: 1;
}
```

## Order

Change visual order without changing HTML order.

```css
.first {
    order: -1;  /* Move to front */
}

.last {
    order: 1;   /* Move to back */
}

/* Default order is 0 */
```

```html
<div class="container">
    <div class="last">C (appears last)</div>
    <div>B (default)</div>
    <div class="first">A (appears first)</div>
</div>
```

Result: `[A] [B] [C]`

## Dimensions

### Fixed Dimensions

```css
.box {
    width: 200px;
    height: 150px;
}
```

### Percentage Dimensions

```css
.half-width {
    width: 50%;
}

.full-height {
    height: 100%;
}
```

### Min/Max Constraints

```css
.responsive {
    width: 100%;
    min-width: 200px;
    max-width: 600px;
}
```

## Overflow and Scrolling

### Enable Scrolling

To create a scrollable container:

1. Set an explicit height
2. Set `overflow: scroll` or `overflow: auto`

```css
.scrollable {
    height: 300px;
    overflow-y: scroll;
}
```

```html
<div class="scrollable">
    <!-- Long content here -->
</div>
```

### Overflow Options

```css
overflow: visible;  /* Show overflow (default) */
overflow: hidden;   /* Clip overflow */
overflow: scroll;   /* Always show scrollbars */
overflow: auto;     /* Scrollbars when needed */

overflow-x: hidden;  /* Horizontal only */
overflow-y: scroll;  /* Vertical only */
```

## Practical Examples

### Centered Content

```html
<div class="centered">
    <div class="content">Centered Box</div>
</div>
```

```css
.centered {
    display: flex;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100%;
}

.content {
    padding: 32px;
    background-color: #2a2a3e;
    border-radius: 8px;
}
```

### Header-Content-Footer Layout

```html
<div class="page">
    <header class="header">Header</header>
    <main class="content">Main Content</main>
    <footer class="footer">Footer</footer>
</div>
```

```css
.page {
    display: flex;
    flex-direction: column;
    height: 100%;
}

.header {
    padding: 16px;
    background-color: #1a1a2e;
}

.content {
    flex-grow: 1;
    padding: 24px;
    overflow-y: auto;
}

.footer {
    padding: 16px;
    background-color: #1a1a2e;
}
```

### Sidebar Layout

```html
<div class="layout">
    <aside class="sidebar">Sidebar</aside>
    <main class="main">Main Content</main>
</div>
```

```css
.layout {
    display: flex;
    flex-direction: row;
    height: 100%;
}

.sidebar {
    width: 250px;
    flex-shrink: 0;
    padding: 16px;
    background-color: #1a1a2e;
}

.main {
    flex-grow: 1;
    padding: 24px;
}
```

### Card Grid

```html
<div class="card-grid">
    <div class="card">Card 1</div>
    <div class="card">Card 2</div>
    <div class="card">Card 3</div>
    <div class="card">Card 4</div>
</div>
```

```css
.card-grid {
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    gap: 16px;
}

.card {
    width: 200px;
    padding: 16px;
    background-color: #2a2a3e;
    border-radius: 8px;
}
```

### Button Row

```html
<div class="button-row">
    <button @click="on_cancel" class="secondary">Cancel</button>
    <div class="spacer"></div>
    <button @click="on_save">Save</button>
</div>
```

```css
.button-row {
    display: flex;
    flex-direction: row;
    gap: 12px;
}

.spacer {
    flex-grow: 1;
}
```

### Navigation Bar

```html
<nav class="navbar">
    <div class="brand">
        <h1>Game Title</h1>
    </div>
    <div class="nav-links">
        <a @click="on_home">Home</a>
        <a @click="on_play">Play</a>
        <a @click="on_settings">Settings</a>
    </div>
</nav>
```

```css
.navbar {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
    padding: 16px 24px;
    background-color: #1a1a2e;
}

.brand h1 {
    font-size: 20px;
    color: #00d4ff;
}

.nav-links {
    display: flex;
    flex-direction: row;
    gap: 24px;
}

.nav-links a {
    color: #aaaacc;
}

.nav-links a:hover {
    color: #ffffff;
}
```

## See Also

- [CSS Properties](css-properties.md) - All layout properties
- [HTML Elements](html-elements.md) - Container elements
- [Getting Started](getting-started.md) - Basic examples
- Example: `addons/gtml/examples/flex_layout.html`
