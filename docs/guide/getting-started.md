# Getting started

*Install GTML, add a GtmlView node, and build your first HTML-driven UI in Godot 4.*

> ⚠ **API rename in progress.** The addon is **GTML**; its classes are migrating from `Gml*`
> to `Gtml*`. These docs use the target `Gtml*` names. If your installed build still registers
> `GmlView` (i.e. `class_name GmlView`), use that name until the rename ships.

## Installation

1. Copy the `addons/gtml/` folder into your project's `addons/` directory.
2. Open **Project → Project Settings → Plugins** and enable **GTML**.

## Add a GtmlView node

1. In a scene, add a **GtmlView** node (search "GtmlView" in the node picker).
2. Size and anchor it as you would any `Control` — it fills its parent by default.
3. In the Inspector, set **Html Path** to an `.html` file and (optionally) **Css Path** to a `.css` file.

GtmlView rebuilds the Control tree whenever those files change on disk (editor) or on `_ready` (runtime).

## Your first view

Create `res://ui/main_menu/menu.html`:

```html
<div class="menu">
  <h1>My Game</h1>
  <button @click="play">Play</button>
  <button @click="settings">Settings</button>
  <button @click="quit">Quit</button>
</div>
```

Create `res://ui/main_menu/menu.css`:

```css
.menu {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 48px;
  background-color: #1a1a2e;
}

h1 {
  color: #e0e0ff;
  font-size: 40px;
}

button {
  background-color: #16213e;
  color: #e0e0ff;
  padding: 12px 24px;
  border-radius: 6px;
  border: 1px solid #4a4a8a;
}

button:hover {
  background-color: #4a4a8a;
}
```

Attach a script to the parent node (the one that holds the GtmlView):

```gdscript
extends Control

@onready var view: GtmlView = $GtmlView

func _ready() -> void:
    view.button_clicked.connect(_on_button_clicked)

func _on_button_clicked(method_name: String) -> void:
    match method_name:
        "play":
            get_tree().change_scene_to_file("res://game/game.tscn")
        "settings":
            $SettingsDialog.show()
        "quit":
            get_tree().quit()
```

Assign `menu.html` and `menu.css` to the GtmlView Inspector fields, run the scene, and the three buttons appear with CSS styles applied. Click **Play** — `button_clicked` fires with `method_name = "play"`.

## Signals at a glance

| Signal | When |
|---|---|
| `button_clicked(method_name)` | `@click="handler"` (no parentheses) |
| `link_clicked(href)` | `<a href="…">` clicked |
| `input_changed(input_id, value)` | text/checkbox/range input edited |
| `selection_changed(select_id, value)` | `<select>` option changed |
| `form_submitted(form_data)` | `<input type="submit">` clicked |
| `key_pressed(handler, event)` | `@keydown="handler"` key event |
| `item_clicked(handler, args)` | `@click="handler(args)"` (with parentheses) |

## Inspector exports

| Export | Purpose |
|---|---|
| `html_path` | Path to the HTML file |
| `css_path` | Path to the CSS file (optional) |
| `auto_reload_in_editor` | Hot-reload on file change (default: true) |
| `show_nodes_in_editor` | Show generated nodes in Scene dock |
| `fonts` | Dictionary mapping font-family names to Font resources |
| `h1_font_size` … `p_font_size` | Default heading/paragraph sizes |
| `default_font_color` | Fallback text color |
| `default_gap`, `default_margin`, `default_padding` | Layout defaults |

## Next steps

Read [Reactivity](reactivity.md) to make the UI data-driven.

## See also

- [Reactivity](reactivity.md) — state, bindings, the reconcile loop
- [Bindings](bindings.md) — directive catalog and expression grammar
- [../reference/gtmlview-api.md](../reference/gtmlview-api.md) — full API reference
