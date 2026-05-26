class_name GmlInputBuilder
extends RefCounted

## Static utility class for building input elements (input, textarea, select).


## Build an input element.
static func build_input(node, ctx: Dictionary) -> Dictionary:
	var input_type = node.get_attr("type", "text")
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults
	var gml_view = ctx.gml_view

	var inner: Control = null

	match input_type:
		"text", "password", "email", "number":
			inner = _build_text_input(node, input_type, style, gml_view, defaults)
		"checkbox":
			inner = _build_checkbox_input(node, style, gml_view, defaults)
		"radio":
			inner = _build_radio_input(node, style, gml_view, defaults)
		"range":
			inner = _build_range_input(node, style, gml_view, defaults)
		"submit":
			inner = _build_submit_button(node, style, ctx)
		_:
			inner = _build_text_input(node, "text", style, gml_view, defaults)

	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


## Build a text input (LineEdit).
static func _build_text_input(node, input_type: String, style: Dictionary, gml_view, defaults: Dictionary = {}) -> Control:
	var line_edit := LineEdit.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		line_edit.editable = false

	# Apply styling
	var style_box = _create_input_stylebox(style)
	line_edit.add_theme_stylebox_override("normal", style_box)

	# Handle :focus pseudo-class
	if style.has("_focus"):
		var focus_style = style["_focus"]
		var focus_box = style_box.duplicate()
		GmlStyles.apply_pseudo_style_to_stylebox(focus_box, focus_style)
		line_edit.add_theme_stylebox_override("focus", focus_box)
	else:
		line_edit.add_theme_stylebox_override("focus", style_box.duplicate())

	# Apply font styles
	_apply_font_styles(line_edit, style, defaults)

	var placeholder = node.get_attr("placeholder", "")
	if not placeholder.is_empty():
		line_edit.placeholder_text = placeholder

	var value = node.get_attr("value", "")
	if not value.is_empty():
		line_edit.text = value

	if input_type == "password":
		line_edit.secret = true

	if input_type == "number":
		line_edit.text_changed.connect(func(new_text: String):
			var filtered := ""
			for c in new_text:
				if c.is_valid_int() or c == "." or c == "-":
					filtered += c
			if filtered != new_text:
				line_edit.text = filtered
		)

	var input_id = node.get_id()
	if input_id.is_empty():
		input_id = node.get_attr("name", "")

	if gml_view != null and not input_id.is_empty():
		var view_ref = weakref(gml_view)
		line_edit.text_changed.connect(func(new_text: String):
			var view = view_ref.get_ref()
			if view != null:
				view.input_changed.emit(input_id, new_text)
		)

	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return line_edit


## Build a checkbox input.
static func _build_checkbox_input(node, style: Dictionary, gml_view, defaults: Dictionary = {}) -> Control:
	var checkbox := CheckBox.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		checkbox.disabled = true

	# Apply font styles (checkbox has limited styling options)
	_apply_font_styles(checkbox, style, defaults)

	var text = node.get_text_content()
	if not text.is_empty():
		checkbox.text = text

	var checked = node.has_attr("checked")
	checkbox.button_pressed = checked

	var input_id = node.get_id()
	if input_id.is_empty():
		input_id = node.get_attr("name", "")

	if gml_view != null and not input_id.is_empty():
		var view_ref = weakref(gml_view)
		checkbox.toggled.connect(func(pressed: bool):
			var view = view_ref.get_ref()
			if view != null:
				view.input_changed.emit(input_id, "true" if pressed else "false")
		)

	_apply_button_focus_stylebox(checkbox, style)
	return checkbox


## Build a radio input.
## Radio buttons with the same "name" attribute are grouped together.
static func _build_radio_input(node, style: Dictionary, gml_view, defaults: Dictionary = {}) -> Control:
	var radio := CheckBox.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		radio.disabled = true

	# Apply font styles
	_apply_font_styles(radio, style, defaults)

	# Get label text (text content of the input element)
	var text = node.get_text_content()
	if not text.is_empty():
		radio.text = text

	# Handle checked attribute
	var checked = node.has_attr("checked")
	radio.button_pressed = checked

	# Get value attribute (used when emitting changes)
	var value = node.get_attr("value", "on")
	radio.set_meta("value", value)

	# Group radios by name attribute using ButtonGroup
	var group_name = node.get_attr("name", "")
	if gml_view != null and not group_name.is_empty():
		var button_group = gml_view.get_radio_group(group_name)
		radio.button_group = button_group

	# Get input ID (prefer id, fallback to name)
	var input_id = node.get_id()
	if input_id.is_empty():
		input_id = node.get_attr("name", "")

	# Emit input_changed signal with the value when selected
	if gml_view != null and not input_id.is_empty():
		var view_ref = weakref(gml_view)
		radio.toggled.connect(func(pressed: bool):
			if pressed:  # Only emit when selected, not when deselected
				var view = view_ref.get_ref()
				if view != null:
					view.input_changed.emit(input_id, value)
		)

	_apply_button_focus_stylebox(radio, style)
	return radio


