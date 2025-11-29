class_name GmlBorderValues
extends RefCounted

## Static utility class for parsing CSS border-related values.
## Handles border shorthand and box-shadow.


## Parse border shorthand (e.g., "2px solid #ff0000" or "none").
## Returns a Dictionary with "width", "style", and "color" keys.
static func parse_border(value: String) -> Dictionary:
	value = value.strip_edges()

	# Handle "none" as a special case
	if value.to_lower() == "none":
		return {"width": 0, "style": "none", "color": Color.TRANSPARENT}

	var parts = value.split(" ", false)
	var result = {"width": 1, "style": "solid", "color": Color.WHITE}

	for part in parts:
		part = part.strip_edges()
		if part.ends_with("px"):
			result["width"] = part.substr(0, part.length() - 2).to_int()
		elif part.is_valid_int():
			result["width"] = part.to_int()
		elif part.begins_with("#"):
			result["color"] = Color.html(part)
		elif part in ["solid", "dashed", "dotted", "none"]:
			result["style"] = part
			# If style is none, set width to 0
			if part == "none":
				result["width"] = 0
		else:
			# Try as named color
			var color = GmlColorValues.parse_color(part)
			if color != Color.WHITE or part.to_lower() == "white":
				result["color"] = color

	return result


## Parse box-shadow (e.g., "4px 4px 8px rgba(0, 0, 0, 0.5)" or "0 4px 8px 2px #000000").
## Supports: offset-x offset-y [blur-radius] [spread-radius] [color] [inset]
## Returns a Dictionary with shadow properties.
static func parse_box_shadow(value: String) -> Dictionary:
	value = value.strip_edges()

	# Handle "none"
	if value == "none":
		return {"none": true}

	var result = {
		"offset_x": 0,
		"offset_y": 0,
		"blur": 0,
		"spread": 0,
		"color": Color(0, 0, 0, 0.5),
		"inset": false
	}

	# Check for inset keyword
	if value.begins_with("inset "):
		result["inset"] = true
		value = value.substr(6).strip_edges()
	elif value.ends_with(" inset"):
		result["inset"] = true
		value = value.substr(0, value.length() - 6).strip_edges()

	# Extract color if it's rgba/rgb (contains parentheses)
	var color_start = value.find("rgba(")
	if color_start == -1:
		color_start = value.find("rgb(")
	if color_start != -1:
		var paren_count = 0
		var color_end = color_start
		for i in range(color_start, value.length()):
			if value[i] == "(":
				paren_count += 1
			elif value[i] == ")":
				paren_count -= 1
				if paren_count == 0:
					color_end = i + 1
					break
		var color_str = value.substr(color_start, color_end - color_start)
		result["color"] = GmlColorValues.parse_color(color_str)
		value = value.substr(0, color_start) + value.substr(color_end)
		value = value.strip_edges()

	# Now parse remaining parts (numbers and possibly hex color)
	var parts = value.split(" ", false)
	var num_index = 0

	for part in parts:
		part = part.strip_edges()
		if part.is_empty():
			continue

		# Check if it's a number (with or without px)
		var num_value = 0
		var is_number = false

		if part.ends_with("px"):
			num_value = part.substr(0, part.length() - 2).to_int()
			is_number = true
		elif part.is_valid_int() or (part.begins_with("-") and part.substr(1).is_valid_int()):
			num_value = part.to_int()
			is_number = true
		elif part.is_valid_float():
			num_value = int(part.to_float())
			is_number = true

		if is_number:
			match num_index:
				0: result["offset_x"] = num_value
				1: result["offset_y"] = num_value
				2: result["blur"] = num_value
				3: result["spread"] = num_value
			num_index += 1
		elif part.begins_with("#"):
			result["color"] = Color.html(part)
		else:
			# Try as named color
			var color = GmlColorValues.parse_color(part)
			if color != Color.WHITE or part.to_lower() == "white":
				result["color"] = color

	return result
