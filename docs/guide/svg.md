# SVG

_Embed inline SVG shapes directly in your HTML markup._

```html
<svg width="24" height="24" viewBox="0 0 24 24" stroke="white" fill="none">
  <circle cx="12" cy="12" r="10"/>
  <line x1="12" y1="8" x2="12" y2="12"/>
</svg>
```

## How it works

GTML renders inline `<svg>` elements using a custom Godot `Control` subclass. The SVG markup is parsed at build time into a list of draw commands. The control then executes those commands in its `_draw()` callback each frame, scaling the shapes to fit the control's current size while maintaining the viewBox aspect ratio (letterboxed, centered).

There is no runtime SVG renderer — the shapes are translated to Godot primitive draw calls (polygons, polylines, arcs). External SVG files loaded via `<img src="...">` are handled by the standard `TextureRect` path and are not subject to any of the limitations below.

## `viewBox`

```html
<svg viewBox="0 0 24 24" width="48" height="48">
```

The `viewBox` attribute defines the coordinate space for all child elements. Width and height on the `<svg>` element (or from CSS `width`/`height`) set the rendered pixel size; the shapes scale proportionally from the viewBox coordinate space to the render size.

## Supported elements

| Element | Supported attributes |
|---------|---------------------|
| `<polygon>` | `points`, `fill`, `stroke`, `stroke-width` |
| `<polyline>` | `points`, `stroke`, `stroke-width` |
| `<line>` | `x1`, `y1`, `x2`, `y2`, `stroke`, `stroke-width` |
| `<circle>` | `cx`, `cy`, `r`, `fill`, `stroke`, `stroke-width` |
| `<ellipse>` | `cx`, `cy`, `rx`, `ry`, `fill`, `stroke`, `stroke-width` |
| `<rect>` | `x`, `y`, `width`, `height`, `rx`, `ry`, `fill`, `stroke`, `stroke-width` |
| `<path>` | `d`, `fill`, `stroke`, `stroke-width` |
| `<g>` | `fill`, `stroke`, `stroke-width` (inherited by children) |

Attributes not in the list above are ignored.

## Path `d` commands

| Command | Meaning |
|---------|---------|
| `M` / `m` | Move to (absolute / relative) |
| `L` / `l` | Line to |
| `H` / `h` | Horizontal line to |
| `V` / `v` | Vertical line to |
| `Z` / `z` | Close path |
| `C` / `c` | Cubic Bézier — **simplified to endpoint only** (control points ignored) |
| `S` / `s` | Smooth cubic Bézier — simplified to endpoint |
| `Q` / `q` | Quadratic Bézier — simplified to endpoint |
| `T` / `t` | Smooth quadratic Bézier — simplified to endpoint |
| `A` / `a` | Arc — **skipped entirely** (no points added) |

Curves are approximated as straight-line segments to their endpoints. Complex paths with many curves will look angular.

## Colors

Attribute values are parsed as:
- CSS hex: `#rgb`, `#rrggbb`
- CSS named colors: `white`, `black`, `red`, `green`, `blue`, `yellow`, `cyan`, `magenta`, `gray`/`grey`, `orange`, `purple`, `pink`
- `rgb(r, g, b)` / `rgba(r, g, b, a)`
- `none` / `transparent` → fully transparent
- `currentColor` → inherits the parent color
- `inherit` → inherits the parent color

## Default stroke and fill

Set defaults on the `<svg>` element; children inherit them unless they override:

```html
<svg stroke="#aaa" fill="transparent" stroke-width="1.5" viewBox="0 0 16 16">
  <circle cx="8" cy="8" r="6"/>         <!-- inherits stroke/fill/width -->
  <line x1="8" y1="4" x2="8" y2="8" stroke="white"/> <!-- overrides stroke -->
</svg>
```

The CSS `color` property on the `<svg>` element overrides the `stroke` default. The CSS `fill` property (if parsed as a Color) overrides the `fill` default.

## Sizing

Size the SVG with CSS `width`/`height` or with HTML attributes directly:

```css
.icon { width: 32px; height: 32px; }
```

When both width and height are set, `SIZE_SHRINK_CENTER` is applied so the icon centers inside its flex slot.

## Limitations

- Bezier curves are simplified to endpoints — avoid complex curved paths.
- Arcs (`A`/`a`) produce no output.
- `<text>`, `<image>`, `<use>`, `<defs>`, filters, masks, and clip-paths are not supported.
- CSS styling of SVG child elements (e.g. `.my-path { fill: red; }`) does not apply — use inline attributes.
- `stroke-dasharray`, `stroke-linecap`, `stroke-linejoin` are not supported.

## See also

- [../reference/html-elements.md](../reference/html-elements.md) — full element reference including `<img>`
