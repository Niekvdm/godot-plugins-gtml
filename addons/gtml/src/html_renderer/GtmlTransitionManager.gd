class_name GtmlTransitionManager
extends RefCounted

## Manages CSS transitions for GTML controls.
## Handles Tween creation, property animation, and interrupted transition handling.


## Stores active tweens per control: {control_id: {property: Tween}}
var _active_tweens: Dictionary = {}

## Stores current animated values for interrupted transitions: {control_id: {property: value}}
var _current_values: Dictionary = {}


## Apply a transition between two style states.
## control: The Control to animate
## from_style: The starting style dictionary
## to_style: The target style dictionary
## transitions: Array of transition definitions from CSS
func transition_style(control: Control, from_style: Dictionary, to_style: Dictionary, transitions: Array) -> void:
	if not is_instance_valid(control):
		return

	for trans in transitions:
		var property: String = trans.get("property", "")
		if property.is_empty():
			continue

		# Check if the target style has this property. The "transform" composite
		# is special: if the target style omits it, the implicit value is the
		# identity transform, so the animation should still fire to revert
		# scale/rotation/position back to neutral.
		var to_value
		if to_style.has(property):
			to_value = to_style[property]
		elif property == "transform":
			to_value = {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}
		else:
			continue

		var from_value = _get_current_value(control, property, from_style)

		# Skip if values are the same
		if _values_equal(from_value, to_value):
			continue

		var duration: float = trans.get("duration", 0.0)
		var timing: Dictionary = trans.get("timing", {"trans_type": Tween.TRANS_SINE, "ease_type": Tween.EASE_IN_OUT})
		var delay: float = trans.get("delay", 0.0)

		_animate_property(control, property, from_value, to_value, duration, timing, delay)


## Get the current value of a property, checking for in-progress animations.
func _get_current_value(control: Control, property: String, fallback_style: Dictionary):
	var control_id = control.get_instance_id()

	# Check if we have a current animated value
	if _current_values.has(control_id) and _current_values[control_id].has(property):
		return _current_values[control_id][property]

	# Fall back to the style value
	return fallback_style.get(property)


## Animate a specific property.
func _animate_property(control: Control, property: String, from_value, to_value, duration: float, timing: Dictionary, delay: float) -> void:
	# Cancel any existing tween for this property
	_cancel_property_tween(control, property)

	# If duration is 0, apply immediately
	if duration <= 0:
		_apply_property_value(control, property, to_value)
		return

	var tween = control.create_tween()
	tween.set_trans(timing.get("trans_type", Tween.TRANS_SINE))
	tween.set_ease(timing.get("ease_type", Tween.EASE_IN_OUT))

	# Add delay if specified
	if delay > 0:
		tween.tween_interval(delay)

	# Animate based on property type
	match property:
		"opacity":
			_animate_opacity(control, from_value, to_value, tween, duration)
		"background-color":
			_animate_background_color(control, from_value, to_value, tween, duration)
		"color":
			_animate_text_color(control, from_value, to_value, tween, duration)
		"border-color":
			_animate_border_color(control, from_value, to_value, tween, duration)
		"width":
			_animate_width(control, from_value, to_value, tween, duration)
		"height":
			_animate_height(control, from_value, to_value, tween, duration)
		"transform":
			_animate_transform(control, from_value, to_value, tween, duration)
		_:
			# Unknown property - try generic approach
			_animate_generic(control, property, from_value, to_value, tween, duration)

	_store_tween(control, property, tween)

	# Clear current value when tween finishes
	tween.finished.connect(func():
		_clear_current_value(control, property)
	)


## Animate opacity property.
func _animate_opacity(control: Control, from_value, to_value, tween: Tween, duration: float) -> void:
	var from_alpha := _to_float(from_value, 1.0)
	var to_alpha := _to_float(to_value, 1.0)

	control.modulate.a = from_alpha
	tween.tween_property(control, "modulate:a", to_alpha, duration)

	# Track current value during animation
	_track_value_during_tween(control, "opacity", from_alpha, to_alpha, tween, duration)


