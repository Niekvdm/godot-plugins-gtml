class_name GmlFontValues
extends RefCounted

## Static utility class for parsing CSS font-related values.
## Handles font-family, font-weight, and letter-spacing.


## Parse font-family value (e.g., "'Orbitron', sans-serif" or "Rajdhani").
## Returns the first font name as a string (stripped of quotes).
static func parse_font_family(value: String) -> String:
	value = value.strip_edges()

	# Split by comma to get font stack
	var fonts = value.split(",")
	if fonts.is_empty():
		return ""

	# Get the first font name
	var first_font = fonts[0].strip_edges()

	# Remove quotes if present
	first_font = first_font.trim_prefix("\"").trim_suffix("\"")
	first_font = first_font.trim_prefix("'").trim_suffix("'")

	return first_font


## Parse font-weight value (e.g., "bold", "normal", "700", "950").
## Returns an int: 100 = thin, 400 = normal, 700 = bold, 900-950 = black/extra-bold.
static func parse_font_weight(value: String) -> int:
	value = value.strip_edges().to_lower()

	match value:
		"thin", "hairline":
			return 100
		"extralight", "extra-light", "ultralight", "ultra-light":
			return 200
		"light", "lighter":
			return 300
		"normal", "regular":
			return 400
		"medium":
			return 500
		"semibold", "semi-bold", "demibold", "demi-bold":
			return 600
		"bold":
			return 700
		"extrabold", "extra-bold", "ultrabold", "ultra-bold", "bolder":
			return 800
		"black", "heavy":
			return 900
		"extrablack", "extra-black", "ultrablack", "ultra-black":
			return 950
		_:
			# Try parsing as numeric value (100-950)
			if value.is_valid_int():
				return clampi(value.to_int(), 100, 950)
			return 400


## Parse letter-spacing value (e.g., "0.1em", "2px", "normal").
## Returns a float representing the spacing in pixels.
## For "em" units, multiplies by a base size of 16px.
static func parse_letter_spacing(value: String) -> float:
	value = value.strip_edges().to_lower()

	if value == "normal":
		return 0.0

	# Handle "em" units (relative to font size, we use 16px as base)
	if value.ends_with("em"):
		var num_str = value.substr(0, value.length() - 2)
		return num_str.to_float() * 16.0

	# Handle "px" units
	if value.ends_with("px"):
		var num_str = value.substr(0, value.length() - 2)
		return num_str.to_float()

	# Assume pixels if no unit
	return value.to_float()
