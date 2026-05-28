# Layout

_Arrange children with flexbox: direction, alignment, sizing, and gaps._

```html
<div style="display:flex; flex-direction:row; gap:12px; align-items:center;">
  <div style="flex-grow:1;">Stats</div>
  <div style="width:120px;">Map</div>
</div>
```

## Flex container

Set `display: flex` on a container to switch it from the default block stacking to a flex layout. Without it, children stack vertically in source order.

```css
.hud-row {
  display: flex;
  flex-direction: row;    /* row (default when flex) | column */
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}
```

### `flex-direction`

| Value | Godot container |
|-------|-----------------|
| `row` | `HBoxContainer` |
| `column` | `VBoxContainer` (default for `display: flex`) |

When `flex-wrap` is `wrap` or `wrap-reverse`, a `FlowContainer` is used instead.

### `justify-content` (main axis)

`flex-start`, `center`, `flex-end`, `space-between`, `space-around`, `space-evenly`.

`space-*` values are implemented with invisible expand-fill spacer controls inserted between children.

### `align-items` (cross axis)

`flex-start`, `center`, `flex-end`, `stretch`.

Applied as Godot size flags on each child. A child with an explicit `width` or `height` on the cross axis is not overridden.

### `align-self`

Overrides `align-items` for a single child. Same values as `align-items`.

### `flex-wrap`

`nowrap` (default), `wrap`, `wrap-reverse`.

Wrapping switches the container to a `FlowContainer`. Gap applies as `h_separation` / `v_separation` on the flow container.

## Gap

| Property | Effect |
|----------|--------|
| `gap` | Sets both row and column spacing. |
| `row-gap` | Row (vertical) spacing only. |
| `column-gap` | Column (horizontal) spacing only. |

Values are pixel integers. `column-gap` applies on `flex-direction: row` containers; `row-gap` on column containers.

## Sizing

### `width` / `height`

Accept `px` values (sets `custom_minimum_size`) and `%` values. A percentage less than 100 % attaches a resize listener that re-evaluates on parent size change. `100%` sets `SIZE_EXPAND_FILL`.

### `min-width` / `min-height` / `max-width` / `max-height`

Accept `px` or `%`. Min-size raises `custom_minimum_size` to at least the given value. Max-size stamps metadata and clamps after layout.

## Flex item properties

### `flex-grow`

A positive float. Translates to Godot's `SIZE_EXPAND` flag plus `size_flags_stretch_ratio`. Items with higher `flex-grow` receive proportionally more free space along the main axis.

```css
.sidebar { flex-grow: 1; }
.main    { flex-grow: 3; }   /* takes 3× as much space as .sidebar */
```

### `flex-shrink`

`0` prevents the item from shrinking below its base size (`SIZE_SHRINK_BEGIN`). Values greater than 0 defer to the container's default behaviour.

### `flex-basis`

Sets the initial main-axis size before free space is distributed. Accepts `px` or `%`; `auto` is a no-op.

### `order`

Integer. Children are sorted ascending by `order` before being added to the container. Default is `0`.

## Example: dashboard row

```html
<div class="dashboard">
  <div class="panel left">Inventory</div>
  <div class="panel center" style="flex-grow:1;">Map</div>
  <div class="panel right">Minimap</div>
</div>
```

```css
.dashboard {
  display: flex;
  flex-direction: row;
  gap: 8px;
  align-items: stretch;
  width: 100%;
}
.panel { padding: 12px; background-color: #1a1a2e; border-radius: 4px; }
.left  { width: 160px; }
.right { width: 120px; }
```

## See also

- [../reference/css-properties.md](../reference/css-properties.md) — full property table
- [transforms.md](transforms.md)
- [selectors.md](selectors.md)
