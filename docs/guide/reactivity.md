# Reactivity

*How GtmlView's state store drives the UI — set a value, only affected nodes re-render.*

## The model

`view.state` is the single source of truth for a GtmlView. HTML bindings
declare which state keys they depend on; when a key changes, only the
Controls bound to that key are updated. You never touch individual nodes —
you set state and the view catches up.

```gdscript
view.state.set("score", 0)       # initial write
view.state.set("score", 42)      # label re-renders; nothing else changes
```

State keys are plain strings. Dotted paths (`"player.health"`) are flat
keys in the store — they are not nested dictionaries.

## A minimal HUD

```html
<div class="hud">
  <span id="score-label">Score: {{ score }}</span>
  <div class="hp-bar">
    <div class="hp-fill" :style-width="hp_pct"></div>
  </div>
  <span v-show="is_low_hp" class="low-hp-warning">Low HP!</span>
</div>
```

```gdscript
extends Control

@onready var view: GtmlView = $GtmlView

func _ready() -> void:
    view.state.set("score", 0)
    view.state.set("hp_pct", 1.0)
    view.state.set("is_low_hp", false)

func add_score(points: int) -> void:
    view.state.set("score", view.state.get("score") + points)

func set_hp(hp: float, max_hp: float) -> void:
    var pct := hp / max_hp
    view.state.set("hp_pct", pct)
    view.state.set("is_low_hp", pct < 0.25)
```

Calling `add_score(10)` re-renders only the score label. Calling `set_hp`
updates the two hp keys; the bar width and warning visibility flip
accordingly.

## The reconcile loop

```
view.state.set("score", 42)
  → state store records new value, captures old
  → emits state_changed("score", 42, old)
  → binding registry fires bindings registered to "score"
       → iterates bindings registered to "score"
       → for each live Control: re-evaluates the expression, writes result
       → invalid (freed) bindings pruned in the same pass
```

For `set_state({...})` batches: all key changes are collected first, then
each affected binding fires exactly once — an interpolation like
`{{ a }} {{ b }}` does not re-render twice in a single batch.

v-for lists reconcile by key on collection change: clones are torn down
and rebuilt from the new array. Use `:key="item.id"` (v0.8.1+) to
preserve Control identity (focus, scroll, in-flight animations) across
reorders and inserts.

## Immutable-update pattern

The state store uses **identity comparison** for arrays and dictionaries.
Mutating a collection in-place does not fire `state_changed` because the
reference has not changed:

```gdscript
# WRONG — no change detected, no re-render
var items = view.state.get("items")
items.append(new_item)              # same Array object, identity unchanged

# CORRECT — new Array instance triggers the binding
view.state.set("items", view.state.get("items") + [new_item])
```

The same applies to dictionaries: replace them with a new Dictionary
rather than mutating fields.

```gdscript
# WRONG
view.state.get("player")["health"] = 80

# CORRECT
var p: Dictionary = view.state.get("player").duplicate()
p["health"] = 80
view.state.set("player", p)
```

Why: the state store's equality check short-circuits on equal type +
identity. When you pass in the same container instance the equality check
passes and the signal is never emitted.

## State vs bare signals

Use `state` for anything the UI displays or reacts to. Use bare `@click`
→ `button_clicked` for one-off actions (navigate to a scene, open a
dialog) where there is no data to mirror.

| Use case | Mechanism |
|---|---|
| Score, HP, ammo — UI reads it | `state.set` + `{{ }}` / `:attr` binding |
| Inventory list | `state.set("items", [...])` + `v-for` |
| "Play" button → change scene | `@click="play"` → `button_clicked` |
| Form value read once on submit | `form_submitted` signal |

## Listening to state changes from GDScript

```gdscript
view.state.state_changed.connect(func(key, new_value, old_value):
    if key == "search":
        view.state.set("filtered_items", _filter(new_value))
)
```

`GtmlView` also re-emits this signal directly:

```gdscript
view.state_changed.connect(_on_state_changed)
```

Both forms are equivalent; use whichever fits your code organization.

## See also

- [Bindings](bindings.md) — directive catalog and expression grammar
- [../reference/gtmlview-api.md](../reference/gtmlview-api.md) — GtmlView API
