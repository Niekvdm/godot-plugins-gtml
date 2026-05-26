class_name GmlWrap
extends RefCounted

## Wraps a content Control with the chain of decorator containers required by
## its CSS style: padding -> gradient-background -> color+border-background
## -> margin -> scroll -> outline.
##
## The wrap chain has a fixed order. Each layer is appended only when the
## style demands it, so the final tree depth is the minimum needed to render
## the requested boxes correctly.


## Public entrypoint. Returns the outermost wrapping control (the same
## ``control`` instance if no wrapping was needed).
static func apply(control: Control, style: Dictionary) -> Control:
	var has_margin := _has_box_prop(style, "margin")
	var has_padding := _has_box_prop(style, "padding")
	var has_bg: bool = style.has("background-color")
	var has_gradient: bool = style.has("background") or style.has("background-image")
	var has_border := _has_border(style)
	var has_scroll := _has_scroll(style)
	var has_outline := _has_outline(style)

	if not (has_margin or has_padding or has_bg or has_gradient or has_border or has_scroll or has_outline):
		return control

	var result := control

	if has_padding:
		result = _wrap_padding(result, style)

	var gradient_applied := false
	if has_gradient:
		var wrapped := _wrap_gradient(result, style)
		if wrapped != null:
			result = wrapped
			gradient_applied = true

	if (has_bg or has_border) and not gradient_applied:
		result = _wrap_bg_and_border(result, style, has_bg, has_border)
	elif gradient_applied and has_border:
		result = _wrap_border_only(result, style)

	if has_margin:
		result = _wrap_margin(result, style)

	if has_scroll:
		result = _wrap_scroll(result, style)

	if has_outline:
		var outline = style["outline"]
		if outline is Dictionary and outline.get("style", "solid") != "none" and outline.get("width", 0) > 0:
			var offset: int = style.get("outline-offset", 0)
			result = GmlStyles.apply_outline(result, outline, offset)

	return result


static func _has_box_prop(style: Dictionary, base: String) -> bool:
	if style.has(base) and style[base] > 0:
		return true
	for side in ["-top", "-right", "-bottom", "-left"]:
		if style.has(base + side):
			return true
	return false


static func _has_border(style: Dictionary) -> bool:
	var keys := [
		"border", "border-width", "border-radius",
		"border-top", "border-right", "border-bottom", "border-left",
		"border-top-width", "border-right-width", "border-bottom-width", "border-left-width",
		"box-shadow",
	]
	for k in keys:
		if style.has(k):
			return true
	return false


static func _has_scroll(style: Dictionary) -> bool:
	for k in ["overflow", "overflow-x", "overflow-y"]:
		if style.get(k, "") in ["scroll", "auto"]:
			return true
	return false


static func _has_outline(style: Dictionary) -> bool:
	return style.has("outline")


static func _wrap_padding(content: Control, style: Dictionary) -> Control:
	var base_pad: int = style.get("padding", 0)
	var c := MarginContainer.new()
	c.add_theme_constant_override("margin_left", style.get("padding-left", base_pad))
	c.add_theme_constant_override("margin_right", style.get("padding-right", base_pad))
	c.add_theme_constant_override("margin_top", style.get("padding-top", base_pad))
	c.add_theme_constant_override("margin_bottom", style.get("padding-bottom", base_pad))
	# Mouse-pass-through so the outer Panel keeps receiving hover events
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(content)
	return c


static func _wrap_margin(content: Control, style: Dictionary) -> Control:
	var base_mar: int = style.get("margin", 0)
	var c := MarginContainer.new()
	c.add_theme_constant_override("margin_left", style.get("margin-left", base_mar))
	c.add_theme_constant_override("margin_right", style.get("margin-right", base_mar))
	c.add_theme_constant_override("margin_top", style.get("margin-top", base_mar))
	c.add_theme_constant_override("margin_bottom", style.get("margin-bottom", base_mar))
	c.add_child(content)
	return c


static func _wrap_gradient(content: Control, style: Dictionary) -> Control:
	var bg_data = style.get("background", style.get("background-image", {}))
	if not (bg_data is Dictionary):
		return null
	if not (bg_data.get("type", "") in ["linear-gradient", "radial-gradient", "image"]):
		return null
	var container := GmlBackgrounds.create(bg_data, style)
	if container == null:
		return null
	container.add_child(content)
	return container


static func _wrap_bg_and_border(content: Control, style: Dictionary, has_bg: bool, has_border: bool) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = style["background-color"] if has_bg else Color.TRANSPARENT
	if has_border:
		GmlStyles.apply_border_to_stylebox(box, style)
	panel.add_theme_stylebox_override("panel", box)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(content)
	return panel


static func _wrap_border_only(content: Control, style: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	GmlStyles.apply_border_to_stylebox(box, style)
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(content)
	return panel


static func _wrap_scroll(content: Control, style: Dictionary) -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var overflow: String = style.get("overflow", "")
	var overflow_x: String = style.get("overflow-x", overflow)
	var overflow_y: String = style.get("overflow-y", overflow)

	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
		if overflow_x in ["scroll", "auto"] else ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
		if overflow_y in ["scroll", "auto"] else ScrollContainer.SCROLL_MODE_DISABLED

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN \
		if overflow_y in ["scroll", "auto"] else Control.SIZE_EXPAND_FILL

	sc.follow_focus = true
	sc.add_child(content)
	return sc
