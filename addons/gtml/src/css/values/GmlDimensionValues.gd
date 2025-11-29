class_name GmlDimensionValues
extends RefCounted

## Static utility class for parsing CSS dimension and size values.
## Handles px, %, auto units and numeric values.


## Parse a dimension value with unit (e.g., "100%", "200px", "auto").
## Returns a Dictionary with "value" and "unit" keys.
static func parse_dimension(value: String) -> Dictionary:
	value = value.strip_edges()

	if value == "auto":
		return {"value": 0, "unit": "auto"}

	if value.ends_with("%"):
		var num_str = value.substr(0, value.length() - 1)
		return {"value": num_str.to_float(), "unit": "%"}

	if value.ends_with("px"):
		var num_str = value.substr(0, value.length() - 2)
		return {"value": num_str.to_int(), "unit": "px"}

	# Assume pixels if no unit
	return {"value": value.to_int(), "unit": "px"}


## Parse a size value (e.g., "10px", "10").
## Returns an integer pixel value.
static func parse_size(value: String) -> int:
	value = value.strip_edges()

	if value.ends_with("px"):
		value = value.substr(0, value.length() - 2)

	return value.to_int()


## Parse a float value (e.g., "0.5", "1").
## Used for opacity, flex-grow, flex-shrink, etc.
static func parse_float(value: String) -> float:
	return value.strip_edges().to_float()
