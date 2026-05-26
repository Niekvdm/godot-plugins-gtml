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

## Combinators

> **Added in v0.2 (descendant, child) / v0.3 (sibling).**

| Combinator | Example | Matches |
|---|---|---|
| ` ` (descendant) | `.card p` | `<p>` anywhere inside `.card` |
| `>` (child) | `.card > p` | `<p>` whose direct parent is `.card` |
| `+` (adjacent sibling) | `.a + .b` | `.b` immediately preceded by `.a` |
| `~` (general sibling) | `.a ~ .b` | any `.b` after a `.a` sibling |

Whitespace alone is the descendant combinator. `.a+.b` (no spaces) is
equivalent to `.a + .b`.

## Compound selectors

Multiple simple selectors stacked with no combinator target the same
element. All constraints must match.

```css
div.card           /* div with class "card" */
button.primary     /* button with class "primary" */
input#email        /* input with id "email" */
div.card.featured  /* div with both classes */
```

## Attribute selectors

> **Added in v0.2 (`[attr]`, `[attr="val"]`) / v0.3 (substring matchers).**

| Form | Matches |
|---|---|
| `[attr]` | element has the attribute (any value) |
| `[attr="value"]` | exact match (quotes optional) |
| `[attr~="word"]` | whitespace-separated word list contains "word" as a whole word |
| `[attr^="prefix"]` | value starts with "prefix" |
| `[attr$="suffix"]` | value ends with "suffix" |
| `[attr*="substr"]` | value contains "substr" anywhere |

```css
input[disabled] { opacity: 0.5; }
input[type="email"] { font-family: 'monospace'; }
a[href^="https://"] { color: blue; }
img[src$=".svg"] { background-color: white; }
[class~="card"] { padding: 16px; }
```

## Structural pseudo-classes

> **Added in v0.3.**

| Pseudo | Matches |
|---|---|
| `:first-child` | first element child of its parent |
| `:last-child` | last element child |
| `:only-child` | the sole element child |
| `:nth-child(N)` | the Nth element child (1-based) |
| `:nth-child(odd \| even)` | by parity |
| `:nth-child(an+b)` | matches positions a·n + b for n ≥ 0 |
| `:not(selector)` | negation; argument is a simple selector |

```css
.list li:first-child { color: var(--accent); }
.row:nth-child(2n+1) { background-color: var(--surface-2); }
p:not(.muted) { color: var(--text-1); }
```

State pseudos (`:hover`, `:focus`, `:active`, `:disabled`, `:checked`)
contribute to specificity but do NOT affect DOM matching — see the
state-pseudo section above.

## Multi-pseudo combined states

> **Added in v0.3.**

```css
button:hover:focus {
    background-color: var(--accent-hot);
}
```

The rule applies only when ALL listed state pseudos are simultaneously
active. Combined-state buckets are keyed by the sorted pseudo set, so
`button:hover:focus` and `button:focus:hover` resolve into the same
bucket and never duplicate.

## Limitations

GTML does **not** support:

- Pseudo-elements: `::before`, `::after`
- `:nth-of-type()`, `:first-of-type`, `:last-of-type`
- `:nth-last-child()`
- `:is()`, `:where()`, `:has()`, `:matches()`
- Namespaced selectors (`ns|tag`)

For substring matchers, multi-segment combinators, and structural pseudos,
see the sections above — those ARE supported.

## See Also

- [CSS Properties](css-properties.md) - Available properties
- [Transitions](transitions.md) - Animate pseudo-class changes
- [Limitations](limitations.md) - Full list of limitations
