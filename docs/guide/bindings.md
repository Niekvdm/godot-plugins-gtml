# Bindings

*The directive catalog: how markup talks to state.*

## Text interpolation — `{{ expr }}`

Replaces the element's text with the evaluated expression. Re-renders whenever
a dependency key changes.

```html
<span>Score: {{ score }}</span>
<p>Welcome, {{ player.name }}!</p>
<span>{{ qty > 0 ? qty : 'Out of stock' }}</span>
```

## Attribute binding — `:attr="expr"`

Evaluates `expr` and writes the result to the named attribute each time a
dependency changes.

```html
<button :disabled="!has_selection">Use</button>
<img :src="item.icon">
<input :value="prefill_text">
<a :href="doc_url">Docs</a>
```

Supported targets: `disabled`, `value` (LineEdit/TextEdit), `src` (img),
`href` (anchor). Unknown targets are silently warned in the output log.

## Class binding — `:class="expr"`

Three syntaxes — pick the one that fits.

**Object syntax** — toggle class names by condition:

```html
<div :class="{ active: is_selected, disabled: !can_use }">
```

Keys whose evaluated value is truthy are added to the class list.

**Array syntax** — concatenate static and dynamic classes:

```html
<span :class="['badge', rarity]">{{ item.name }}</span>
```

String literals pass through; path expressions resolve from state.

**Bare path** — append a state string as a class name:

```html
<div :class="current_theme">
```

`view.state.set("current_theme", "dark")` adds the class `"dark"`.

**Visual re-resolution (v0.8.2+):** When a `:class` binding changes the
active class set, visual CSS properties (color, background-color,
border-*, opacity, font-size) are recomputed and applied to the element.
Structural properties (display, flex-\*, width, height, padding, margin,
gap, position) are NOT re-resolved — they are fixed at build time.

**Known limitations:**

- Descendant re-resolution from an ancestor's dynamic class is not
  supported. `.card.selected .name { color: X }` does NOT restyle the
  child `.name` when `selected` toggles on the card. Put the `:class`
  (and the selector) on the element you want to restyle, or drive a
  separate state key on the child.
- Hover and dynamic `:class` on the same property: hover wins while
  active; the new dynamic base shows after hover ends.
- `font-family` is not re-resolved by dynamic `:class` (only `font-size`).

## Conditional rendering — `v-if` / `v-show`

`v-if` controls whether the element is built at all. A falsy condition at
render time omits the element and its entire subtree; no bindings are
registered for it. When the key flips true the element is rebuilt fresh.

```html
<div v-if="has_error" class="error-banner">{{ error_msg }}</div>
```

`v-show` keeps the element in the tree but toggles `visible`. Use it for
elements that toggle frequently and have expensive subtrees.

```html
<div v-show="show_detail" class="item-detail">…</div>
```

Both accept full expressions:

```html
<span v-if="hp > 0">Alive</span>
<span v-show="qty > 1">x{{ qty }}</span>
```

## List rendering — `v-for`

Clones the element once per item in the bound array.

```html
<li v-for="item in inventory" @click="select(item)">
  <img :src="item.icon">
  <span :class="['name', item.rarity]">{{ item.name }}</span>
</li>
```

Indexed form — exposes the loop index:

```html
<li v-for="item, i in inventory">
  <span class="slot-number">{{ i }}</span>
  <span>{{ item.name }}</span>
</li>
```

Add `:key="item.id"` (v0.8.1+) for stable Control identity across
reorders and inserts (preserves focus, scroll, in-flight animations):

```html
<li v-for="item in inventory" :key="item.id">…</li>
```

Without `:key` the list is rebuilt by position on every array change — fine
for short stable lists, problematic for drag-reorder or frequent updates.

When `state.set("inventory", new_array)` fires, v-for re-evaluates the
entire clone set. Pass a new Array instance — mutating in place produces
no update (see [Reactivity — immutable-update pattern](reactivity.md)).

## Two-way binding — `v-model`

Binds an input control to a state key in both directions: state writes
into the control; user edits write back to state.

```html
<input v-model="search" placeholder="Search…">
<input type="checkbox" v-model="accept_terms">
<input type="range" min="0" max="100" v-model="volume">
<textarea v-model="bio"></textarea>
<select v-model="difficulty">
  <option value="easy">Easy</option>
  <option value="hard">Hard</option>
</select>
```

A reentry guard prevents the state→control write from triggering another
control→state update.

## Event binding — `@event`

**Bare handler** (no parentheses) — fires `button_clicked` or `link_clicked`:

```html
<button @click="play">Play</button>
<a @click="about">About</a>
```

**Handler with args** — fires `item_clicked(handler, args)`. Args are
evaluated from the current scope at click time:

```html
<li v-for="item in inventory" @click="select(item)">…</li>
<li v-for="item, i in slots" @click="equip(item, i)">…</li>
```

```gdscript
view.item_clicked.connect(func(handler: String, args: Array):
    if handler == "select":
        view.state.set("selected_item", args[0])
    elif handler == "equip":
        _equip(args[0], args[1])
)
```

`@keydown` on inputs fires `key_pressed(handler, event)`:

```html
<input @keydown="search_key" v-model="search">
```

## Expression grammar

Expressions support:

| Form | Example |
|---|---|
| Path | `score`, `player.health`, `item.rarity` |
| Negation | `!is_loading`, `!has_selection` |
| Arithmetic | `hp + shield`, `max_hp * 0.25`, `score % 10` |
| Comparison | `hp > 0`, `score >= 1000`, `qty != 0` |
| Equality | `filter == 'all'`, `selected_item == null` |
| Logical | `has_item && is_identified`, `hp > 0 \|\| shield > 0` |
| Ternary | `qty > 1 ? qty : 'Out of stock'` |
| Indexing | `items[selected_index]`, `items[i].name` |
| String literal | `'all'`, `"common"` |
| Number literal | `0`, `42`, `0.25` |

No function or method calls are supported in expressions. Compute derived
values in GDScript and store them in state:

```gdscript
# In GDScript — computed before storing
view.state.set("is_low_hp", player.hp < player.max_hp * 0.25)
view.state.set("display_name", player.name.to_upper())
```

```html
<!-- In HTML — reads the precomputed key -->
<div :class="{ low: is_low_hp }">
<span>{{ display_name }}</span>
```

**Operator precedence** follows JavaScript/Vue convention (highest → lowest):
unary `! -` → `* / %` → `+ -` → `> < >= <=` → `== !=` → `&&` → `||` →
ternary `?:`. Use parentheses when in doubt.

**Type rules (v0.8+):** operators are strict. `5 + '5'` is null + warning,
not `'55'`. `==` and `!=` allow cross-type comparison without warning (the
`x == null` pattern is common and expected). Division by zero returns null
with a warning.

## See also

- [Reactivity](reactivity.md) — the state model and reconcile loop
- [Forms & inputs](forms-and-inputs.md) — input types, v-model, form submission
- [../reference/gtmlview-api.md](../reference/gtmlview-api.md) — GtmlView API