## Animate background-color property using tween_method for StyleBox updates.
func _animate_background_color(control: Control, from_value, to_value, tween: Tween, duration: float) -> void:
	var from_color := _to_color(from_value)
	var to_color := _to_color(to_value)

	# Use tween_method to update StyleBox each frame
	tween.tween_method(
		func(t: float):
			var current_color = from_color.lerp(to_color, t)
			_update_control_background(control, current_color)
			_store_current_value(control, "background-color", current_color),
		0.0, 1.0, duration
	)


## Animate text color property.
func _animate_text_color(control: Control, from_value, to_value, tween: Tween, duration: float) -> void:
	var from_color := _to_color(from_value)
	var to_color := _to_color(to_value)

	# Use tween_method to update theme color each frame
	tween.tween_method(
		func(t: float):
			var current_color = from_color.lerp(to_color, t)
			_update_control_text_color(control, current_color)
			_store_current_value(control, "color", current_color),
		0.0, 1.0, duration
	)


## Animate border-color property.
func _animate_border_color(control: Control, from_value, to_value, tween: Tween, duration: float) -> void:
	var from_color := _to_color(from_value)
	var to_color := _to_color(to_value)

	tween.tween_method(
		func(t: float):
			var current_color = from_color.lerp(to_color, t)
			_update_control_border_color(control, current_color)
			_store_current_value(control, "border-color", current_color),
		0.0, 1.0, duration
	)


## Animate width property.
func _animate_width(control: Control, from_value, to_value, tween: Tween, duration: float) -> void:
	var from_width := _to_int(from_value, int(control.custom_minimum_size.x))
	var to_width := _to_int(to_value, from_width)

	control.custom_minimum_size.x = from_width
	tween.tween_property(control, "custom_minimum_size:x", float(to_width), duration)

	_track_value_during_tween(control, "width", from_width, to_width, tween, duration)


## Animate height property.
func _animate_height(control: Control, from_value, to_value, tween: Tween, duration: float) -> void:
	var from_height := _to_int(from_value, int(control.custom_minimum_size.y))
	var to_height := _to_int(to_value, from_height)

	control.custom_minimum_size.y = from_height
	tween.tween_property(control, "custom_minimum_size:y", float(to_height), duration)

	_track_value_during_tween(control, "height", from_height, to_height, tween, duration)


## Animate the transform composite — scale (Vector2), rotation (float),
## and translate offset (Vector2) interpolate in parallel through the same
## tween. Missing values on either side default to the identity transform
## (scale = 1, rotation = 0, translate = ZERO) so going from a transformed
## :hover back to a transform-less base reverts cleanly.
##
## Interruption-safe: we read the live control.scale / control.rotation /
## control.position rather than the caller's from_value so a hover-in
## followed by a quick hover-out continues from the mid-tween visual state
## instead of snapping back to the un-tweened baseline.
##
## Base-position fallback: if GtmlDimensions hasn't stamped
## _transform_base_position (the base style had no transform declaration),
## we stamp it here using the live position so reverts return to layout.
func _animate_transform(control: Control, _from_value, to_value, tween: Tween, duration: float) -> void:
	var to_t := _normalize_transform(to_value)

	if not control.has_meta("_transform_base_position"):
		control.set_meta("_transform_base_position", control.position)
	var base_pos: Vector2 = control.get_meta("_transform_base_position")

	tween.set_parallel(true)
	tween.tween_property(control, "scale", to_t["scale"], duration)
	tween.tween_property(control, "rotation", to_t["rotate"], duration)
	tween.tween_property(control, "position", base_pos + to_t["translate"], duration)


## Normalize a transform value to the canonical {translate, scale, rotate}
## Dictionary. Accepts a Dictionary (the GtmlTransformValues output), an
## untyped Variant (treated as identity), or null.
static func _normalize_transform(v) -> Dictionary:
	if not (v is Dictionary):
		return {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}
	var d: Dictionary = v
	return {
		"translate": d.get("translate", Vector2.ZERO),
		"scale": d.get("scale", Vector2.ONE),
		"rotate": d.get("rotate", 0.0),
	}


