# Selectors

_Target elements with tag, class, ID, attributes, combinators, and pseudo-classes._

```css
button.primary:hover { background-color: #4a9eff; }
.hud > .panel { padding: 8px; }
input[type="checkbox"]:checked { border-color: #0f0; }
```

## Simple selectors

| Syntax | Matches |
|--------|---------|
| `div` | Any element with that tag name (case-insensitive). |
| `.name` | Elements whose `class` attribute contains the word `name`. |
| `#id` | The single element with `id="id"`. |
| `*` | Any element (universal selector — rarely needed explicitly). |

Compound selectors combine these on the same token: `button.primary#submit` matches an element that is a `button`, has class `primary`, and has id `submit`.

## Combinators

| Syntax | Meaning |
|--------|---------|
| `A B` | `B` is a descendant of `A` (any depth). |
| `A > B` | `B` is a direct child of `A`. |
| `A + B` | `B` is the immediately following sibling of `A`. |
| `A ~ B` | `B` is any later sibling of `A`. |

## Attribute selectors

| Syntax | Matches when the attribute… |
|--------|-----------------------------|
| `[attr]` | …is present (any value). |
| `[attr=val]` | …equals `val` exactly. |
| `[attr~=val]` | …is a whitespace-separated word list containing `val`. |
| `[attr^=val]` | …starts with `val`. |
| `[attr$=val]` | …ends with `val`. |
| `[attr*=val]` | …contains `val`. |

Values may be quoted (`"val"` or `'val'`) or unquoted.

## Pseudo-classes

### State pseudos

State pseudos respond to runtime input events. The renderer toggles them via signals on the Godot Control — they don't narrow the DOM match, they route the rule into a separate style bucket that is applied when the state is active.

| Pseudo | Triggered by |
|--------|--------------|
| `:hover` | `mouse_entered` / `mouse_exited` on the control. |
| `:focus` | `focus_entered` / `focus_exited`. |
| `:active` | Parsed and resolved but the renderer does not yet emit activate/deactivate events — rules with `:active` alone never fire at runtime. |
| `:disabled` | Same status as `:active` — parsed, never fires. |
| `:checked` | Parsed and resolved; checkbox state wiring is deferred. |

Combined states work: `button:hover:focus` produces a `_focus+hover` bucket merged on top of the individual buckets when both are active.

### Structural pseudos

Structural pseudos affect which element a rule matches at build time.

| Pseudo | Matches |
|--------|---------|
| `:first-child` | Element that is the first element child of its parent. |
| `:last-child` | Last element child. |
| `:only-child` | Only element child. |
| `:nth-child(An+B)` | Positional: `odd`, `even`, `3`, `2n+1`, `-n+3`, etc. |
| `:not(selector)` | Elements that do not match the inner selector. Combinator arguments inside `:not()` are not supported. |

## Comma lists

A comma separates independent selectors that share the same rule block:

```css
h1, h2, h3 { color: #fff; }
.btn, button { padding: 8px 16px; }
```

## Specificity

The resolver sorts matched rules by `(id count, class+attr+pseudo count, tag count)` in descending order, with source order as a tie-breaker. Higher specificity wins. Structural pseudos contribute to the class count; state pseudos contribute to the class count of the bucket they land in.

## See also

- [../reference/css-properties.md](../reference/css-properties.md) — full property table
- [layout.md](layout.md)
- [transitions.md](transitions.md)
