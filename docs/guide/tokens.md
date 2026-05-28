# Tokens

_Define reusable values with custom properties and compute expressions with `calc()`._

```css
:root {
  --accent: #4a9eff;
  --panel-pad: 12px;
}
.card { padding: var(--panel-pad); border-color: var(--accent); }
.title { font-size: calc(var(--base-size) + 4px); }
```

## Custom properties

A custom property starts with `--`. Declare it anywhere in your CSS; the resolver inherits values from ancestor elements down to descendants, so a property set on a parent element is visible in all of its children.

```css
.hud {
  --surface: #1a1a2e;
  --text: #e0e0ff;
}
.hud .panel { background-color: var(--surface); color: var(--text); }
```

Custom properties are stored as raw strings. The resolved (substituted) value is re-parsed through the normal property type pipeline, so `var(--panel-pad)` in a `padding` context produces an integer the same way a literal `12px` would.

## `var()`

```
var(--name)
var(--name, fallback)
```

- If `--name` is defined in scope, its value is substituted.
- If `--name` is not defined and a fallback is provided, the fallback string is used instead.
- If `--name` is not defined and there is no fallback, the property resolves to an empty value and a warning is emitted.

Cycle detection is built in: a `var()` that references itself (directly or through a chain) breaks the cycle at re-entry and warns.

## `calc()`

Evaluates a flat arithmetic expression:

```
calc(<value> <op> <value> [<op> <value> ...])
```

Supported operators: `+`, `-`, `*`, `/`.

Operator precedence: `*` and `/` are evaluated first (left-to-right), then `+` and `-` (left-to-right). Nested parentheses inside a `calc()` body are not supported — only the outer `calc(...)` delimiters are recognised.

Values carry an optional unit (`px`, `%`, or other identifiers). Unit rules:

- `+` and `-` require both operands to share the same unit, or for one to be unitless.
- `*` and `/` allow at most one operand to carry a unit.
- Division by a unit-bearing value is rejected with a warning.
- Division by zero is rejected with a warning.

```css
.banner { width: calc(100% - 32px); }    /* mixed: not supported, leaves raw */
.icon   { width: calc(16px * 2); }       /* → 32px ✔ */
.gap    { gap: calc(4px + 8px); }        /* → 12 ✔ */
```

Note: mixing `%` and `px` in a single `+`/`-` operation (e.g. `100% - 32px`) is rejected by the unit rule and left as the raw string.

## `var()` + `calc()` together

`var()` substitution runs first, then `calc()` evaluation. You can nest both:

```css
:root { --base: 16px; }
h2 { font-size: calc(var(--base) * 1.5); }   /* → 24px */
```

## See also

- [../reference/css-properties.md](../reference/css-properties.md) — full property table
