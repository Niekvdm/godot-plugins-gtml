class_name GmlButtonElements
extends RefCounted

## Static utility class for building button elements.


## Build a button element.
## Supports both text-only buttons and buttons with child elements (like SVG icons).
static func build_button(node, ctx: Dictionary) -> Dictionary:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults
	var gml_view = ctx.gml_view

	# Check if button has complex children (not just text)
	var has_complex_children := false
	for child in node.children:
		if not child.is_text_node:
			has_complex_children = true
			break

	if has_complex_children:
		return _build_complex_button(node, ctx, style, defaults, gml_view)
	else:
		return _build_simple_button(node, ctx, style, defaults, gml_view)


static func _build_complex_button(node, ctx: Dictionary, style: Dictionary, defaults: Dictionary, gml_view) -> Dictionary:
	var button := Button.new()
	button.text = ""

	# Determine layout direction from flex-direction
	var flex_direction = style.get("flex-direction", "row")
	var is_row = flex_direction == "row"

	# Create container to hold the button's children
	var content_container: BoxContainer
	if is_row:
		content_container = HBoxContainer.new()
	else:
		content_container = VBoxContainer.new()

	# Apply justify-content (main-axis alignment)
	var justify = style.get("justify-content", "center")
	content_container.alignment = GmlStyles.parse_box_alignment(justify)

	content_container.add_theme_constant_override("separation", style.get("gap", 4))
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Button doesn't respect size flags - use anchors to fill the button rect
	content_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Get align-items for cross-axis alignment
	var align_items = style.get("align-items", "center")

	# Build children
	for child in node.children:
		var child_control = ctx.build_node.call(child)
		if child_control != null:
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Apply cross-axis alignment to children
			var child_style = ctx.get_style.call(child) if not child.is_text_node else {}
			GmlStyles.apply_cross_axis_alignment(child_control, align_items, is_row, child_style)
			content_container.add_child(child_control)

	button.add_child(content_container)

	# Wire up @click handler
	if node.has_attr("@click"):
		var method_name = node.get_attr("@click")
		if gml_view != null:
			var view_ref = weakref(gml_view)
			button.pressed.connect(func():
				var view = view_ref.get_ref()
				if view != null:
					view.button_clicked.emit(method_name)
			)

	# Apply button-specific styles (padding handled by StyleBox content margins)
	_apply_button_styles(button, style, defaults, false)

	if not style.has("width") and not style.has("min-width"):
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var wrapped = _wrap_with_button_margin(button, style)
	return {"control": wrapped, "inner": button}


static func _build_simple_button(node, ctx: Dictionary, style: Dictionary, defaults: Dictionary, gml_view) -> Dictionary:
	var button := Button.new()
	button.text = node.get_text_content()

	# Wire up @click handler
	if node.has_attr("@click"):
		var method_name = node.get_attr("@click")
		if gml_view != null:
			var view_ref = weakref(gml_view)
			button.pressed.connect(func():
				var view = view_ref.get_ref()
				if view != null:
					view.button_clicked.emit(method_name)
			)

	_apply_button_styles(button, style, defaults)

	if not style.has("width") and not style.has("min-width"):
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var wrapped = _wrap_with_button_margin(button, style)
	return {"control": wrapped, "inner": button}


