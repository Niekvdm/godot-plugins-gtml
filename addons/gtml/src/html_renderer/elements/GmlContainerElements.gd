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

	var display = style.get("display", "block")
	var flex_direction = style.get("flex-direction", "column")
	var flex_wrap = style.get("flex-wrap", "nowrap")
	var is_row = display == "flex" and flex_direction == "row"
	var is_wrapping = flex_wrap in ["wrap", "wrap-reverse"]

	var container: Control

	# Use FlowContainer for wrapping layouts, BoxContainer otherwise
	if is_wrapping:
		container = _create_flow_container(style, defaults, is_row, flex_wrap == "wrap-reverse")
	else:
		container = _create_box_container(style, defaults, is_row)

	# Store layout direction for child flex-grow/shrink to use
	container.set_meta("is_row_layout", is_row)
	container.set_meta("flex_wrap", flex_wrap)

	# Apply justify-content (main-axis alignment) - only for BoxContainer
	if style.has("justify-content") and container is BoxContainer:
		container.alignment = GmlStyles.parse_box_alignment(style["justify-content"])

	# Determine cross-axis alignment for children
	var align_items = style.get("align-items", "")

	# Build children with order support
	var children_with_order: Array = []
	for child in node.children:
		var child_control = ctx.build_node.call(child)
		if child_control != null:
			# Apply inherited text styles to text nodes (Label controls)
			if child.is_text_node and child_control is Label:
				GmlStyles.apply_text_color(child_control, style, defaults)
				GmlStyles.apply_text_styles(child_control, style, defaults)

			# Get child's style for align-self and order
			var child_style = ctx.get_style.call(child) if not child.is_text_node else {}

			# Check for align-self override
			var child_align = child_style.get("align-self", "")
			if not child_align.is_empty() and child_align != "auto":
				GmlStyles.apply_cross_axis_alignment(child_control, child_align, is_row, child_style)
			elif not align_items.is_empty():
				GmlStyles.apply_cross_axis_alignment(child_control, align_items, is_row, child_style)

			# Get order value (default 0)
			var order_value: float = child_style.get("order", 0.0)
			children_with_order.append({"control": child_control, "order": order_value})

	# Sort children by order value
	children_with_order.sort_custom(func(a, b): return a["order"] < b["order"])

	# Add children to container in sorted order
	for child_data in children_with_order:
		container.add_child(child_data["control"])

	# Apply space distribution for space-between/around/evenly (only for BoxContainer)
	var justify = style.get("justify-content", "")
	if justify in ["space-between", "space-around", "space-evenly"] and container is BoxContainer:
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


## Create a BoxContainer for non-wrapping flex layouts.
static func _create_box_container(style: Dictionary, defaults: Dictionary, is_row: bool) -> BoxContainer:
	var container: BoxContainer
	if is_row:
		container = HBoxContainer.new()
	else:
		container = VBoxContainer.new()

	# Apply gap (row-gap and column-gap, or unified gap)
	var base_gap: int = style.get("gap", defaults.get("default_gap", 8))
	if is_row:
		var gap: int = style.get("column-gap", base_gap)
		container.add_theme_constant_override("separation", gap)
	else:
		var gap: int = style.get("row-gap", base_gap)
		container.add_theme_constant_override("separation", gap)

	return container


## Create a FlowContainer for wrapping flex layouts.
static func _create_flow_container(style: Dictionary, defaults: Dictionary, is_row: bool, reverse: bool) -> FlowContainer:
	var container := FlowContainer.new()

	# FlowContainer is horizontal by default (like flex-direction: row)
	# For column direction, we'd need to use vertical property
	container.vertical = not is_row

	# FlowContainer has both horizontal and vertical separation
	var base_gap: int = style.get("gap", defaults.get("default_gap", 8))
	var h_gap: int = style.get("column-gap", base_gap)
	var v_gap: int = style.get("row-gap", base_gap)

	container.add_theme_constant_override("h_separation", h_gap)
	container.add_theme_constant_override("v_separation", v_gap)

	# FlowContainer supports alignment
	var align_items = style.get("align-items", "")
	match align_items:
		"flex-start", "start":
			container.alignment = FlowContainer.ALIGNMENT_BEGIN
		"center":
			container.alignment = FlowContainer.ALIGNMENT_CENTER
		"flex-end", "end":
			container.alignment = FlowContainer.ALIGNMENT_END

	# Store reverse flag for potential child ordering
	container.set_meta("flex_reverse", reverse)

	return container
