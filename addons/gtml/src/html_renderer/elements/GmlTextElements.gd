class_name GmlTextElements
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

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		return GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return label


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

	# Apply text-decoration if present
	var result_control: Control = label
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
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

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		return GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return label


## Build a label element.
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

	# Store the "for" attribute and enable click-to-focus behavior
	var for_id = node.get_attr("for", "")
	if not for_id.is_empty():
		label.set_meta("for", for_id)
		# Make label clickable and focus the associated input
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		if gml_view != null:
			var view_ref = weakref(gml_view)
			label.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					var view = view_ref.get_ref()
					if view != null:
						var target = view.get_element_by_id(for_id)
						if target != null and target is Control:
							target.grab_focus()
			)

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		return GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return label


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

	# Apply text-decoration if present
	if style.has("text-decoration"):
		return GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return label


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

	# Apply text-decoration if present
	if style.has("text-decoration"):
		var color: Color = style.get("color", defaults.get("default_font_color", Color.WHITE))
		return GmlStyles.apply_text_decoration(label, style["text-decoration"], color)

	return label