## Apply a CSS-driven :focus stylebox to a CheckBox / radio so authors can
## replace Godot's default focus rectangle with something on-brand.
##
## If the style has a _focus bucket, build a StyleBoxFlat from its
## background-color / border / border-radius and install it as the "focus"
## theme override. Empty bucket (no recognized properties) yields a
## transparent StyleBoxEmpty so authors can opt out of any focus indicator.
## When the style has no _focus rule, leave Godot's default in place.
static func _apply_button_focus_stylebox(btn: CheckBox, style: Dictionary) -> void:
	if not style.has("_focus"):
		return
	var focus_style: Dictionary = style["_focus"]
	var has_visual := false
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	if focus_style.has("background-color"):
		box.bg_color = focus_style["background-color"]
		has_visual = true
	if focus_style.has("border") or focus_style.has("border-width") or focus_style.has("border-color"):
		GmlStyles.apply_border_to_stylebox(box, focus_style)
		has_visual = true
	if focus_style.has("border-radius"):
		box.corner_radius_top_left = focus_style["border-radius"]
		box.corner_radius_top_right = focus_style["border-radius"]
		box.corner_radius_bottom_left = focus_style["border-radius"]
		box.corner_radius_bottom_right = focus_style["border-radius"]
		has_visual = true
	if not has_visual:
		# Empty :focus rule — explicit opt-out: silence the default ring.
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		return
	btn.add_theme_stylebox_override("focus", box)


## Build a range input (slider).
static func _build_range_input(node, style: Dictionary, gml_view, defaults: Dictionary = {}) -> Control:
	var slider := HSlider.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		slider.editable = false

	# Apply slider track styling
	if style.has("background-color") or style.has("border"):
		var track_box = _create_input_stylebox(style)
		# Make the track thinner
		track_box.content_margin_top = 2
		track_box.content_margin_bottom = 2
		slider.add_theme_stylebox_override("slider", track_box)

		# Style the grabber area (filled part)
		var grabber_area = track_box.duplicate()
		if style.has("color"):
			grabber_area.bg_color = style["color"]
		else:
			grabber_area.bg_color = Color(0.3, 0.5, 0.8, 1.0)  # Default accent
		slider.add_theme_stylebox_override("grabber_area", grabber_area)

		# Style the grabber (handle)
		var grabber = StyleBoxFlat.new()
		grabber.bg_color = Color.WHITE
		grabber.set_corner_radius_all(8)
		slider.add_theme_stylebox_override("grabber", grabber)

		var grabber_highlight = grabber.duplicate()
		grabber_highlight.bg_color = Color(0.9, 0.9, 0.9, 1.0)
		slider.add_theme_stylebox_override("grabber_highlight", grabber_highlight)

	var min_val = float(node.get_attr("min", "0"))
	var max_val = float(node.get_attr("max", "100"))
	var step_val = float(node.get_attr("step", "1"))
	var value = float(node.get_attr("value", str(min_val)))

	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = value

	var input_id = node.get_id()
	if input_id.is_empty():
		input_id = node.get_attr("name", "")

	if gml_view != null and not input_id.is_empty():
		var view_ref = weakref(gml_view)
		slider.value_changed.connect(func(new_value: float):
			var view = view_ref.get_ref()
			if view != null:
				view.input_changed.emit(input_id, str(new_value))
		)

	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return slider


## Build a submit button.
static func _build_submit_button(node, style: Dictionary, ctx: Dictionary) -> Control:
	var gml_view = ctx.gml_view
	var button := Button.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		button.disabled = true

	var value = node.get_attr("value", "Submit")
	button.text = value

	if gml_view != null:
		var click_handler = node.get_attr("@click", "")
		if not click_handler.is_empty():
			var view_ref = weakref(gml_view)
			button.pressed.connect(func():
				var view = view_ref.get_ref()
				if view != null:
					view.button_clicked.emit(click_handler)
			)

	return button


