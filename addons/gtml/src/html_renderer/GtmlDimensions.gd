class_name GtmlDimensions
extends RefCounted

## Static helpers that translate CSS dimension/flex/cursor properties into
## Godot Control settings. Pure transformation logic — no scene-tree work.
## Percent-based sizing and max-size enforcement live in GtmlPercentSizing.


## Apply width / height / min-* / max-* / flex-* / cursor onto a control.
## Returns nothing; metadata used by GtmlPercentSizing is stamped on the control.
static func apply(control: Control, style: Dictionary) -> void:
	var width_percent: float = -1.0
	var height_percent: float = -1.0

	if style.has("width"):
		width_percent = _apply_axis(control, style["width"], true)
	if style.has("height"):
		height_percent = _apply_axis(control, style["height"], false)

	if (width_percent > 0 and width_percent < 1.0) or (height_percent > 0 and height_percent < 1.0):
		if width_percent > 0 and width_percent < 1.0:
			control.set_meta("width_percent", width_percent)
		if height_percent > 0 and height_percent < 1.0:
			control.set_meta("height_percent", height_percent)
		GtmlPercentSizing.attach(control)

	_apply_min(control, style, "min-width", true)
	_apply_min(control, style, "min-height", false)

	var has_max := _apply_max(control, style, "max-width", true)
	has_max = _apply_max(control, style, "max-height", false) or has_max
	if has_max:
		GtmlPercentSizing.attach_max_size(control)

	_apply_flex_grow(control, style)
	_apply_flex_shrink(control, style)
	_apply_flex_basis(control, style)

	if width_percent >= 1.0 and height_percent >= 1.0:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif width_percent >= 1.0:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif height_percent >= 1.0:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if style.has("cursor"):
		control.mouse_default_cursor_shape = parse_cursor(style["cursor"])

	if style.has("transform"):
		_apply_transform(control, style["transform"])


## Apply a parsed transform Dictionary to a Control. Maps:
##   translate -> position offset (added to the layout-driven position)
##   scale     -> Control.scale
##   rotate    -> Control.rotation (radians)
## pivot_offset is recomputed to the control's size center so scale/rotate
## behave like CSS transform-origin: 50% 50%. Done deferred to a process
## frame so we have a valid post-layout size to anchor on.
static func _apply_transform(control: Control, t: Dictionary) -> void:
	var translate: Vector2 = t.get("translate", Vector2.ZERO)
	var scale_v: Vector2 = t.get("scale", Vector2.ONE)
	var rotate_v: float = t.get("rotate", 0.0)

	# Apply scalar transforms immediately — position offset waits for layout.
	control.scale = scale_v
	control.rotation = rotate_v

	if translate != Vector2.ZERO or scale_v != Vector2.ONE or rotate_v != 0.0:
		var ref := weakref(control)
		control.set_meta("_transform_translate", translate)
		# Recompute pivot + position once the Control has been sized by its
		# Container. Re-applies on resize so dynamic layouts keep their
		# transform-origin centered.
		var update_pivot := func():
			var c = ref.get_ref()
			if c == null or not is_instance_valid(c):
				return
			c.pivot_offset = c.size * 0.5
			var off: Vector2 = c.get_meta("_transform_translate", Vector2.ZERO)
			c.position = c.get_meta("_transform_base_position", c.position) + off
		control.tree_entered.connect(func():
			var c = ref.get_ref()
			if c == null or not is_instance_valid(c):
				return
			c.set_meta("_transform_base_position", c.position)
			c.get_tree().process_frame.connect(update_pivot, CONNECT_ONE_SHOT)
			if not c.resized.is_connected(update_pivot):
				c.resized.connect(update_pivot)
		, CONNECT_ONE_SHOT)


## Apply width or height. Returns the percent fraction if percent-based, else -1.
static func _apply_axis(control: Control, dim: Variant, is_width: bool) -> float:
	if not (dim is Dictionary):
		return -1.0
	var d: Dictionary = dim
	match d.get("unit", ""):
		"%":
			var pct: float = d["value"] / 100.0
			if d["value"] >= 100:
				if is_width:
					control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				else:
					control.size_flags_vertical = Control.SIZE_EXPAND_FILL
			else:
				if is_width:
					control.set_meta("width_percent", pct)
				else:
					control.set_meta("height_percent", pct)
			return pct
		"px":
			var v: float = d["value"]
			if is_width:
				control.custom_minimum_size.x = v
			else:
				control.custom_minimum_size.y = v
				if v <= 0:
					control.visible = false
	return -1.0


