class_name GmlContainerElements
extends RefCounted

## Static utility class for building container elements (div, section, form, etc.).


## Build a div element with inner reference.
## ctx contains: styles, defaults, gml_view, build_node (Callable), get_style (Callable), wrap_with_margin_padding (Callable)
static func build_div(node, ctx: Dictionary) -> Dictionary:
	var inner = build_div_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


## Build a div element inner content.
static func build_div_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var container: BoxContainer
	var display = style.get("display", "block")
	var flex_direction = style.get("flex-direction", "column")
	var is_row = display == "flex" and flex_direction == "row"

	if is_row:
		container = HBoxContainer.new()
	else:
		container = VBoxContainer.new()

	# Apply gap
	var gap: int = style.get("gap", defaults.get("default_gap", 8))
	container.add_theme_constant_override("separation", gap)

	# Apply justify-content (main-axis alignment)
	if style.has("justify-content"):
		container.alignment = GmlStyles.parse_box_alignment(style["justify-content"])

	# Determine cross-axis alignment for children
	var align_items = style.get("align-items", "")

	# Build children
	for child in node.children:
		var child_control = ctx.build_node.call(child)
		if child_control != null:
			if not align_items.is_empty():
				var child_style = ctx.get_style.call(child) if not child.is_text_node else {}
				GmlStyles.apply_cross_axis_alignment(child_control, align_items, is_row, child_style)
			container.add_child(child_control)

	return container
