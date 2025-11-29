class_name GmlBackgroundValues
extends RefCounted

## Static utility class for parsing CSS background values.
## Handles linear-gradient, radial-gradient, url(), and solid colors.


## Parse background value (color, gradient, or image).
## Returns a Dictionary with "type" and relevant data.
static func parse_background(value: String) -> Dictionary:
	value = value.strip_edges()

	# Check for linear-gradient
	if value.begins_with("linear-gradient("):
		return parse_linear_gradient(value)

	# Check for radial-gradient
	if value.begins_with("radial-gradient("):
		return parse_radial_gradient(value)

	# Check for url() - image
	if value.begins_with("url("):
		var url_content = _extract_function_content(value, "url")
		# Remove quotes if present
		url_content = url_content.trim_prefix("\"").trim_suffix("\"")
		url_content = url_content.trim_prefix("'").trim_suffix("'")
		return {"type": "image", "url": url_content}

	# Fallback to color
	return {"type": "color", "color": GmlColorValues.parse_color(value)}


## Parse linear-gradient function.
## e.g., "linear-gradient(to right, #ff0000, #0000ff)"
## e.g., "linear-gradient(45deg, red, blue)"
static func parse_linear_gradient(value: String) -> Dictionary:
	var content = _extract_function_content(value, "linear-gradient")
	var parts = _split_gradient_args(content)

	var result = {
		"type": "linear-gradient",
		"angle": 180.0,  # Default: top to bottom
		"colors": [],
		"offsets": []
	}

	var start_index = 0

	# Check if first part is direction or angle
	if parts.size() > 0:
		var first = parts[0].strip_edges()
		if first.begins_with("to "):
			result["angle"] = _parse_gradient_direction(first)
			start_index = 1
		elif first.ends_with("deg"):
			result["angle"] = first.trim_suffix("deg").to_float()
			start_index = 1

	# Parse color stops
	for i in range(start_index, parts.size()):
		var stop = parts[i].strip_edges()
		var color_offset = parse_color_stop(stop)
		result["colors"].append(color_offset["color"])
		if color_offset.has("offset"):
			result["offsets"].append(color_offset["offset"])
		else:
			# Auto-calculate offset based on position
			var total = parts.size() - start_index
			if total > 1:
				result["offsets"].append(float(i - start_index) / float(total - 1))
			else:
				result["offsets"].append(0.0)

	return result


## Parse radial-gradient function.
## e.g., "radial-gradient(circle, #ff0000, #0000ff)"
static func parse_radial_gradient(value: String) -> Dictionary:
	var content = _extract_function_content(value, "radial-gradient")
	var parts = _split_gradient_args(content)

	var result = {
		"type": "radial-gradient",
		"shape": "ellipse",  # Default shape
		"colors": [],
		"offsets": []
	}

	var start_index = 0

	# Check if first part is shape
	if parts.size() > 0:
		var first = parts[0].strip_edges().to_lower()
		if first == "circle" or first == "ellipse":
			result["shape"] = first
			start_index = 1
		elif first.begins_with("circle") or first.begins_with("ellipse"):
			result["shape"] = "circle" if first.begins_with("circle") else "ellipse"
			start_index = 1

	# Parse color stops
	for i in range(start_index, parts.size()):
		var stop = parts[i].strip_edges()
		var color_offset = parse_color_stop(stop)
		result["colors"].append(color_offset["color"])
		if color_offset.has("offset"):
			result["offsets"].append(color_offset["offset"])
		else:
			var total = parts.size() - start_index
			if total > 1:
				result["offsets"].append(float(i - start_index) / float(total - 1))
			else:
				result["offsets"].append(0.0)

	return result


## Parse a color stop (e.g., "#ff0000", "red 50%", "#00ff00 25%").
static func parse_color_stop(stop: String) -> Dictionary:
	stop = stop.strip_edges()
	var parts = stop.split(" ", false)

	if parts.size() == 1:
		return {"color": GmlColorValues.parse_color(parts[0])}

	# Color with offset
	var color = GmlColorValues.parse_color(parts[0])
	var offset_str = parts[parts.size() - 1]
	var offset = 0.0

	if offset_str.ends_with("%"):
		offset = offset_str.trim_suffix("%").to_float() / 100.0
	else:
		offset = offset_str.to_float()

	return {"color": color, "offset": offset}


## Parse gradient direction (e.g., "to right", "to bottom left").
static func _parse_gradient_direction(direction: String) -> float:
	direction = direction.strip_edges().to_lower()
	match direction:
		"to top": return 0.0
		"to top right", "to right top": return 45.0
		"to right": return 90.0
		"to bottom right", "to right bottom": return 135.0
		"to bottom": return 180.0
		"to bottom left", "to left bottom": return 225.0
		"to left": return 270.0
		"to top left", "to left top": return 315.0
		_: return 180.0


## Extract content inside a function call like "linear-gradient(...)".
static func _extract_function_content(value: String, func_name: String) -> String:
	var start = value.find("(")
	var end = value.rfind(")")
	if start == -1 or end == -1 or end <= start:
		return ""
	return value.substr(start + 1, end - start - 1)


## Split gradient arguments, respecting parentheses (for nested functions like rgba()).
static func _split_gradient_args(content: String) -> Array:
	var result = []
	var current = ""
	var paren_depth = 0

	for ch in content:
		if ch == "(":
			paren_depth += 1
			current += ch
		elif ch == ")":
			paren_depth -= 1
			current += ch
		elif ch == "," and paren_depth == 0:
			result.append(current.strip_edges())
			current = ""
		else:
			current += ch

	if not current.strip_edges().is_empty():
		result.append(current.strip_edges())

	return result