static func _apply_min(control: Control, style: Dictionary, prop: String, is_width: bool) -> void:
	if not style.has(prop):
		return
	var dim = style[prop]
	if not (dim is Dictionary) or dim.get("unit", "") != "px":
		return
	if is_width:
		control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, dim["value"])
	else:
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, dim["value"])


## Returns true if any max-* was applied (so caller can wire enforcement).
static func _apply_max(control: Control, style: Dictionary, prop: String, is_width: bool) -> bool:
	if not style.has(prop):
		return false
	var dim = style[prop]
	if not (dim is Dictionary):
		return false
	match dim.get("unit", ""):
		"px":
			if is_width:
				control.set_meta("max_width", dim["value"])
				control.custom_minimum_size.x = minf(control.custom_minimum_size.x, dim["value"])
			else:
				control.set_meta("max_height", dim["value"])
				control.custom_minimum_size.y = minf(control.custom_minimum_size.y, dim["value"])
			return true
		"%":
			if is_width:
				control.set_meta("max_width_percent", dim["value"] / 100.0)
			else:
				control.set_meta("max_height_percent", dim["value"] / 100.0)
			return true
	return false


static func _is_row(control: Control) -> bool:
	var parent: Node = control.get_parent()
	return parent.get_meta("is_row_layout", false) if parent else false


static func _apply_flex_grow(control: Control, style: Dictionary) -> void:
	if not style.has("flex-grow"):
		return
	var grow: float = style["flex-grow"]
	if grow <= 0:
		return
	if _is_row(control):
		control.size_flags_horizontal |= Control.SIZE_EXPAND
	else:
		control.size_flags_vertical |= Control.SIZE_EXPAND
	control.size_flags_stretch_ratio = grow


static func _apply_flex_shrink(control: Control, style: Dictionary) -> void:
	if not style.has("flex-shrink"):
		return
	var shrink: float = style["flex-shrink"]
	if shrink != 0:
		return  # >0 is default container behavior; nothing to wire
	if _is_row(control):
		control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


static func _apply_flex_basis(control: Control, style: Dictionary) -> void:
	if not style.has("flex-basis"):
		return
	var basis = style["flex-basis"]
	var row := _is_row(control)
	if basis is Dictionary:
		var unit: String = basis.get("unit", "")
		var value: float = basis.get("value", 0)
		if unit == "px":
			if row:
				control.custom_minimum_size.x = value
			else:
				control.custom_minimum_size.y = value
		elif unit == "%":
			if row:
				control.set_meta("flex_basis_percent_x", value / 100.0)
			else:
				control.set_meta("flex_basis_percent_y", value / 100.0)
	elif basis is String and basis != "auto" and (basis as String).is_valid_float():
		var px_value: float = (basis as String).to_float()
		if row:
			control.custom_minimum_size.x = px_value
		else:
			control.custom_minimum_size.y = px_value


## Parse a CSS cursor keyword to a Godot CursorShape.
static func parse_cursor(value: String) -> Control.CursorShape:
	match value:
		"pointer":
			return Control.CURSOR_POINTING_HAND
		"text":
			return Control.CURSOR_IBEAM
		"move":
			return Control.CURSOR_MOVE
		"grab", "grabbing":
			return Control.CURSOR_POINTING_HAND  # Godot has no grab cursor — fall back to hand
		"not-allowed", "no-drop":
			return Control.CURSOR_FORBIDDEN
		"wait":
			return Control.CURSOR_WAIT
		"progress":
			return Control.CURSOR_BUSY
		"crosshair":
			return Control.CURSOR_CROSS
		"help":
			return Control.CURSOR_HELP
		"n-resize", "s-resize", "ns-resize":
			return Control.CURSOR_VSIZE
		"e-resize", "w-resize", "ew-resize":
			return Control.CURSOR_HSIZE
		"nw-resize", "se-resize", "nwse-resize":
			return Control.CURSOR_FDIAGSIZE
		"ne-resize", "sw-resize", "nesw-resize":
			return Control.CURSOR_BDIAGSIZE
		"col-resize":
			return Control.CURSOR_HSPLIT
		"row-resize":
			return Control.CURSOR_VSPLIT
		_:
			return Control.CURSOR_ARROW
