
<div align="right">
  <details>
    <summary >🌐 Language</summary>
    <div>
      <div align="center">
        <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=en">English</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=zh-CN">简体中文</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=zh-TW">繁體中文</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=ja">日本語</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=ko">한국어</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=hi">हिन्दी</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=th">ไทย</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=fr">Français</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=de">Deutsch</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=es">Español</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=it">Italiano</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=ru">Русский</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=pt">Português</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=nl">Nederlands</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=pl">Polski</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=ar">العربية</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=fa">فارسی</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=tr">Türkçe</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=vi">Tiếng Việt</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=id">Bahasa Indonesia</a>
        | <a href="https://openaitx.github.io/view.html?user=Niekvdm&project=godot-plugins-gtml&lang=as">অসমীয়া</
      </div>
    </div>
  </details>
</div>

# GTML - Godot Markup Language

A Godot 4.x addon that lets you build UI using HTML and CSS. Create game menus, HUDs, and panels with familiar web technologies.

## Features

- HTML-based UI structure with 20+ element types
- External CSS styling with 80+ properties
- Live reload in editor
- Flexbox layout system
- SVG rendering support
- Form elements with signals
- CSS transitions and pseudo-classes (:hover, :active, :focus)
- Gradient backgrounds and custom fonts

## Quick Start

### 1. Install

Copy `addons/gtml/` to your project and enable in **Project Settings → Plugins**.

### 2. Create Files

**menu.html:**
```html
<div class="menu">
    <h1>My Game</h1>
    <button @click="on_play">Play</button>
    <button @click="on_quit">Quit</button>
</div>
```

**menu.css:**
```css
.menu {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 32px;
    background-color: #1a1a2e;
}

h1 {
    font-size: 32px;
    color: #ffffff;
}

button {
    padding: 12px 24px;
    background-color: #00d4ff;
    border-radius: 4px;
    color: #000000;
    transition: background-color 200ms ease;
}

button:hover {
    background-color: #00a8cc;
}
```

### 3. Add GmlView Node

Add a `GmlView` node and set **Html Path** and **Css Path** in the Inspector.

### 4. Connect Signals

```gdscript
func _ready():
    $GmlView.button_clicked.connect(_on_button_clicked)

func _on_button_clicked(method_name: String):
    match method_name:
        "on_play":
            get_tree().change_scene_to_file("res://game.tscn")
        "on_quit":
            get_tree().quit()
```

## Documentation

- [Getting Started](docs/getting-started.md) - Installation and basic usage
- [HTML Elements](docs/html-elements.md) - Supported tags and attributes
- [CSS Properties](docs/css-properties.md) - Complete property reference
- [CSS Selectors](docs/css-selectors.md) - Selectors and pseudo-classes
- [Forms & Inputs](docs/forms-and-inputs.md) - Form elements and events
- [SVG Support](docs/svg-support.md) - Vector graphics
- [Layout & Flexbox](docs/layout-and-flexbox.md) - Layout system
- [Transitions](docs/transitions.md) - CSS transitions
- [Fonts & Typography](docs/fonts-and-typography.md) - Custom fonts
- [Extending GTML](docs/extending-gtml.md) - Add new features
- [Limitations](docs/limitations.md) - Known limitations

## Examples

Check `addons/gtml/examples/` for working demos:
- `basic` - Simple menu
- `all_elements` - All HTML elements
- `css_features` - CSS properties showcase
- `flex_layout` - Flexbox layouts
- `transitions` - CSS transitions

## License

MIT License
