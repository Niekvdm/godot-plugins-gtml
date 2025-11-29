class_name GmlAnchorElements
extends RefCounted

## Static utility class for building anchor/link elements.


## Build an anchor element (<a>).
## Renders as a clickable label/rich text that emits link_clicked signal.
static func build_anchor(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_anchor_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_anchor_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults
	var gml_view = ctx.gml_view

	var href: String = node.get_attr("href") if node.has_attr("href") else ""
	var target: String = node.get_attr("target") if node.has_attr("target") else ""

	# Check if anchor has complex children (like SVG icons)
	var has_complex_children := false
	for child in node.children:
		if not child.is_text_node:
			has_complex_children = true
			break

	if has_complex_children:
		return _build_complex_anchor(node, ctx, style, defaults, gml_view, href, target)
	else:
		return _build_simple_anchor(node, ctx, style, defaults, gml_view, href, target)


static func _build_simple_anchor(node, ctx: Dictionary, style: Dictionary, defaults: Dictionary, gml_view, href: String, target: String) -> Control:
	# Check for @click attribute (like buttons)
	var click_handler: String = node.get_attr("@click", "")
	var has_click := not click_handler.is_empty()
	var has_href := not href.is_empty()

	var text_content: String = node.get_text_content()

	# Use LinkButton for proper flex layout compatibility
	var link := LinkButton.new()
	link.text = text_content

	# Get link color (default to typical link blue)
	var link_color: Color = style.get("color", Color(0.4, 0.6, 1.0, 1.0))
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))

	# Apply text decoration
	var text_decoration: String = style.get("text-decoration", "underline")
	match text_decoration:
		"underline":
			link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
		"none":
			link.underline = LinkButton.UNDERLINE_MODE_NEVER
		_:
			link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER

	# Apply font size
	link.add_theme_font_size_override("font_size", font_size)

	# Apply colors
	link.add_theme_color_override("font_color", link_color)
	link.add_theme_color_override("font_hover_color", link_color.lightened(0.2))
	link.add_theme_color_override("font_pressed_color", link_color.darkened(0.1))
	link.add_theme_color_override("font_focus_color", link_color)

	# Font family
	if style.has("font-family"):
		var font_name: String = style["font-family"]
		var fonts_dict: Dictionary = defaults.get("fonts", {})
		if fonts_dict.has(font_name):
			var font = fonts_dict[font_name]
			if font is Font:
				link.add_theme_font_override("font", font)

	# Connect pressed signal
	if gml_view != null:
		var view_ref = weakref(gml_view)
		var href_copy = href
		var target_copy = target
		var handler_copy = click_handler

		link.pressed.connect(func():
			var view = view_ref.get_ref()
			if view != null:
				# Emit @click handler if present, otherwise emit link_clicked
				if has_click:
					view.button_clicked.emit(handler_copy)
				elif has_href:
					view.link_clicked.emit(href_copy, target_copy)
		)

	return link


static func _build_complex_anchor(node, ctx: Dictionary, style: Dictionary, defaults: Dictionary, gml_view, href: String, target: String) -> Control:
	# Check for @click attribute
	var click_handler: String = node.get_attr("@click", "")
	var has_click := not click_handler.is_empty()
	var has_href := not href.is_empty()

	# Create a button-like container for complex anchor content
	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_theme_constant_override("separation", 4)

	# Build children
	for child in node.children:
		var child_control = ctx.build_node.call(child)
		if child_control != null:
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(child_control)

	# Apply link color to container (for text children)
	var link_color: Color = style.get("color", Color(0.4, 0.6, 1.0, 1.0))

	# Make the entire container clickable
	if gml_view != null:
		var view_ref = weakref(gml_view)
		var href_copy = href
		var target_copy = target
		var handler_copy = click_handler
		container.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					var view = view_ref.get_ref()
					if view != null:
						# Emit @click handler if present, otherwise emit link_clicked
						if has_click:
							view.button_clicked.emit(handler_copy)
						elif has_href:
							view.link_clicked.emit(href_copy, target_copy)
		)

	# Show pointer cursor for clickable anchors
	if has_click or has_href:
		container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Apply dimensions
	if style.has("width"):
		var width_dim = style["width"]
		if width_dim is Dictionary:
			match width_dim.get("unit", ""):
				"px":
					container.custom_minimum_size.x = width_dim["value"]
				"%":
					if width_dim["value"] >= 100:
						container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if style.has("height"):
		var height_dim = style["height"]
		if height_dim is Dictionary:
			match height_dim.get("unit", ""):
				"px":
					container.custom_minimum_size.y = height_dim["value"]
				"%":
					if height_dim["value"] >= 100:
						container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	return container
