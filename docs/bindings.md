# Reactive bindings (v0.7+)

GTML supports Vue-style reactive bindings so dynamic UIs (HUDs,
inventories, leaderboards, dialog trees) don't require per-element
GDScript glue. You declare the data flow in HTML; your game code only
updates state.

## The 30-second example

```html
<h1>Welcome, {{ player.name }}!</h1>
<ul>
  <li v-for="item in inventory" @click="select(item)">
    <img :src="item.icon">
    <span>{{ item.name }}</span>
    <span v-show="item.qty">x{{ item.qty }}</span>
  </li>
</ul>
<button :disabled="!selected_item">Use</button>
```

```gdscript
@onready var view: GmlView = $GmlView

func _ready() -> void:
    view.state.set("player.name", "Ada")
    view.state.set("inventory", load_inventory())
    view.state.set("selected_item", null)
    view.item_clicked.connect(_on_item_clicked)

func _on_item_clicked(handler: String, args: Array) -> void:
    if handler == "select":
        view.state.set("selected_item", args[0])
```

## The state object

Every `GmlView` has a `state: GmlState` field. Read with
`view.state.get(key)`, write with `view.state.set(key, value)`. State
persists across HTML/CSS hot-reloads.

```gdscript
view.state.set("score", 42)
view.state.set("player.health", 85)        # dotted paths are keys
view.state.set_state({"a": 1, "b": 2})     # batch update
print(view.state.get("score"))             # 42
```

`set()` short-circuits if the new value equals the old one, so
re-renders only fire when values actually change.

## Directive reference

### `{{ expr }}` — text interpolation

```html
<h1>Welcome, {{ name }}!</h1>
<span>HP: {{ player.health }}/{{ player.max_health }}</span>
```

Substitutes at render and on every change to a referenced state key.
Works in any text node.

### `:attr="key"` — attribute binding (v-bind shorthand)

```html
<button :disabled="locked">Save</button>
<input :value="name">
<img :src="icon_path">
<a :href="link_url">link</a>
```

Reads the key from state on render and on every change. Supported
targets in v0.7: `disabled`, `value`, `src`, `href`. Unknown targets
emit a warning.

### `:class="..."` — class binding

Three forms:

```html
<!-- Bare key: state.get("dyn") is a string -->
<div :class="dyn">

<!-- Object: keys are class names, values must be truthy to apply -->
<div :class="{ active: is_active, dim: !is_active }">

<!-- Array: mix literals + dynamic -->
<div :class="['static', dynamic_class_name]">
```

**Limitation in v0.7**: `:class` stores the dynamic class list on the
control's `dynamic_classes` meta but does NOT re-resolve CSS rules.
Styles declared on classes present at build time work normally; dynamic
class addition does not pull in new styles. Workaround: declare all
possible classes at build time and use `v-show` / `v-if` to swap.

### `v-if="expr"` — conditional rendering

```html
<div v-if="show_panel">...</div>
<div v-if="!loading">...</div>
```

When the expression is falsy, the element (and all its children) is
omitted from the tree. On state change, the parent rebuilds.

### `v-show="expr"` — conditional visibility

```html
<div v-show="show_panel">...</div>
```

Element stays in the tree; `visible` flips. Cheaper than `v-if` for
elements that toggle frequently.

### `v-for="item in items"` — list rendering

```html
<ul>
  <li v-for="entry in inventory">{{ entry.name }}</li>
</ul>
```

With index:

```html
<li v-for="entry, i in inventory">{{ i }}: {{ entry.name }}</li>
```

On state change to the bound array, all children of the v-for parent
are torn down and rebuilt. For typical game inventories (<100 items)
this is fast enough. Keyed reconciliation (`:key="entry.id"`) is
planned for a future release.

### `v-model="key"` — two-way input binding

```html
<input v-model="search">                          <!-- LineEdit -->
<input type="checkbox" v-model="opt_in">          <!-- CheckBox -->
<input type="range" v-model="volume">             <!-- HSlider -->
<select v-model="size">...</select>               <!-- OptionButton -->
```

State changes update the control; user edits update state. The
state-to-control direction is guarded by an equality check so the
control's `*_changed` signal can't feed back into state.

### `@event="handler(args)"` — events with arguments

```html
<li v-for="item in items" @click="select(item)">...</li>
<button @click="confirm('save', form_data)">Save</button>
```

Fires `view.item_clicked(handler: String, args: Array)`. Args are
re-evaluated at click time so they reflect current state. Bare
`@click="handler"` (no parens) continues to fire `button_clicked(handler)`
as in earlier versions.

## Expression grammar

`{{ ... }}`, `:attr="..."`, `v-if="..."`, `v-show="..."`, `v-model="..."`
accept a path (with optional `!` negation):

- `key`
- `nested.key.path`
- `!key`
- `!nested.key`

`:class` and `@event` additionally accept object literals, array
literals, and call expressions. Full grammar:

```
Expr     := Path | NegPath | ObjectLit | ArrayLit | CallExpr | StringLit
Path     := Ident ('.' Ident)*
NegPath  := '!' Path
ObjectLit:= '{' (Ident ':' Expr (',' Ident ':' Expr)*)? '}'
ArrayLit := '[' (Expr (',' Expr)*)? ']'
CallExpr := Ident '(' (Expr (',' Expr)*)? ')'
StringLit:= "'…'" | '"…"'
```

**Not supported**: arithmetic, comparison, string concat, ternaries. If
you need a computed value, compute it in GDScript and
`view.state.set("is_complex", ...)`.

## Loop scope

Inside a `v-for`, the loop variable shadows global state on key
collision:

```html
<li v-for="item in items">{{ item.name }}</li>
```

`item.name` reads from the loop variable, not from a global `item` key.

## See also

- [Getting started](getting-started.md)
- The `inventory/` showcase sample demonstrates every directive
  end-to-end.
