# Fonts

_Set font families, sizes, weights, spacing, and color for text elements._

```css
h1 { font-family: "Orbitron"; font-size: 32px; font-weight: bold; color: #e0e0ff; }
p  { font-size: 14px; letter-spacing: 0.5px; }
```

## `font-size`

Pixel integer. Applied as a Godot theme font-size override on the label.

```css
.caption { font-size: 11px; }
.headline { font-size: 28px; }
```

Tag defaults (`h1`, `h2`, `h3`, `p`) have built-in sizes configurable on the `GtmlView` node in the Inspector.

## `font-family`

Names a font from the `fonts` export Dictionary on `GtmlView`. Only the first name in a comma-separated font stack is used.

```css
.ui-text { font-family: "Orbitron"; }
.mono    { font-family: 'JetBrains Mono', monospace; }  /* only "JetBrains Mono" is looked up */
```

Assign fonts in the Godot Inspector on your `GtmlView` node:

```
fonts = {
  "Orbitron": <FontFile: Orbitron-Regular.ttf>,
  "JetBrains Mono": <FontFile: JetBrainsMono-Regular.ttf>
}
```

If the requested family is not in the dictionary, the engine falls back to the scene's default font.

## `font-weight`

Accepts keywords (`thin`, `light`, `normal`, `medium`, `semibold`, `bold`, `extrabold`, `black`) or numeric values `100`–`950`.

```css
.label-bold { font-weight: bold; }    /* 700 */
.label-thin { font-weight: 300; }
```

Bold variant lookup order for a family `"Roboto"` with weight >= 600:

1. `"Roboto-Bold"` in the fonts dict
2. `"RobotoBold"`
3. `"Roboto Bold"`
4. `"Roboto-700"` (weight suffix)
5. `"Roboto"` (regular fallback)

If no bold variant is found, an outline simulation (label `outline_size` override) is applied. For `font-weight: 900+` the outline is 2–3 px wide; for 600–899 it is 1 px.

## `color`

The text color for labels and buttons. Falls back to the `default_font_color` export on `GtmlView` (default white) when no `color` rule matches.

```css
.danger { color: #ff4444; }
.muted  { color: rgba(255,255,255,0.5); }
```

## `letter-spacing`

Space added between glyphs. Accepts `px` or `em` (resolved against a fixed 16 px base). Stored as `spacing_glyph` on a `FontVariation`.

```css
.spaced { letter-spacing: 2px; }
.tight  { letter-spacing: -0.5px; }
```

## `word-spacing`

Space added between words. Applied as `spacing_space` on the same `FontVariation` as `letter-spacing`.

## `line-height`

Pixel integer. Maps to the `line_spacing` theme constant on the Godot `Label`.

```css
.body { line-height: 20px; }
```

## `text-decoration`

Values: `underline`, `line-through`, `overline`, `none`, or a space-separated combination.

```css
.link { text-decoration: underline; }
.strike { text-decoration: line-through; }
.both  { text-decoration: underline line-through; }
```

Decorations are drawn by a custom `Control` wrapper placed around the label.

## `text-align`

`left`, `center`, `right`, `justify`. Maps to Godot's `horizontal_alignment`.

## See also

- [../reference/css-properties.md](../reference/css-properties.md) — full property table
- [../reference/gtmlview-api.md](../reference/gtmlview-api.md) — `fonts` export and `GtmlView` inspector properties