## Generic animation for unsupported properties - applies immediately.
func _animate_generic(control: Control, property: String, _from_value, to_value, _tween: Tween, _duration: float) -> void:
	_apply_property_value(control, property, to_value)


## Track a value during tween animation.
func _track_value_during_tween(control: Control, property: String, from_value, to_value, tween: Tween, duration: float) -> void:
	# Use a parallel tween to track the value
	tween.parallel().tween_method(
		func(t: float):
			var current = lerp(from_value, to_value, t)
			_store_current_value(control, property, current),
		0.0, 1.0, duration
	)


## Update control background color via StyleBox.
func _update_control_background(control: Control, color: Color) -> void:
	var stylebox: StyleBoxFlat

	# Try to get existing StyleBox based on control type
	if control is Button:
		if control.has_theme_stylebox_override("normal"):
			stylebox = control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	elif control is LineEdit:
		if control.has_theme_stylebox_override("normal"):
			stylebox = control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	elif control is TextEdit:
		if control.has_theme_stylebox_override("normal"):
			stylebox = control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	elif control is PanelContainer:
		if control.has_theme_stylebox_override("panel"):
			stylebox = control.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	elif control.has_theme_stylebox_override("panel"):
		stylebox = control.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	# Create new StyleBox if needed
	if stylebox == null:
		stylebox = StyleBoxFlat.new()
		# Copy existing properties if we have metadata
		if control.has_meta("_stylebox_props"):
			var props: Dictionary = control.get_meta("_stylebox_props")
			if props.has("corner_radius"):
				var cr = props.corner_radius
				stylebox.corner_radius_top_left = cr
				stylebox.corner_radius_top_right = cr
				stylebox.corner_radius_bottom_left = cr
				stylebox.corner_radius_bottom_right = cr
			if props.has("border_width"):
				var bw = props.border_width
				stylebox.border_width_top = bw
				stylebox.border_width_right = bw
				stylebox.border_width_bottom = bw
				stylebox.border_width_left = bw
			if props.has("border_color"):
				stylebox.border_color = props.border_color

	stylebox.bg_color = color

	# Apply to appropriate override - for buttons, update ALL states
	if control is Button:
		control.add_theme_stylebox_override("normal", stylebox)
		control.add_theme_stylebox_override("hover", stylebox.duplicate())
		control.add_theme_stylebox_override("pressed", stylebox.duplicate())
		control.add_theme_stylebox_override("focus", stylebox.duplicate())
	elif control is LineEdit:
		control.add_theme_stylebox_override("normal", stylebox)
		control.add_theme_stylebox_override("focus", stylebox.duplicate())
	elif control is TextEdit:
		control.add_theme_stylebox_override("normal", stylebox)
		control.add_theme_stylebox_override("focus", stylebox.duplicate())
	elif control is PanelContainer:
		control.add_theme_stylebox_override("panel", stylebox)
	else:
		control.add_theme_stylebox_override("panel", stylebox)


## Update control text color.
func _update_control_text_color(control: Control, color: Color) -> void:
	if control is Label:
		control.add_theme_color_override("font_color", color)
	elif control is Button:
		control.add_theme_color_override("font_color", color)
	elif control is LineEdit:
		control.add_theme_color_override("font_color", color)
	elif control is RichTextLabel:
		control.add_theme_color_override("default_color", color)


