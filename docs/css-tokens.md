# CSS Tokens — custom properties, `var()`, `calc()`

GTML supports CSS custom properties as design tokens, with cascading
inheritance just like the browser engine. They compose with `calc()` for
derived dimensions.

> **Added in v0.4.** Implementation lives in
> `addons/gtml/src/css/GmlCssEval.gd`.

## Custom property declarations

Any selector can declare a custom property with the `--` prefix:

```css
.app {
    --brand: #5fc8ff;
    --gap-md: 16px;
    --gap-lg: 32px;
}
```

The declaration is stored as a raw string. Children of the matched element
inherit the value through the cascade, just like the browser.

There is no special `:root` selector in GTML — the topmost element of your
HTML doubles as `:root`. Most samples put their palette on the outer
`.app` / `.page` selector.

## Reading a property with `var()`

```css
.button {
    background-color: var(--brand);
    padding: var(--gap-md);
}
```

`var()` resolution happens at compute-style time. The resolver walks the
DOM and threads a `scope` dict through each node; the scope is the
ancestor cascade plus the node's own declarations.

### Fallback

`var(--name, fallback)` uses the fallback when the variable isn't in scope:

```css
.button {
    color: var(--brand-text, white);
}
```

The fallback can itself contain `var()` — resolution recurses.

### Cycle detection

If a variable references itself (directly or via a chain
`--a → --b → --a`), the resolver breaks the cycle, emits a `push_warning`,
and treats the value as initial (empty string). The CSS spec's
"invalid → initial" semantic.

## `calc()` arithmetic

`calc()` evaluates a flat arithmetic expression with `+`, `-`, `*`, `/`
and standard precedence:

```css
.sidebar {
    width: calc(100px + 16px * 2);   /* -> 132px */
    height: calc(var(--row) * 4);    /* uses scope */
}
```

### Unit rules

| Operator | Rule |
|---|---|
| `+`, `-` | Both operands must share the same unit (or both be unitless) |
| `*`, `/` | At most one operand may carry a unit |

Mixing units in an addition (like `calc(100% - 16px)` in current GTML)
emits a `push_warning` and leaves the substring as-is. Pure arithmetic
on unitless numbers and same-unit additions both work cleanly.

### Composition with `var()`

`var()` resolution runs before `calc()`, so this:

```css
.app { --base: 16; }
.row { padding: calc(var(--base) * 2); }   /* -> 32 */
```

…evaluates as `calc(16 * 2)` after substitution and yields `32`.

## Bucket-local declarations (limitation)

Custom properties declared inside a state bucket are NOT yet added to that
bucket's scope:

```css
p:hover { --x: red; color: var(--x); }   /* -> :hover bucket gets no --x */
```

The bucket's `var(--x)` resolves against the base scope. Workaround: put
the `--x` on a non-hover selector that the same element matches.

## Why use them

- Single source of truth for palettes — re-brand by editing one block
- Derived values stay in sync (`calc(var(--gap-md) * 2)` updates with
  `--gap-md`)
- Document intent through naming (`--accent` reads better than `#5fc8ff`)

See `addons/gtml/examples/showcase/atlas/style.css` for a real palette
that uses the pattern throughout.
