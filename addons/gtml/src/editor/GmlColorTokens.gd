class_name GmlColorTokens
extends RefCounted

## Scan a buffer for color literals and format them back.
## Token: {line: int, col: int, length: int, color: Color, kind: String}
## kind in {"hex", "rgb", "rgba"}.

const HEX_RE := "#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\\b"
const RGB_RE := "\\brgb\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*\\)"
const RGBA_RE := "\\brgba\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*[\\d.]+\\s*\\)"


static func scan(text: String) -> Array:
	var out: Array = []
	var lines := text.split("\n")
	for line_idx in range(lines.size()):
		var line: String = lines[line_idx]
		_append_matches(out, line, line_idx, HEX_RE, "hex", _hex_to_color)
		_append_matches(out, line, line_idx, RGB_RE, "rgb", _rgb_to_color)
		_append_matches(out, line, line_idx, RGBA_RE, "rgba", _rgba_to_color)
	return out


static func format(color: Color, kind: String) -> String:
	match kind:
		"rgb":
			return "rgb(%d, %d, %d)" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255))]
		"rgba":
			return "rgba(%d, %d, %d, %s)" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255)), str(color.a).pad_decimals(2)]
		_:
			if color.a < 0.999:
				return "#%02x%02x%02x%02x" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255)), int(round(color.a * 255))]
			return "#%02x%02x%02x" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255))]


# Internals

static func _append_matches(out: Array, line: String, line_idx: int, pattern: String, kind: String, color_fn: Callable) -> void:
	var re := RegEx.new()
	re.compile(pattern)
	for m in re.search_all(line):
		var literal := m.get_string()
		var color = color_fn.call(literal)
		if color == null:
			continue
		out.append({
			"line": line_idx,
			"col": m.get_start(),
			"length": m.get_end() - m.get_start(),
			"color": color,
			"kind": kind,
		})


static func _hex_to_color(literal: String) -> Variant:
	var body := literal.substr(1)
	if body.length() == 3:
		var c0 := body.substr(0, 1)
		var c1 := body.substr(1, 1)
		var c2 := body.substr(2, 1)
		body = c0 + c0 + c1 + c1 + c2 + c2
	var r := body.substr(0, 2).hex_to_int() / 255.0
	var g := body.substr(2, 2).hex_to_int() / 255.0
	var b := body.substr(4, 2).hex_to_int() / 255.0
	var a := 1.0
	if body.length() == 8:
		a = body.substr(6, 2).hex_to_int() / 255.0
	return Color(r, g, b, a)


static func _rgb_to_color(literal: String) -> Variant:
	var nums := _extract_nums(literal)
	if nums.size() < 3:
		return null
	return Color(nums[0] / 255.0, nums[1] / 255.0, nums[2] / 255.0, 1.0)


static func _rgba_to_color(literal: String) -> Variant:
	var nums := _extract_nums(literal)
	if nums.size() < 4:
		return null
	return Color(nums[0] / 255.0, nums[1] / 255.0, nums[2] / 255.0, nums[3])


static func _extract_nums(literal: String) -> Array:
	var re := RegEx.new()
	re.compile("[\\d.]+")
	var out: Array = []
	for m in re.search_all(literal):
		out.append(m.get_string().to_float())
	return out
