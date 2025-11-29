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

	# Store layout direction for child flex-grow/shrink to use
	container.set_meta("is_row_layout", is_row)

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
			# Apply inherited text styles to text nodes (Label controls)
			if child.is_text_node and child_control is Label:
				GmlStyles.apply_text_color(child_control, style, defaults)
				GmlStyles.apply_text_styles(child_control, style, defaults)

			if not align_items.is_empty():
				var child_style = ctx.get_style.call(child) if not child.is_text_node else {}
				GmlStyles.apply_cross_axis_alignment(child_control, align_items, is_row, child_style)
			container.add_child(child_control)

	# Apply space distribution for space-between/around/evenly
	var justify = style.get("justify-content", "")
	if justify in ["space-between", "space-around", "space-evenly"]:
		_apply_space_distribution(container, justify, is_row)

	return container


## Apply space-between, space-around, or space-evenly distribution using spacer controls.
static func _apply_space_distribution(container: BoxContainer, justify: String, is_row: bool) -> void:
	var child_count = container.get_child_count()
	if child_count < 1:
		return

	# For single child with space-around/evenly, center it
	if child_count == 1:
		if justify in ["space-around", "space-evenly"]:
			container.alignment = BoxContainer.ALIGNMENT_CENTER
		return

	# Remove gap since we're using spacers for distribution
	container.add_theme_constant_override("separation", 0)

	var expand_flag = Control.SIZE_EXPAND_FILL

	match justify:
		"space-between":
			# Spacers between children only (no edge spacers)
			for i in range(child_count - 1, 0, -1):
				var spacer = Control.new()
				spacer.name = "_spacer_%d" % i
				if is_row:
					spacer.size_flags_horizontal = expand_flag
				else:
					spacer.size_flags_vertical = expand_flag
				container.add_child(spacer)
				container.move_child(spacer, i)

		"space-around":
			# Half-size spacers at edges, full spacers between
			for i in range(child_count, -1, -1):
				var spacer = Control.new()
				spacer.name = "_spacer_%d" % i
				if is_row:
					spacer.size_flags_horizontal = expand_flag
					if i == 0 or i == child_count:
						spacer.size_flags_stretch_ratio = 0.5
				else:
					spacer.size_flags_vertical = expand_flag
					if i == 0 or i == child_count:
						spacer.size_flags_stretch_ratio = 0.5
				container.add_child(spacer)
				container.move_child(spacer, i)

		"space-evenly":
			# Equal spacers everywhere including edges
			for i in range(child_count, -1, -1):
				var spacer = Control.new()
				spacer.name = "_spacer_%d" % i
				if is_row:
					spacer.size_flags_horizontal = expand_flag
				else:
					spacer.size_flags_vertical = expand_flag
				container.add_child(spacer)
				container.move_child(spacer, i)
