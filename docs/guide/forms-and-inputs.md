# Forms & inputs

*Input types, two-way binding, form submission, and keyboard events.*

## Input types

| HTML | Godot Control | Signal |
|---|---|---|
| `<input>` / `<input type="text">` | LineEdit | `input_changed` |
| `<input type="password">` | LineEdit (secret) | `input_changed` |
| `<input type="email">` | LineEdit | `input_changed` |
| `<input type="number">` | LineEdit (numeric filter) | `input_changed` |
| `<input type="checkbox">` | CheckBox | `input_changed` |
| `<input type="radio" name="…">` | CheckBox in ButtonGroup | `input_changed` |
| `<input type="range">` | HSlider | `input_changed` |
| `<input type="submit">` | Button | `form_submitted` |
| `<textarea>` | TextEdit | `input_changed` |
| `<select>` | OptionButton | `selection_changed` |

The `input_changed` signal carries the input's `id` (or `name` as fallback)
and the new value as a string. `selection_changed` carries the `select`
element's `id`/`name` and the selected item's `value` attribute.

## Two-way binding with v-model

`v-model` keeps a state key and an input control in sync:

```html
<input v-model="player_name" placeholder="Enter name">
<input type="checkbox" v-model="sound_enabled">
<input type="range" min="0" max="100" v-model="volume">
<textarea v-model="bio"></textarea>
<select v-model="difficulty">
  <option value="easy">Easy</option>
  <option value="normal">Normal</option>
  <option value="hard">Hard</option>
</select>
```

```gdscript
view.state.set("player_name", "Ada")
view.state.set("sound_enabled", true)
view.state.set("volume", 80.0)
view.state.set("difficulty", "normal")
```

State drives the control on initial render and on every subsequent
`state.set`. User edits write back to state immediately. A reentry guard
prevents infinite loops: the state→control write compares before writing,
so the control's signal does not bounce back.

**`v-model` value types by control:**

| Control | State type |
|---|---|
| LineEdit / TextEdit | String |
| CheckBox (no group) | bool |
| CheckBox (radio) | String (the `value` attribute, only when pressed) |
| HSlider | float |
| OptionButton | String (selected item text) |

## Static initial values

Use `value`, `checked`, and `selected` HTML attributes to set the initial
state without a `state.set` call. These are applied at build time:

```html
<input type="text" id="search" value="default query">
<input type="checkbox" id="agree" checked>
<input type="range" id="vol" min="0" max="100" value="75">
<select id="lang">
  <option>English</option>
  <option selected>Français</option>
</select>
```

## The :checked pseudo-class in CSS

Style a checkbox or radio's pressed state with `:checked`:

```css
input[type="checkbox"]:checked {
  background-color: #4a90e2;
  border-color: #4a90e2;
}
```

This maps to Godot's `"pressed"` stylebox theme slot.

## Keyboard events with @keydown

Add `@keydown="handler"` to a text input. Every key-down event fires
`key_pressed(handler, event)` on the view, where `event` is an
`InputEventKey`:

```html
<input id="search" @keydown="search_key" v-model="search">
```

```gdscript
view.key_pressed.connect(func(handler: String, event: InputEvent):
    if handler == "search_key":
        if event is InputEventKey:
            var key_event := event as InputEventKey
            if key_event.keycode == KEY_ESCAPE:
                view.state.set("search", "")
                view.state.set("results", [])
)
```

`@keydown` is supported on `<input>` (text variants) only; it is wired at
the LineEdit's `gui_input` level and filters to key-down events.

## Form submission

### With the submit button

Place a `<button type="submit">` (or `<input type="submit">`) inside a
form. When clicked it emits `form_submitted(form_data)` with a snapshot of
all registered inputs:

```html
<form>
  <input id="username" placeholder="Username">
  <input id="password" type="password" placeholder="Password">
  <input type="submit" value="Log in">
</form>
```

```gdscript
view.form_submitted.connect(func(data: Dictionary):
    # data == {"username": "Ada", "password": "…"}
    _attempt_login(data["username"], data["password"])
)
```

### Manual snapshot

Call `view.get_form_data()` at any point to collect the current input
values without waiting for submission:

```gdscript
var snapshot := view.get_form_data()
```

`get_form_data()` returns:

- LineEdit / TextEdit → String
- CheckBox (no group) → bool
- CheckBox in a ButtonGroup (radio) → the selected radio's `value` attribute,
  keyed by the group's `name`; unselected radios are absent
- HSlider → float
- OptionButton → the selected item text

## Radio groups

Radio inputs share a `ButtonGroup` when they have the same `name`
attribute. Only one can be pressed at a time:

```html
<input type="radio" name="difficulty" value="easy">Easy
<input type="radio" name="difficulty" value="normal" checked>Normal
<input type="radio" name="difficulty" value="hard">Hard
```

`get_form_data()` returns `{ "difficulty": "normal" }` (the value of the
selected radio, keyed by the group name).

Retrieve the ButtonGroup for programmatic control:

```gdscript
var group := view.get_radio_group("difficulty")
```

## Listening to individual changes

```gdscript
view.input_changed.connect(func(input_id: String, value: String):
    if input_id == "search":
        view.state.set("results", _search(value))
)

view.selection_changed.connect(func(select_id: String, value: String):
    if select_id == "filter":
        view.state.set("category", value)
)
```

`input_changed` fires on every keystroke for text inputs. If you need
debouncing, apply it in GDScript before calling `state.set`.

## See also

- [Bindings](bindings.md) — directive catalog and expression grammar
- [../reference/gtmlview-api.md](../reference/gtmlview-api.md) — GtmlView API
