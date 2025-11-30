# Forms and Inputs

GTML supports HTML form elements for creating interactive UI. This guide covers input types, form handling, and styling.

## Input Types

### Text Input

Standard single-line text input.

```html
<input type="text" id="username" placeholder="Enter username">
```

**Godot Control:** LineEdit

### Password Input

Text input with masked characters.

```html
<input type="password" id="password" placeholder="Enter password">
```

**Godot Control:** LineEdit (with secret mode)

### Email Input

Text input for email addresses (functions as text input).

```html
<input type="email" id="email" placeholder="email@example.com">
```

**Godot Control:** LineEdit

### Number Input

Text input that only accepts numeric values.

```html
<input type="number" id="age" placeholder="Enter age">
```

**Godot Control:** LineEdit (with number filter)

### Checkbox

Toggle checkbox input.

```html
<input type="checkbox" id="remember">
<label for="remember">Remember me</label>

<input type="checkbox" id="agree" checked>
<label for="agree">I agree to terms</label>
```

**Attributes:**
- `checked` - Pre-checked state (boolean attribute)

**Godot Control:** CheckBox

### Radio Buttons

Radio buttons are automatically grouped by the `name` attribute:

```html
<div class="radio-group">
    <input type="radio" name="difficulty" id="easy" value="easy" checked>
    <label for="easy">Easy</label>

    <input type="radio" name="difficulty" id="normal" value="normal">
    <label for="normal">Normal</label>

    <input type="radio" name="difficulty" id="hard" value="hard">
    <label for="hard">Hard</label>
</div>
```

**Attributes:**
- `name` - Group name (radios with same name are mutually exclusive)
- `value` - Value emitted when selected
- `checked` - Pre-selected option

**Godot Control:** CheckBox (in ButtonGroup)

### Range Slider

Slider input for numeric ranges.

```html
<input type="range" id="volume" min="0" max="100" value="75">
<input type="range" id="brightness" min="0" max="1" step="0.1" value="0.5">
```

**Attributes:**
- `min` - Minimum value (default: 0)
- `max` - Maximum value (default: 100)
- `step` - Step increment (default: 1)
- `value` - Initial value

**Godot Control:** HSlider

### Submit Button

Submit button for forms.

```html
<input type="submit" value="Submit">
```

**Godot Control:** Button

## Textarea

Multi-line text input.

```html
<textarea id="description" rows="5" cols="40" placeholder="Enter description..."></textarea>
```

**Attributes:**
- `id` / `name` - Element identifier
- `rows` - Visible rows (default: 4)
- `cols` - Visible columns (default: 20)
- `placeholder` - Placeholder text

**Godot Control:** TextEdit

## Select (Dropdown)

Dropdown selection with options.

```html
<select id="country">
    <option value="us">United States</option>
    <option value="uk">United Kingdom</option>
    <option value="ca" selected>Canada</option>
    <option value="au">Australia</option>
</select>
```

**Select Attributes:**
- `id` / `name` - Element identifier

**Option Attributes:**
- `value` - Option value (defaults to text content if omitted)
- `selected` - Pre-selected option (boolean attribute)

**Godot Control:** OptionButton

## Form Container

Group form elements in a form container:

```html
<form class="login-form">
    <div class="form-group">
        <label for="username">Username</label>
        <input type="text" id="username" placeholder="Enter username">
    </div>

    <div class="form-group">
        <label for="password">Password</label>
        <input type="password" id="password" placeholder="Enter password">
    </div>

    <div class="form-group">
        <input type="checkbox" id="remember">
        <label for="remember">Remember me</label>
    </div>

    <button type="submit" @click="on_login">Login</button>
</form>
```

## Event Handling

### Input Changes

Connect to the `input_changed` signal:

```gdscript
func _ready():
    $GmlView.input_changed.connect(_on_input_changed)

func _on_input_changed(input_id: String, value: String):
    match input_id:
        "username":
            print("Username: ", value)
        "volume":
            AudioServer.set_bus_volume_db(0, linear_to_db(float(value) / 100.0))
        "remember":
            # Checkbox: value is "true" or "false"
            var checked = value == "true"
            print("Remember: ", checked)
```

### Selection Changes

Connect to the `selection_changed` signal:

```gdscript
func _ready():
    $GmlView.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(select_id: String, value: String):
    match select_id:
        "country":
            print("Selected country: ", value)
        "difficulty":
            set_difficulty(value)
```

### Form Submission

Connect to the `form_submitted` signal:

```gdscript
func _ready():
    $GmlView.form_submitted.connect(_on_form_submitted)

func _on_form_submitted(form_data: Dictionary):
    print("Form data: ", form_data)
    # form_data contains all input values by ID
```

## Label Association

Use the `for` attribute to associate labels with inputs:

```html
<label for="username">Username:</label>
<input type="text" id="username">
```

Clicking the label will focus the associated input.

## Styling Form Elements

### Basic Styling