## Build a textarea element.
static func build_textarea(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_textarea_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_textarea_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults
	var gml_view = ctx.gml_view

	var text_edit := TextEdit.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		text_edit.editable = false

	# Apply styling
	var style_box = _create_input_stylebox(style)
	text_edit.add_theme_stylebox_override("normal", style_box)
	text_edit.add_theme_stylebox_override("read_only", style_box.duplicate())

	# Handle :focus pseudo-class
	if style.has("_focus"):
		var focus_style = style["_focus"]
		var focus_box = style_box.duplicate()
		GmlStyles.apply_pseudo_style_to_stylebox(focus_box, focus_style)
		text_edit.add_theme_stylebox_override("focus", focus_box)
	else:
		text_edit.add_theme_stylebox_override("focus", style_box.duplicate())

	# Apply font styles
	_apply_font_styles(text_edit, style, defaults)

	var placeholder = node.get_attr("placeholder", "")
	if not placeholder.is_empty():
		text_edit.placeholder_text = placeholder

	var content = node.get_text_content()
	if not content.is_empty():
		text_edit.text = content

	var rows = int(node.get_attr("rows", "4"))
	text_edit.custom_minimum_size.y = rows * 24

	var cols = int(node.get_attr("cols", "40"))
	text_edit.custom_minimum_size.x = cols * 8

	var input_id = node.get_id()
	if input_id.is_empty():
		input_id = node.get_attr("name", "")

	if gml_view != null and not input_id.is_empty():
		var view_ref = weakref(gml_view)
		text_edit.text_changed.connect(func():
			var view = view_ref.get_ref()
			if view != null:
				view.input_changed.emit(input_id, text_edit.text)
		)

	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return text_edit


## Build a select/dropdown element.
static func build_select(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_select_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_select_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults
	var gml_view = ctx.gml_view

	var option_button := OptionButton.new()

	# Handle disabled attribute
	if node.has_attr("disabled"):
		option_button.disabled = true

	# Apply styling
	var style_box = _create_input_stylebox(style)
	option_button.add_theme_stylebox_override("normal", style_box)

	# Create hover/pressed/focus variants
	var hover_box = style_box.duplicate()
	hover_box.bg_color = style_box.bg_color.lightened(0.1)
	option_button.add_theme_stylebox_override("hover", hover_box)

	var pressed_box = style_box.duplicate()
	pressed_box.bg_color = style_box.bg_color.darkened(0.1)
	option_button.add_theme_stylebox_override("pressed", pressed_box)

	# Handle :focus pseudo-class
	if style.has("_focus"):
		var focus_style = style["_focus"]
		var focus_box = style_box.duplicate()
		GmlStyles.apply_pseudo_style_to_stylebox(focus_box, focus_style)
		option_button.add_theme_stylebox_override("focus", focus_box)
	else:
		option_button.add_theme_stylebox_override("focus", style_box.duplicate())

	# Apply font styles
	_apply_font_styles(option_button, style, defaults)

	var selected_idx := 0
	var idx := 0
	for child in node.children:
		if child.tag == "option":
			var text = child.get_text_content()
			var value = child.get_attr("value", text)

			option_button.add_item(text)
			option_button.set_item_metadata(idx, value)

			if child.has_attr("selected"):
				selected_idx = idx

			idx += 1

	if idx > 0:
		option_button.select(selected_idx)

	var select_id = node.get_id()
	if select_id.is_empty():
		select_id = node.get_attr("name", "")

	if gml_view != null and not select_id.is_empty():
		var view_ref = weakref(gml_view)
		option_button.item_selected.connect(func(index: int):
			var view = view_ref.get_ref()
			if view != null:
				var value = option_button.get_item_metadata(index)
				view.selection_changed.emit(select_id, str(value))
		)

	return option_button


## Create a StyleBoxFlat from CSS style properties for input elements.
static func _create_input_stylebox(style: Dictionary) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()

	# Background
	if style.has("background-color"):
		style_box.bg_color = style["background-color"]
	else:
		style_box.bg_color = Color(0.15, 0.15, 0.2, 1.0)  # Default dark

	# Border
	GmlStyles.apply_border_to_stylebox(style_box, style)

	# Padding (for content margin)
	if style.has("padding"):
		var p = style["padding"]
		style_box.content_margin_top = p
		style_box.content_margin_right = p
		style_box.content_margin_bottom = p
		style_box.content_margin_left = p

	# Individual padding
	if style.has("padding-top"):
		style_box.content_margin_top = style["padding-top"]
	if style.has("padding-right"):
		style_box.content_margin_right = style["padding-right"]
	if style.has("padding-bottom"):
		style_box.content_margin_bottom = style["padding-bottom"]
	if style.has("padding-left"):
		style_box.content_margin_left = style["padding-left"]

	return style_box


## Apply font styles to a control using theme overrides.
static func _apply_font_styles(control: Control, style: Dictionary, defaults: Dictionary) -> void:
	if style.has("color"):
		control.add_theme_color_override("font_color", style["color"])
		# Also set placeholder color for input controls
		if control is LineEdit or control is TextEdit:
			control.add_theme_color_override("font_placeholder_color", style["color"].darkened(0.4))

	if style.has("font-size"):
		control.add_theme_font_size_override("font_size", style["font-size"])

	if style.has("font-family"):
		var font_name: String = style["font-family"]
		var fonts_dict: Dictionary = defaults.get("fonts", {})
		if fonts_dict.has(font_name):
			var font = fonts_dict[font_name]
			if font is Font:
				control.add_theme_font_override("font", font)