## Apply styles directly to a button's StyleBox.
static func _apply_button_styles(button: Button, style: Dictionary, defaults: Dictionary, skip_padding: bool = false) -> void:
	var style_box := StyleBoxFlat.new()

	# Background color
	if style.has("background-color"):
		style_box.bg_color = style["background-color"]
	else:
		style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)

	# Padding
	if skip_padding:
		style_box.content_margin_top = 0
		style_box.content_margin_right = 0
		style_box.content_margin_bottom = 0
		style_box.content_margin_left = 0
	else:
		var base_padding: int = style.get("padding", 8)
		style_box.content_margin_top = style.get("padding-top", base_padding)
		style_box.content_margin_right = style.get("padding-right", base_padding)
		style_box.content_margin_bottom = style.get("padding-bottom", base_padding)
		style_box.content_margin_left = style.get("padding-left", base_padding)

	# Apply dimensions
	if style.has("width"):
		var width_dim = style["width"]
		if width_dim is Dictionary:
			match width_dim.get("unit", ""):
				"px":
					button.custom_minimum_size.x = width_dim["value"]
				"%":
					if width_dim["value"] >= 100:
						button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if style.has("height"):
		var height_dim = style["height"]
		if height_dim is Dictionary:
			match height_dim.get("unit", ""):
				"px":
					button.custom_minimum_size.y = height_dim["value"]
				"%":
					if height_dim["value"] >= 100:
						button.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if style.has("min-width"):
		var dim = style["min-width"]
		if dim is Dictionary and dim.get("unit", "") == "px":
			button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, dim["value"])

	if style.has("min-height"):
		var dim = style["min-height"]
		if dim is Dictionary and dim.get("unit", "") == "px":
			button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, dim["value"])

	# Border and border-radius
	GmlStyles.apply_border_to_stylebox(style_box, style)

	# Apply to normal state
	button.add_theme_stylebox_override("normal", style_box)

	# Create hover state
	var hover_box := style_box.duplicate()
	var hover_style: Dictionary = style.get("_hover", {})
	if not hover_style.is_empty():
		GmlStyles.apply_pseudo_style_to_stylebox(hover_box, hover_style)
	elif hover_box.bg_color.a > 0:
		hover_box.bg_color = hover_box.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover_box)

	# Create pressed state
	var pressed_box := style_box.duplicate()
	var active_style: Dictionary = style.get("_active", {})
	if not active_style.is_empty():
		GmlStyles.apply_pseudo_style_to_stylebox(pressed_box, active_style)
	elif pressed_box.bg_color.a > 0:
		pressed_box.bg_color = pressed_box.bg_color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed_box)

	# Focus state
	var focus_box := style_box.duplicate()
	var focus_style: Dictionary = style.get("_focus", {})
	if not focus_style.is_empty():
		GmlStyles.apply_pseudo_style_to_stylebox(focus_box, focus_style)
	else:
		focus_box = hover_box.duplicate()
	button.add_theme_stylebox_override("focus", focus_box)

	# Disabled state
	var disabled_box := style_box.duplicate()
	var disabled_style: Dictionary = style.get("_disabled", {})
	if not disabled_style.is_empty():
		GmlStyles.apply_pseudo_style_to_stylebox(disabled_box, disabled_style)
	else:
		disabled_box.bg_color = disabled_box.bg_color.darkened(0.3)
		disabled_box.bg_color.a *= 0.6
	button.add_theme_stylebox_override("disabled", disabled_box)

	# Text colors
	if style.has("color"):
		var color: Color = style["color"]
		button.add_theme_color_override("font_color", color)

	if hover_style.has("color"):
		button.add_theme_color_override("font_hover_color", hover_style["color"])
	elif style.has("color"):
		button.add_theme_color_override("font_hover_color", style["color"])

	if active_style.has("color"):
		button.add_theme_color_override("font_pressed_color", active_style["color"])
	elif style.has("color"):
		button.add_theme_color_override("font_pressed_color", style["color"])

	if focus_style.has("color"):
		button.add_theme_color_override("font_focus_color", focus_style["color"])
	elif style.has("color"):
		button.add_theme_color_override("font_focus_color", style["color"])

	if disabled_style.has("color"):
		button.add_theme_color_override("font_disabled_color", disabled_style["color"])
	elif style.has("color"):
		var disabled_color: Color = style["color"]
		disabled_color.a *= 0.5
		button.add_theme_color_override("font_disabled_color", disabled_color)

	# Font family
	if style.has("font-family"):
		var font_name: String = style["font-family"]
		var fonts_dict: Dictionary = defaults.get("fonts", {})
		if fonts_dict.has(font_name):
			var font = fonts_dict[font_name]
			if font is Font:
				button.add_theme_font_override("font", font)

	# Font size
	if style.has("font-size"):
		var font_size: int = style["font-size"]
		button.add_theme_font_size_override("font_size", font_size)

	# Font weight
	if style.has("font-weight"):
		var weight: int = style["font-weight"]
		if weight >= 600:
			var outline_size: int
			if weight >= 900:
				outline_size = 7
			elif weight >= 800:
				outline_size = 4
			else:
				outline_size = 1
			button.add_theme_constant_override("outline_size", outline_size)
			var font_color: Color = style.get("color", Color.WHITE)
			button.add_theme_color_override("font_outline_color", font_color)
			button.add_theme_color_override("font_hover_outline_color", hover_style.get("color", font_color))
			button.add_theme_color_override("font_pressed_outline_color", active_style.get("color", font_color))
			button.add_theme_color_override("font_focus_outline_color", focus_style.get("color", font_color))
			var disabled_outline_color: Color = disabled_style.get("color", font_color)
			disabled_outline_color.a *= 0.5
			button.add_theme_color_override("font_disabled_outline_color", disabled_outline_color)

	# Letter spacing
	if style.has("letter-spacing"):
		var spacing: float = style["letter-spacing"]
		if spacing > 0.0 and not button.text.is_empty():
			var original_text: String = button.text
			var spaced_text := ""
			var space_char := ""
			if spacing >= 4.0:
				space_char = " "
			elif spacing >= 2.0:
				space_char = "\u2002"
			elif spacing >= 1.0:
				space_char = "\u2009"
			else:
				space_char = "\u200A"

			for i in range(original_text.length()):
				spaced_text += original_text[i]
				if i < original_text.length() - 1:
					var num_spaces := maxi(1, int(spacing / 2.0))
					for _j in range(num_spaces):
						spaced_text += space_char
			button.text = spaced_text


## Wrap button with margin only.
static func _wrap_with_button_margin(button: Button, style: Dictionary) -> Control:
	var has_margin = style.has("margin") and style["margin"] > 0 \
		or style.has("margin-top") or style.has("margin-right") or style.has("margin-bottom") or style.has("margin-left")

	if not has_margin:
		return button

	var base_margin: int = style.get("margin", 0)
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", style.get("margin-left", base_margin))
	margin_container.add_theme_constant_override("margin_right", style.get("margin-right", base_margin))
	margin_container.add_theme_constant_override("margin_top", style.get("margin-top", base_margin))
	margin_container.add_theme_constant_override("margin_bottom", style.get("margin-bottom", base_margin))
	margin_container.add_child(button)

	return margin_container
