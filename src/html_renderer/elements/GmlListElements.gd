class_name GmlListElements
extends RefCounted

## Static utility class for building list elements (ul, ol, li).


## Build an unordered or ordered list.
static func build_list(node, ordered: bool, ctx: Dictionary) -> Dictionary:
	var inner = _build_list_inner(node, ordered, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_list_inner(node, ordered: bool, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var container := VBoxContainer.new()

	var gap: int = style.get("gap", defaults.get("default_gap", 8))
	container.add_theme_constant_override("separation", gap)

	var item_number := 1

	for child in node.children:
		if child.tag == "li":
			var item_container := HBoxContainer.new()
			item_container.add_theme_constant_override("separation", 8)

			# Add bullet or number
			var marker := Label.new()
			if ordered:
				marker.text = "%d." % item_number
				item_number += 1
			else:
				marker.text = "•"

			var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
			marker.add_theme_font_size_override("font_size", font_size)
			marker.custom_minimum_size.x = 24 if ordered else 16

			item_container.add_child(marker)

			# Build the list item content
			var item_content := VBoxContainer.new()
			item_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			for li_child in child.children:
				var li_control = ctx.build_node.call(li_child)
				if li_control != null:
					item_content.add_child(li_control)

			# If no children, use text content
			if child.children.is_empty():
				var text_label := Label.new()
				text_label.text = child.get_text_content()
				text_label.add_theme_font_size_override("font_size", font_size)
				text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
				item_content.add_child(text_label)

			item_container.add_child(item_content)
			container.add_child(item_container)

	return container


## Build a list item (when used outside of ul/ol context).
static func build_list_item(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_list_item_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_list_item_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var defaults: Dictionary = ctx.defaults

	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# Add bullet
	var marker := Label.new()
	marker.text = "•"
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	marker.add_theme_font_size_override("font_size", font_size)
	marker.custom_minimum_size.x = 16
	container.add_child(marker)

	# Build content
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for child in node.children:
		var child_control = ctx.build_node.call(child)
		if child_control != null:
			content.add_child(child_control)

	if node.children.is_empty():
		var text_label := Label.new()
		text_label.text = node.get_text_content()
		text_label.add_theme_font_size_override("font_size", font_size)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(text_label)

	container.add_child(content)

	return container
