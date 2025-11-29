class_name GmlInputElements
extends RefCounted

## Static utility class for building input elements (input, textarea, select).


## Build an input element.
static func build_input(node, ctx: Dictionary) -> Dictionary:
	var input_type = node.get_attr("type", "text")
	var style = ctx.get_style.call(node)
	var gml_view = ctx.gml_view

	var inner: Control = null

	match input_type:
		"text", "password", "email", "number":
			inner = _build_text_input(node, input_type, style, gml_view)
		"checkbox":
			inner = _build_checkbox_input(node, style, gml_view)
		"range":
			inner = _build_range_input(node, style, gml_view)
		"submit":
			inner = _build_submit_button(node, style, ctx)
		_:
			inner = _build_text_input(node, "text", style, gml_view)

	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


## Build a text input (LineEdit).
static func _build_text_input(node, input_type: String, style: Dictionary, gml_view) -> Control:
	var line_edit := LineEdit.new()

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
static func _build_checkbox_input(node, style: Dictionary, gml_view) -> Control:
	var checkbox := CheckBox.new()

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

	return checkbox


## Build a range input (slider).
static func _build_range_input(node, style: Dictionary, gml_view) -> Control:
	var slider := HSlider.new()

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
	var gml_view = ctx.gml_view

	var text_edit := TextEdit.new()

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
	var gml_view = ctx.gml_view

	var option_button := OptionButton.new()

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
