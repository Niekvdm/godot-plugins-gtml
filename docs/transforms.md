# Transforms

GTML supports the CSS `transform` property — `translate`, `scale`, and
`rotate`. Transforms map to `Control.position`, `Control.scale`, and
`Control.rotation` respectively, with `pivot_offset` set to the element's
visual centre so scale/rotate behave like the CSS default
`transform-origin: 50% 50%`.

> **Added in v0.4.** Animated transitions for `transform` added in v0.5.
> Parser lives in `addons/gtml/src/css/values/GmlTransformValues.gd`;
> application in `addons/gtml/src/html_renderer/GmlDimensions.gd`.

## Syntax

```css
.card {
    transform: translate(10px, 0);
}

.icon-rotated {
    transform: rotate(45deg);
}

.hero-image {
    transform: scale(1.05);
}
```

### Function reference

| Function | Args | Notes |
|---|---|---|
| `translate(x[, y])` | px values | second arg defaults to 0 |
| `translateX(x)` | px | shorthand for `translate(x, 0)` |
| `translateY(y)` | px | shorthand for `translate(0, y)` |
| `scale(s)` | unitless | uniform scale on both axes |
| `scale(sx, sy)` | unitless | per-axis scale |
| `scaleX(s)` / `scaleY(s)` | unitless | per-axis shorthand |
| `rotate(45deg)` | angle | accepts `deg`, `rad`, `turn`, or a bare number (treated as degrees) |

### Composition

Multiple functions in one declaration compose left-to-right; later writes
overwrite earlier ones for the same axis:

```css
.thing {
    transform: translate(10px, 0) scale(1.05) rotate(-3deg);
}
```

## Animating transforms

Include `transform` in a `transition` declaration and the transition
manager interpolates scale, rotation, and translate together through a
single tween:

```css
.card {
    transition: transform 220ms;
}

.card:hover {
    transform: scale(1.04);
}
```

When the target style omits `transform`, the manager treats the implicit
target as the identity transform `{translate: 0,0; scale: 1,1; rotate: 0}`
and animates back to neutral — so hover-out reverts cleanly without
needing an explicit `:not(:hover)` rule.

### Composing with other transitions

`transform` plays nicely with other transitioned properties on the same
rule:

```css
.btn-primary {
    transition: background-color 180ms, transform 180ms;
}

.btn-primary:hover {
    background-color: var(--accent-hot);
    transform: scale(1.03);
}
```

## Pivot

`pivot_offset` is recomputed on the control's first frame and on every
`resized` signal to keep the visual centre as the rotation/scale anchor.
There is no `transform-origin` property yet — if you need an off-centre
pivot, anchor your element manually via Container layout.

## Limitations

- Only `translate` / `scale` / `rotate` are supported. `skew`, `matrix`,
  3D transforms (`translate3d`, `rotateX`/`rotateY`/`rotateZ`,
  `perspective`) are not implemented.
- `transform-origin` is not parsed; it defaults to the visual centre.
- `transform` arguments are split on commas at the function level. Nested
  CSS values like `translate(calc(10px + 5px), 0)` work because the
  resolver evaluates `calc()` before transform parsing — but only because
  the result is a literal by the time the transform parser sees it.

See `addons/gtml/examples/showcase/kitchen/` for a single-scene reference
exercising every transform function with transitions.
