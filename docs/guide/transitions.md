# Transitions

_Animate style changes between pseudo-states with CSS transitions._

```css
.btn {
  background-color: #2a2a4a;
  transition: background-color 0.2s ease-in-out;
}
.btn:hover { background-color: #4a9eff; }
```

## Shorthand

```
transition: <property> <duration> [<timing-function>] [<delay>], ...
```

```css
/* Single */
transition: opacity 0.3s ease;

/* Multiple — comma-separated */
transition: background-color 0.2s ease-out, transform 0.15s ease-in-out 0.05s;
```

Only `property` is required. `duration` defaults to `0s`, `timing-function` to `ease`, `delay` to `0s`.

## Longhands

| Property | Accepts |
|----------|---------|
| `transition-property` | Comma-separated list of CSS property names. |
| `transition-duration` | Comma-separated list of time values (`0.3s`, `300ms`). |
| `transition-timing-function` | Comma-separated list of timing keywords (see below). |
| `transition-delay` | Comma-separated list of time values. |

Longhands are parsed independently; the shorthand is the practical way to specify everything in one line.

## Timing functions

| Value | Behaviour |
|-------|-----------|
| `ease` | Slow start and end, faster middle (Godot `TRANS_SINE / EASE_IN_OUT`). Default. |
| `ease-in` | Slow start. |
| `ease-out` | Slow end. |
| `ease-in-out` | Slow start and end. |
| `linear` | Constant speed. |
| `cubic-bezier(...)` | Parsed but falls back to `ease` — custom curves are not yet mapped to Godot Tween types. |

## Animatable properties

The transition engine has explicit animators for:

| Property | Animation method |
|----------|------------------|
| `background-color` | Lerps the `StyleBoxFlat` background color each frame. |
| `color` | Lerps the label/button font color via theme override. |
| `border-color` | Lerps the `StyleBoxFlat` border color each frame. |
| `width` | Tweens `custom_minimum_size.x`. |
| `height` | Tweens `custom_minimum_size.y`. |
| `opacity` | Tweens `modulate.a`. |
| `transform` | Interpolates scale, rotation, and position offset in parallel (see [transforms.md](transforms.md)). |

Any other property listed in `transition-property` is applied immediately (no interpolation).

## Pseudo-state triggers

Transitions fire when the active pseudo-state set changes. The two wired states are:

| State | Signal pair |
|-------|-------------|
| `:hover` | `mouse_entered` / `mouse_exited` |
| `:focus` | `focus_entered` / `focus_exited` |

When both hover and focus are active simultaneously, the engine merges the individual buckets and then the combined `_focus+hover` bucket (if a rule like `a:hover:focus { ... }` exists), so the more-specific combined rule wins.

`:active` and `:disabled` parse and resolve but do not fire at runtime — their signal wiring is deferred.

## Interrupted transitions

If a new transition fires while one is still running, the engine reads the current animated value from its tracking dict (rather than the snapshot from the original `from_style`) so the animation continues smoothly from wherever the control currently is.

## Example: button hover with color and scale

```css
.primary-btn {
  background-color: #1e3a5f;
  color: #ffffff;
  transform: scale(1.0);
  transition: background-color 0.18s ease-out, transform 0.12s ease-out;
}
.primary-btn:hover {
  background-color: #2d5f9e;
  transform: scale(1.04);
}
```

## See also

- [transforms.md](transforms.md)
- [selectors.md](selectors.md)
- [../reference/css-properties.md](../reference/css-properties.md)