## Update control border color via StyleBox.
func _update_control_border_color(control: Control, color: Color) -> void:
	var stylebox: StyleBoxFlat

	# Try to get existing StyleBox based on control type
	if control is Button:
		if control.has_theme_stylebox_override("normal"):
			stylebox = control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	elif control is LineEdit:
		if control.has_theme_stylebox_override("normal"):
			stylebox = control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	elif control is TextEdit:
		if control.has_theme_stylebox_override("normal"):
			stylebox = control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	elif control.has_theme_stylebox_override("panel"):
		stylebox = control.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	if stylebox:
		stylebox.border_color = color

		# Apply to appropriate override - for buttons, update ALL states
		if control is Button:
			control.add_theme_stylebox_override("normal", stylebox)
			control.add_theme_stylebox_override("hover", stylebox.duplicate())
			control.add_theme_stylebox_override("pressed", stylebox.duplicate())
			control.add_theme_stylebox_override("focus", stylebox.duplicate())
		elif control is LineEdit:
			control.add_theme_stylebox_override("normal", stylebox)
			control.add_theme_stylebox_override("focus", stylebox.duplicate())
		elif control is TextEdit:
			control.add_theme_stylebox_override("normal", stylebox)
			control.add_theme_stylebox_override("focus", stylebox.duplicate())
		else:
			control.add_theme_stylebox_override("panel", stylebox)


## Apply a property value immediately without animation.
func _apply_property_value(control: Control, property: String, value) -> void:
	match property:
		"opacity":
			control.modulate.a = _to_float(value, 1.0)
		"background-color":
			_update_control_background(control, _to_color(value))
		"color":
			_update_control_text_color(control, _to_color(value))
		"border-color":
			_update_control_border_color(control, _to_color(value))
		"width":
			control.custom_minimum_size.x = _to_int(value, 0)
		"height":
			control.custom_minimum_size.y = _to_int(value, 0)
		"transform":
			var t := _normalize_transform(value)
			control.scale = t["scale"]
			control.rotation = t["rotate"]
			# Stamp the base position the first time we touch transform so
			# subsequent reverts return to the pre-translate layout spot
			# instead of accumulating offsets each toggle.
			if not control.has_meta("_transform_base_position"):
				control.set_meta("_transform_base_position", control.position)
			var base_pos: Vector2 = control.get_meta("_transform_base_position")
			control.position = base_pos + t["translate"]


## Cancel an existing tween for a property.
func _cancel_property_tween(control: Control, property: String) -> void:
	var control_id = control.get_instance_id()

	if _active_tweens.has(control_id) and _active_tweens[control_id].has(property):
		var tween: Tween = _active_tweens[control_id][property]
		if is_instance_valid(tween) and tween.is_running():
			tween.kill()
		_active_tweens[control_id].erase(property)


## Store a tween reference.
func _store_tween(control: Control, property: String, tween: Tween) -> void:
	var control_id = control.get_instance_id()

	if not _active_tweens.has(control_id):
		_active_tweens[control_id] = {}

	_active_tweens[control_id][property] = tween


## Store the current animated value.
func _store_current_value(control: Control, property: String, value) -> void:
	var control_id = control.get_instance_id()

	if not _current_values.has(control_id):
		_current_values[control_id] = {}

	_current_values[control_id][property] = value


## Clear the current value for a property.
func _clear_current_value(control: Control, property: String) -> void:
	var control_id = control.get_instance_id()

	if _current_values.has(control_id):
		_current_values[control_id].erase(property)
		if _current_values[control_id].is_empty():
			_current_values.erase(control_id)


## Check if two values are equal.
func _values_equal(a, b) -> bool:
	if a is Color and b is Color:
		return a.is_equal_approx(b)
	if a is float and b is float:
		return is_equal_approx(a, b)
	return a == b


## Convert value to float.
func _to_float(value, default: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		return value.to_float()
	return default


## Convert value to int.
func _to_int(value, default: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		return value.to_int()
	return default


## Convert value to Color.
func _to_color(value) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, Color.WHITE)
	return Color.WHITE


## Clean up tweens for a control that is being freed.
func cleanup_control(control: Control) -> void:
	var control_id = control.get_instance_id()

	if _active_tweens.has(control_id):
		for property in _active_tweens[control_id]:
			var tween: Tween = _active_tweens[control_id][property]
			if is_instance_valid(tween):
				tween.kill()
		_active_tweens.erase(control_id)

	if _current_values.has(control_id):
		_current_values.erase(control_id)
