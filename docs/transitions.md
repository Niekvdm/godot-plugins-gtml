# CSS Transitions

GTML supports CSS transitions for smooth property animations between states. This guide covers transition syntax, supported properties, and examples.

## Basic Syntax

```css
transition: property duration timing-function delay;
```

### Example

```css
button {
    background-color: #00d4ff;
    transition: background-color 200ms ease;
}

button:hover {
    background-color: #00a8cc;
}
```

## Transition Properties

### transition

Shorthand for all transition properties:

```css
transition: background-color 300ms ease 0ms;
transition: all 200ms linear;
```

### transition-property

Specify which properties to animate:

```css
transition-property: background-color;
transition-property: background-color, border-color;
transition-property: all;  /* Animate all changes */
```

### transition-duration

How long the transition takes:

```css
transition-duration: 200ms;   /* Milliseconds */
transition-duration: 0.5s;    /* Seconds */
```

### transition-timing-function

The easing curve for the animation:

```css
transition-timing-function: linear;       /* Constant speed */
transition-timing-function: ease;         /* Default - slow start/end */
transition-timing-function: ease-in;      /* Slow start */
transition-timing-function: ease-out;     /* Slow end */
transition-timing-function: ease-in-out;  /* Slow start and end */
```

### transition-delay

Wait before starting the transition:

```css
transition-delay: 100ms;
transition-delay: 0.2s;
```

## Animatable Properties

These properties can be smoothly animated:

| Property | Example |
|----------|---------|
| `background-color` | Smooth color changes |
| `border-color` | Border color transitions |
| `color` | Text color transitions |
| `opacity` | Fade in/out effects |
| `width` | Size animations |
| `height` | Size animations |

## Multiple Transitions

Animate multiple properties with different timings:

```css
button {
    background-color: #00d4ff;
    border: 2px solid transparent;
    opacity: 1;
    transition: background-color 200ms ease,
                border-color 150ms ease,
                opacity 300ms ease;
}

button:hover {
    background-color: #00a8cc;
    border-color: #ffffff;
}

button:disabled {
    opacity: 0.5;
}
```

## Practical Examples

### Button Hover Effect

```html
<button @click="on_play">Play Game</button>
```

```css
button {
    padding: 16px 32px;
    background-color: #00d4ff;
    border: none;
    border-radius: 4px;
    color: #000000;
    font-size: 16px;
    transition: background-color 200ms ease;
}

button:hover {
    background-color: #00a8cc;
}

button:active {
    background-color: #008899;
}
```

### Fade Effect

```html
<div class="notification" id="notification">
    <p>Settings saved!</p>
</div>
```

```css
.notification {
    padding: 16px;
    background-color: #00ff88;
    color: #000000;
    border-radius: 4px;
    opacity: 1;
    transition: opacity 300ms ease;
}

.notification.hidden {
    opacity: 0;
}
```

### Input Focus Effect

```html
<input type="text" id="username" placeholder="Enter username">
```

```css
input {
    padding: 12px;
    background-color: #1a1a28;
    border: 2px solid #3a3a5e;
    border-radius: 4px;
    color: #ffffff;
    transition: border-color 150ms ease,
                background-color 150ms ease;
}

input:focus {
    border-color: #00d4ff;
    background-color: #1e1e2e;
}
```

### Card Hover

```html
<div class="card">
    <h3>Card Title</h3>
    <p>Card description goes here.</p>
</div>
```

```css
.card {
    padding: 20px;
    background-color: #2a2a3e;
    border: 1px solid #3a3a5e;
    border-radius: 8px;
    transition: background-color 200ms ease,
                border-color 200ms ease;
}

.card:hover {
    background-color: #3a3a4e;
    border-color: #4a4a6e;
}
```

### Menu Item Highlight

```html
<nav class="menu">
    <a @click="on_home" class="menu-item">Home</a>
    <a @click="on_play" class="menu-item">Play</a>
    <a @click="on_settings" class="menu-item">Settings</a>
</nav>
```

```css
.menu {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.menu-item {
    padding: 12px 20px;
    color: #aaaacc;
    background-color: transparent;
    border-radius: 4px;
    transition: color 150ms ease,
                background-color 150ms ease;
}

.menu-item:hover {
    color: #ffffff;
    background-color: rgba(255, 255, 255, 0.1);
}
```

### Button with Border Animation

```html
<button @click="on_action" class="outline-btn">Action</button>
```

```css
.outline-btn {
    padding: 12px 24px;
    background-color: transparent;
    border: 2px solid #00d4ff;
    border-radius: 4px;
    color: #00d4ff;
    transition: background-color 200ms ease,
                color 200ms ease;
}

.outline-btn:hover {
    background-color: #00d4ff;
    color: #000000;
}
```

### Delayed Transition

```css
.delayed {
    opacity: 0;
    transition: opacity 300ms ease 500ms;  /* 500ms delay */
}

.delayed:hover {
    opacity: 1;
}
```

## Timing Functions Comparison

```
linear:
├─────────────────────────────────────────►

ease (default):
├──────────────╮                    ╭─────►
               ╰────────────────────╯

ease-in:
├───────────────────────────────╮   ╭─────►
                                ╰───╯

ease-out:
├───╮   ╭─────────────────────────────────►
    ╰───╯

ease-in-out:
├──────────╮            ╭─────────────────►
           ╰────────────╯
```

## Best Practices

### 1. Keep Transitions Short

```css
/* Good - snappy and responsive */
transition: background-color 150ms ease;

/* Too slow - feels laggy */
transition: background-color 1000ms ease;
```

### 2. Use Appropriate Properties

```css
/* Good - lightweight properties */
transition: opacity 200ms, background-color 200ms;

/* Avoid animating expensive properties unnecessarily */
```

### 3. Match Transition to Action

```css
/* Hover - quick feedback */
button:hover {
    transition: background-color 150ms ease;
}

/* Appearing content - slightly longer */
.modal {
    transition: opacity 300ms ease;
}
```

### 4. Consistent Timing

```css
/* Use consistent durations across UI */
:root {
    --transition-fast: 100ms;
    --transition-normal: 200ms;
    --transition-slow: 300ms;
}
```

## Example File

See `addons/gtml/examples/transitions.html` and `transitions.css` for a complete working example.

## Limitations

- **No CSS animations** (`@keyframes`) - only transitions
- **No transform property** - can't animate rotation, scale, position
- **No CSS variables** for dynamic values
- **Cubic-bezier()** timing functions fall back to `ease`

## See Also

- [CSS Properties](css-properties.md) - Animatable properties
- [CSS Selectors](css-selectors.md) - Pseudo-classes for triggering transitions
- [Limitations](limitations.md) - Full limitations list
