class_name GmlColorValues
extends RefCounted

## Static utility class for parsing CSS color values.
## Supports hex, rgb(), rgba(), and named colors.


## Parse a color value string into a Godot Color.
## Supports: #hex, rgb(), rgba(), and named colors.
static func parse_color(value: String) -> Color:
	value = value.strip_edges()

	# Hex color
	if value.begins_with("#"):
		return Color.html(value)

	# rgba(r, g, b, a)
	if value.begins_with("rgba(") and value.ends_with(")"):
		var inner = value.substr(5, value.length() - 6)
		var parts = inner.split(",")
		if parts.size() >= 4:
			var r = parts[0].strip_edges().to_float() / 255.0
			var g = parts[1].strip_edges().to_float() / 255.0
			var b = parts[2].strip_edges().to_float() / 255.0
			var a = parts[3].strip_edges().to_float()
			return Color(r, g, b, a)
		push_warning("GmlColorValues: Invalid rgba() format '%s'" % value)
		return Color.WHITE

	# rgb(r, g, b)
	if value.begins_with("rgb(") and value.ends_with(")"):
		var inner = value.substr(4, value.length() - 5)
		var parts = inner.split(",")
		if parts.size() >= 3:
			var r = parts[0].strip_edges().to_float() / 255.0
			var g = parts[1].strip_edges().to_float() / 255.0
			var b = parts[2].strip_edges().to_float() / 255.0
			return Color(r, g, b, 1.0)
		push_warning("GmlColorValues: Invalid rgb() format '%s'" % value)
		return Color.WHITE

	# Named colors
	return parse_named_color(value)


## Parse a named color into a Godot Color.
static func parse_named_color(name: String) -> Color:
	match name.to_lower():
		"white": return Color.WHITE
		"black": return Color.BLACK
		"red": return Color.RED
		"green": return Color.GREEN
		"blue": return Color.BLUE
		"yellow": return Color.YELLOW
		"cyan": return Color.CYAN
		"magenta": return Color.MAGENTA
		"gray", "grey": return Color.GRAY
		"transparent": return Color.TRANSPARENT
		_:
			push_warning("GmlColorValues: Unknown color '%s'" % name)
			return Color.WHITE
