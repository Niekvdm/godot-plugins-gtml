# GTML — Godot Markup Language

Build Godot 4 UI with HTML, CSS, and a **Vue-style reactive layer**. Declare
your interface in markup, drive it from game state, and let GTML keep the
Control tree in sync — menus, HUDs, inventories, leaderboards, and dialog
trees without per-element GDScript glue.

> ⚠ **API rename in progress.** The addon is **GTML**; its classes are migrating from `Gml*` to `Gtml*`. These docs use the target `Gtml*` names. If your installed build still registers `GmlView`, use that name until the rename ships.

```html
<ul>
  <li v-for="item in inventory" :key="item.id" @click="select(item)"
      :class="{ rare: item.rarity == 'rare' }">
    <span>{{ item.name }}</span>
    <span v-show="item.qty > 1">x{{ item.qty }}</span>
  </li>
</ul>
<button :disabled="!has_selection">Use</button>
```

```gdscript
@onready var view: GtmlView = $GtmlView

func _ready() -> void:
    view.state.set("inventory", load_inventory())
    view.state.set("has_selection", false)
    view.item_clicked.connect(func(handler, args):
        if handler == "select":
            view.state.set("has_selection", true))
```

Call `view.state.set(...)` and the DOM updates itself — reorder the array and
focused inputs keep focus, only the changed rows re-render.

## Why GTML

- **Reactive bindings** — `{{ }}` interpolation, `:attr`, `:class`, `v-if`,
  `v-show`, `v-for`, `v-model`, `@event(args)`. State in, UI out.
- **Real expressions** — arithmetic, comparison, logical, ternary, indexing
  inside bindings: `:class="{ low: hp < max_hp * 0.25 }"`,
  `{{ items[selected].name }}`.
- **Keyed list reconciliation** — `v-for :key` preserves Control identity
  (focus / scroll / animation) across reorders; a single-item change touches
  ~constant work, not a full rebuild.
- **Live CSS re-resolution** — toggling a dynamic `:class` actually restyles
  the element (color, background, border, opacity, font-size) in place.
- **Keyboard & gamepad ready** — automatic focus traversal, HTML `tabindex`,
  `autofocus`, `focus-trap` for modals. Works on console / Steam Deck.
- **The web you know** — 20+ HTML elements, 80+ CSS properties, flexbox,
  `var()`/`calc()` tokens, transforms, transitions, `:hover`/`:focus`/
  `:checked`, gradients, custom fonts, SVG.
- **Editor-native** — live reload, autocomplete, jump-to-definition, color
  picker, multi-cursor.

## Install

Copy `addons/gtml/` into your project and enable it in
**Project Settings → Plugins**. Add a `GtmlView` node and set its
**Html Path** + **Css Path** in the Inspector.

## Quick start — reactive

**hud.html**
```html
<div class="hud">
  <span class="score">Score: {{ score }}</span>
  <div class="bar" :class="{ low: hp < 25 }">HP {{ hp }}/{{ max_hp }}</div>
  <input v-model="player_name" autofocus>
</div>
```

**hud.css**
```css
.hud { display: flex; flex-direction: column; gap: 12px; padding: 24px; background-color: #14161f; }
.score { color: #fff; font-size: 18px; }
.bar { color: #8fe; }
.bar.low { color: #f55; }
```

**hud.gd**
```gdscript
@onready var view: GtmlView = $GtmlView

func _ready() -> void:
    view.state.set_state({ "score": 0, "hp": 100, "max_hp": 100, "player_name": "Ada" })

func add_score(points: int) -> void:
    view.state.set("score", view.state.get("score") + points)

func take_damage(dmg: int) -> void:
    view.state.set("hp", max(0, view.state.get("hp") - dmg))   # bar turns red under 25
```

No node lookups, no `.text =` assignments — set state, the view reacts. When
`hp` drops below 25 the `low` class applies and the bar restyles live.

## Quick start — static (the simple case)

For a plain menu you don't even need state — bare `@click` fires a signal:

```html
<div class="menu">
  <h1>My Game</h1>
  <button @click="play">Play</button>
  <button @click="quit">Quit</button>
</div>
```

```gdscript
func _ready() -> void:
    $GtmlView.button_clicked.connect(func(handler):
        match handler:
            "play": get_tree().change_scene_to_file("res://game.tscn")
            "quit": get_tree().quit())
```

`@click="handler"` (no parens) fires `button_clicked(handler)`;
`@click="handler(args)"` fires `item_clicked(handler, args)` with the
arguments resolved from the current scope (e.g. the `v-for` item).

## Examples

Crafted demos live in `addons/gtml/examples/showcase/` — open any
`demo.tscn` and press Play:

| Demo | What it shows |
|---|---|
| **inventory** | The reactive flagship — `state`, `{{ }}`, `v-for :key`, `:class`, `v-model`, `@click(item)`, with a real `demo.gd` game script |
| **atlas** | Dashboard layout (flex-heavy) |
| **atelier** | Editorial reader (typography + design tokens) |
| **forge** | Settings panel (`:hover`/`:focus` transitions) |
| **kitchen** | Kitchen-sink reference (nearly every element + CSS property) |

## Documentation

Full docs: **[docs/index.md](docs/index.md)**

- [Getting started](docs/guide/getting-started.md) — install + your first view
- [Reactivity](docs/guide/reactivity.md) — the state → bindings model
- [Bindings](docs/guide/bindings.md) — `{{ }}`, `:class`, `v-for`, `v-model`, `@event`, expressions
- [Focus & navigation](docs/guide/focus.md) — keyboard / gamepad
- [GtmlView API](docs/reference/gtmlview-api.md) — state, signals, methods, exports

## License

MIT License
