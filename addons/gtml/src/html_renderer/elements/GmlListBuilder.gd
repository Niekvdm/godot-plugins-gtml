class_name GmlListBuilder
extends RefCounted

## Static utility class for building list elements (ul, ol, li).

# Bullet characters for different list-style-types
const BULLETS = {
	"disc": "•",
	"circle": "○",
	"square": "■",
	"none": ""
}


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

	# Get list-style-type (defaults based on ordered/unordered)
	var list_style: String = style.get("list-style-type", "decimal" if ordered else "disc")

	var item_number := 1

	for child in node.children:
		if child.tag == "li":
			var item_container := HBoxContainer.new()
			item_container.add_theme_constant_override("separation", 8)

			# Add bullet or number based on list-style-type
			var marker := Label.new()
			marker.text = _get_marker_text(list_style, item_number, ordered)
			if list_style != "none":
				item_number += 1

			var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
			marker.add_theme_font_size_override("font_size", font_size)
			marker.custom_minimum_size.x = _get_marker_width(list_style, ordered)

			# Hide marker if list-style-type is none
			if list_style == "none":
				marker.visible = false
				marker.custom_minimum_size.x = 0

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


## Get marker text based on list-style-type.
static func _get_marker_text(list_style: String, number: int, ordered: bool) -> String:
	match list_style:
		"none":
			return ""
		"disc":
			return "•"
		"circle":
			return "○"
		"square":
			return "■"
		"decimal":
			return "%d." % number
		"decimal-leading-zero":
			return "%02d." % number
		"lower-alpha", "lower-latin":
			return "%s." % _number_to_alpha(number, false)
		"upper-alpha", "upper-latin":
			return "%s." % _number_to_alpha(number, true)
		"lower-roman":
			return "%s." % _number_to_roman(number, false)
		"upper-roman":
			return "%s." % _number_to_roman(number, true)
		_:
			# Default based on ordered/unordered
			if ordered:
				return "%d." % number
			else:
				return "•"


## Get marker width based on list-style-type.
static func _get_marker_width(list_style: String, ordered: bool) -> int:
	match list_style:
		"none":
			return 0
		"disc", "circle", "square":
			return 16
		"decimal", "decimal-leading-zero":
			return 24
		"lower-alpha", "upper-alpha", "lower-latin", "upper-latin":
			return 24
		"lower-roman", "upper-roman":
			return 32  # Roman numerals can be wider
		_:
			return 24 if ordered else 16


## Convert number to alphabetic (a, b, c, ... z, aa, ab, ...)
static func _number_to_alpha(n: int, uppercase: bool) -> String:
	var result := ""
	while n > 0:
		n -= 1
		var char_code = (n % 26) + (65 if uppercase else 97)  # A=65, a=97
		result = char(char_code) + result
		n = n / 26
	return result if not result.is_empty() else ("A" if uppercase else "a")


## Convert number to Roman numerals.
static func _number_to_roman(n: int, uppercase: bool) -> String:
	if n <= 0 or n > 3999:
		return str(n)

	var roman_numerals = [
		[1000, "m"], [900, "cm"], [500, "d"], [400, "cd"],
		[100, "c"], [90, "xc"], [50, "l"], [40, "xl"],
		[10, "x"], [9, "ix"], [5, "v"], [4, "iv"], [1, "i"]
	]

	var result := ""
	for pair in roman_numerals:
		while n >= pair[0]:
			result += pair[1]
			n -= pair[0]

	return result.to_upper() if uppercase else result


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

	# Get list-style-type from style (defaults to disc for standalone li)
	var list_style: String = style.get("list-style-type", "disc")

	# Add bullet/marker
	var marker := Label.new()
	marker.text = _get_marker_text(list_style, 1, false)
	var font_size: int = style.get("font-size", defaults.get("p_font_size", 16))
	marker.add_theme_font_size_override("font_size", font_size)
	marker.custom_minimum_size.x = _get_marker_width(list_style, false)

	# Hide marker if list-style-type is none
	if list_style == "none":
		marker.visible = false
		marker.custom_minimum_size.x = 0

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