```css
input, textarea, select {
    background-color: #1a1a28;
    border: 1px solid #3a3a5e;
    border-radius: 6px;
    padding: 10px;
    color: #ddddee;
    font-size: 14px;
}

input:focus, textarea:focus, select:focus {
    border-color: #00d4ff;
    background-color: #1e1e2e;
}
```

### Checkbox Styling

```css
input[type="checkbox"] {
    /* Checkboxes have limited styling */
    /* Use background-color for the box */
}
```

### Range Slider Styling

```css
input[type="range"] {
    background-color: #3a3a5e;  /* Track color */
    color: #00d4ff;             /* Filled area color */
}
```

### Disabled State

```css
input:disabled, textarea:disabled, select:disabled {
    background-color: #2a2a2a;
    color: #666666;
    cursor: not-allowed;
}
```

## Complete Form Example

### HTML

```html
<form class="settings-form">
    <h2>Settings</h2>

    <div class="form-group">
        <label for="player-name">Player Name</label>
        <input type="text" id="player-name" placeholder="Enter name">
    </div>

    <div class="form-group">
        <label>Difficulty</label>
        <select id="difficulty">
            <option value="easy">Easy</option>
            <option value="normal" selected>Normal</option>
            <option value="hard">Hard</option>
        </select>
    </div>

    <div class="form-group">
        <label for="volume">Master Volume</label>
        <input type="range" id="volume" min="0" max="100" value="75">
    </div>

    <div class="form-group checkbox-group">
        <input type="checkbox" id="fullscreen">
        <label for="fullscreen">Fullscreen</label>
    </div>

    <div class="form-group checkbox-group">
        <input type="checkbox" id="vsync" checked>
        <label for="vsync">VSync</label>
    </div>

    <div class="form-group">
        <label>Graphics Quality</label>
        <div class="radio-group">
            <input type="radio" name="quality" id="low" value="low">
            <label for="low">Low</label>
            <input type="radio" name="quality" id="medium" value="medium" checked>
            <label for="medium">Medium</label>
            <input type="radio" name="quality" id="high" value="high">
            <label for="high">High</label>
        </div>
    </div>

    <div class="buttons">
        <button @click="on_save">Save</button>
        <button @click="on_cancel" class="secondary">Cancel</button>
    </div>
</form>
```

### CSS

```css
.settings-form {
    display: flex;
    flex-direction: column;
    gap: 20px;
    padding: 24px;
    background-color: #1a1a2e;
    border-radius: 8px;
    width: 400px;
}

h2 {
    font-size: 24px;
    color: #ffffff;
    margin-bottom: 8px;
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.checkbox-group {
    flex-direction: row;
    align-items: center;
}

.radio-group {
    display: flex;
    flex-direction: row;
    gap: 16px;
}

label {
    font-size: 14px;
    color: #aaaacc;
}

input, textarea, select {
    background-color: #2a2a3e;
    border: 1px solid #3a3a5e;
    border-radius: 4px;
    padding: 10px;
    color: #ffffff;
    font-size: 14px;
}

input:focus, textarea:focus, select:focus {
    border-color: #00d4ff;
}

.buttons {
    display: flex;
    flex-direction: row;
    gap: 12px;
    justify-content: flex-end;
    margin-top: 16px;
}

button {
    padding: 10px 20px;
    background-color: #00d4ff;
    border-radius: 4px;
    color: #000000;
    font-size: 14px;
}

button:hover {
    background-color: #00a8cc;
}

button.secondary {
    background-color: #3a3a5e;
    color: #ffffff;
}

button.secondary:hover {
    background-color: #4a4a7e;
}
```

### GDScript

```gdscript
extends Control

var settings = {
    "player_name": "",
    "difficulty": "normal",
    "volume": 75,
    "fullscreen": false,
    "vsync": true,
    "quality": "medium"
}

func _ready():
    $GmlView.input_changed.connect(_on_input_changed)
    $GmlView.selection_changed.connect(_on_selection_changed)
    $GmlView.button_clicked.connect(_on_button_clicked)

func _on_input_changed(id: String, value: String):
    match id:
        "player-name":
            settings.player_name = value
        "volume":
            settings.volume = int(value)
        "fullscreen":
            settings.fullscreen = value == "true"
        "vsync":
            settings.vsync = value == "true"
        "low", "medium", "high":
            settings.quality = id

func _on_selection_changed(id: String, value: String):
    if id == "difficulty":
        settings.difficulty = value

func _on_button_clicked(method: String):
    match method:
        "on_save":
            save_settings()
        "on_cancel":
            close_settings()

func save_settings():
    print("Saving settings: ", settings)
    # Apply settings...

func close_settings():
    queue_free()
```

## See Also

- [HTML Elements](html-elements.md) - All element types
- [CSS Properties](css-properties.md) - Styling properties
- [CSS Selectors](css-selectors.md) - Focus pseudo-class
- [Getting Started](getting-started.md) - Signal handling basics
