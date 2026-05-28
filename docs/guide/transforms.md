# Transforms

_Translate, scale, and rotate a control without affecting layout flow._

```css
.card:hover { transform: scale(1.05); }
.icon        { transform: rotate(45deg) translate(4px, -4px); }
```

## Syntax

```css
transform: <function> [<function> ...];
```

Multiple functions compose left-to-right in the same declaration. The three supported functions are:

| Function | Effect | Example |
|----------|--------|---------|
| `translate(x, y)` | Offsets the control's position by `x` and `y` pixels. The `y` argument is optional (defaults to 0). | `translate(10px, -5px)` |
| `translateX(x)` | Horizontal offset only. | `translateX(8px)` |
| `translateY(y)` | Vertical offset only. | `translateY(-4px)` |
| `scale(sx, sy)` | Scales the control. One argument scales uniformly; two arguments scale axes independently. | `scale(1.2)` |
| `scaleX(sx)` | Horizontal scale only. | `scaleX(0.5)` |
| `scaleY(sy)` | Vertical scale only. | `scaleY(2)` |
| `rotate(angle)` | Rotates the control. Accepts `deg`, `rad`, or `turn`; a bare number is treated as degrees. | `rotate(45deg)` |

Units on `translate` values are stripped — only the numeric part is used (pixel offsets).

## Transform origin

The pivot is automatically set to the center of the control (`pivot_offset = size * 0.5`) after layout resolves the control's size. This is equivalent to CSS `transform-origin: 50% 50%`. The pivot recalculates on `resized` so it stays correct if the control changes size.

## Interaction with layout

Transform does not affect the flow layout. A translated or scaled control still occupies its original layout slot; neighboring controls do not reflow. The position offset from `translate` is added on top of the container-assigned position, stored in `_transform_base_position` metadata so reverts (e.g. when a `:hover` transition ends) return to the correct spot.

## Combining with transitions

Transform is one of the properties the transition engine can animate. Pair it with a `:hover` rule and a `transition` declaration:

```css
.btn {
  transform: scale(1.0);
  transition: transform 0.15s ease-out;
}
.btn:hover {
  transform: scale(1.08);
}
```

All three components (translate, scale, rotate) are interpolated in parallel when a transform transition fires. If the base rule has no `transform` declaration the engine treats it as identity (`scale(1)`, `rotate(0)`, `translate(0,0)`) so the animated revert still works.

## See also

- [transitions.md](transitions.md)
- [layout.md](layout.md)
