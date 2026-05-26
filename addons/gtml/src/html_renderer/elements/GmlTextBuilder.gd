class_name GmlTextBuilder
extends RefCounted

## Static utility class for building text elements (p, span, h1-h6, label).


## Build a paragraph element.
static func build_paragraph(node, ctx: Dictionary) -> Dictionary:
	var inner = build_paragraph_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func build_paragraph_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD

	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	label.add_theme_font_size_override("font_size", font_size)

	label.text = node.get_text_content()

	GmlStyles.apply_text_color(label, style, defaults)
	GmlStyles.apply_text_styles(label, style, defaults)

	var result: Control = label

	# Apply text-shadow if present (shadow goes behind, so apply first)
	if style.has("text-shadow"):
		result = GmlStyles.apply_text_shadow(label, style["text-shadow"])

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		if result == label:
			result = GmlStyles.apply_text_decoration(label, style["text-decoration"], color)
		# Note: If both shadow and decoration, decoration is applied to the label
		# which is already inside the shadow container

	return result


## Build a span element.
static func build_span(node, ctx: Dictionary) -> Dictionary:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var label := Label.new()
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	label.add_theme_font_size_override("font_size", font_size)

	label.text = node.get_text_content()

	GmlStyles.apply_text_color(label, style, defaults)
	GmlStyles.apply_text_styles(label, style, defaults)

	var result_control: Control = label

	# Apply text-shadow if present
	if style.has("text-shadow"):
		result_control = GmlStyles.apply_text_shadow(label, style["text-shadow"])

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		if result_control == label:
			result_control = GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return {"control": result_control, "inner": label}


## Build a heading element.
static func build_heading(node, level: int, ctx: Dictionary) -> Dictionary:
	var inner = build_heading_inner(node, level, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func build_heading_inner(node, level: int, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var label := Label.new()

	# Get font size from defaults or style
	# HTML5 spec: h1=2em(32px), h2=1.5em(24px), h3=1.17em(~19px), h4=1em(16px), h5=0.83em(~13px), h6=0.67em(~11px)
	var default_size: int
	match level:
		1: default_size = defaults.get("h1_font_size", 32)
		2: default_size = defaults.get("h2_font_size", 24)
		3: default_size = defaults.get("h3_font_size", 19)
		4: default_size = defaults.get("h4_font_size", 16)
		5: default_size = defaults.get("h5_font_size", 13)
		6: default_size = defaults.get("h6_font_size", 11)
		_: default_size = defaults.get("p_font_size", 16)

	var font_size: int = style.get("font-size", default_size)
	label.add_theme_font_size_override("font_size", font_size)

	label.text = node.get_text_content()

	GmlStyles.apply_text_color(label, style, defaults)
	GmlStyles.apply_text_styles(label, style, defaults)

	var result: Control = label

	# Apply text-shadow if present
	if style.has("text-shadow"):
		result = GmlStyles.apply_text_shadow(label, style["text-shadow"])

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		if result == label:
			result = GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return result


## Build a label element.
## Handle a label-for click against the resolved target Control. Matches
## the standard HTML semantics:
##   - radio (BaseButton with button_group): set pressed=true unconditionally
##     so clicking the label of an already-selected radio does not deselect
##     it (which would also leave the whole group unselected)
##   - checkbox / toggle BaseButton (no group): invert button_pressed
##   - LineEdit / TextEdit / other Control: grab_focus
static func _activate_for_target(target) -> void:
	if target is BaseButton:
		var btn: BaseButton = target
		if btn.button_group != null:
			btn.button_pressed = true
		else:
			btn.button_pressed = not btn.button_pressed
		btn.grab_focus()
		return
	if target is Control:
		(target as Control).grab_focus()


static func build_label(node, ctx: Dictionary) -> Dictionary:
	var inner = build_label_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func build_label_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults
	var gml_view = ctx.gml_view

	var label := Label.new()
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	label.add_theme_font_size_override("font_size", font_size)

	label.text = node.get_text_content()

	GmlStyles.apply_text_color(label, style, defaults)
	GmlStyles.apply_text_styles(label, style, defaults)

	# Wire `for="x"` attribute: clicking the label activates the input
	# referenced by id. CheckBoxes toggle, radio inputs select (never deselect
	# their group), and text inputs grab focus. Lookup is deferred to click
	# time so the input may appear after the label in source order.
	var for_id = node.get_attr("for", "")
	if not for_id.is_empty():
		label.set_meta("for", for_id)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if gml_view != null:
			var view_ref = weakref(gml_view)
			label.gui_input.connect(func(event: InputEvent):
				if not (event is InputEventMouseButton):
					return
				if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
					return
				var view = view_ref.get_ref()
				if view == null:
					return
				var target = view.get_element_by_id(for_id)
				if target == null:
					return
				_activate_for_target(target)
			)

	var result: Control = label

	# Apply text-shadow if present
	if style.has("text-shadow"):
		result = GmlStyles.apply_text_shadow(label, style["text-shadow"])

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		if result == label:
			result = GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return result


## Build bold text.
static func build_bold(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var label := Label.new()
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	label.add_theme_font_size_override("font_size", font_size)

	label.text = node.get_text_content()

	GmlStyles.apply_text_color(label, style, defaults)
	GmlStyles.apply_text_styles(label, style, defaults)

	# Apply bold styling using outline
	label.add_theme_constant_override("outline_size", 1)
	var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
	label.add_theme_color_override("font_outline_color", color)

	var result: Control = label

	# Apply text-shadow if present
	if style.has("text-shadow"):
		result = GmlStyles.apply_text_shadow(label, style["text-shadow"])

	# Apply text-decoration if present
	if style.has("text-decoration"):
		if result == label:
			result = GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return result


## Build italic text.
static func build_italic(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var label := Label.new()
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	label.add_theme_font_size_override("font_size", font_size)

	label.text = node.get_text_content()

	GmlStyles.apply_text_color(label, style, defaults)
	GmlStyles.apply_text_styles(label, style, defaults)

	# Store italic flag for custom font handling
	label.set_meta("font_style", "italic")

	var result: Control = label

	# Apply text-shadow if present
	if style.has("text-shadow"):
		result = GmlStyles.apply_text_shadow(label, style["text-shadow"])

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		if result == label:
			result = GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return result
