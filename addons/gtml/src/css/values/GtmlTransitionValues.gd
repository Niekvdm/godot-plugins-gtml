class_name GtmlTransitionValues
extends RefCounted

## Static utility class for parsing CSS transition properties.
## Handles transition shorthand and individual properties.


## Parse transition shorthand: "property duration timing-function delay, ..."
## Example: "background-color 0.3s ease-in-out 0.1s, color 0.2s ease"
## Returns array of transition definitions.
static func parse_transition(value: String) -> Array:
	var transitions: Array = []

	# Handle "none" keyword
	if value.strip_edges() == "none":
		return transitions

	# Split by comma for multiple transitions
	var parts = value.split(",")

	for part in parts:
		var transition = _parse_single_transition(part.strip_edges())
		if not transition.is_empty():
			transitions.append(transition)

	return transitions


## Parse a single transition definition.
## Format: "property duration timing-function delay"
## Only property is required; others have defaults.
static func _parse_single_transition(value: String) -> Dictionary:
	if value.is_empty():
		return {}

	var tokens = _tokenize(value)
	if tokens.is_empty():
		return {}

	var result = {
		"property": "",
		"duration": 0.0,
		"timing": parse_timing_function("ease"),
		"delay": 0.0
	}

	var duration_found := false
	var timing_found := false

	for token in tokens:
		# Check if it's a duration/delay (ends with s or ms)
		if _is_duration(token):
			if not duration_found:
				result.duration = parse_duration(token)
				duration_found = true
			else:
				result.delay = parse_duration(token)
		# Check if it's a timing function
		elif _is_timing_function(token):
			result.timing = parse_timing_function(token)
			timing_found = true
		# Otherwise it's the property name
		elif result.property.is_empty():
			result.property = token

	# Property is required
	if result.property.is_empty():
		return {}

	return result


## Tokenize a transition string, handling parentheses for potential cubic-bezier.
static func _tokenize(value: String) -> Array:
	var tokens: Array = []
	var current := ""
	var in_parens := 0

	for c in value:
		if c == '(':
			in_parens += 1
			current += c
		elif c == ')':
			in_parens -= 1
			current += c
		elif c == ' ' and in_parens == 0:
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += c

	if not current.is_empty():
		tokens.append(current)

	return tokens


## Check if a token is a duration value.
static func _is_duration(token: String) -> bool:
	return token.ends_with("s") or token.ends_with("ms")


## Check if a token is a timing function.
static func _is_timing_function(token: String) -> bool:
	var timing_keywords = ["linear", "ease", "ease-in", "ease-out", "ease-in-out"]
	return token in timing_keywords or token.begins_with("cubic-bezier")


## Parse duration value (0.3s, 300ms) to float seconds.
static func parse_duration(value: String) -> float:
	value = value.strip_edges()

	if value.ends_with("ms"):
		var num_str = value.substr(0, value.length() - 2)
		return num_str.to_float() / 1000.0

	if value.ends_with("s"):
		var num_str = value.substr(0, value.length() - 1)
		return num_str.to_float()

	# Assume seconds if no unit
	return value.to_float()


## Map CSS timing function to Godot Tween types.
## Returns Dictionary with trans_type and ease_type.
static func parse_timing_function(value: String) -> Dictionary:
	value = value.strip_edges()

	match value:
		"linear":
			return {
				"trans_type": Tween.TRANS_LINEAR,
				"ease_type": Tween.EASE_IN_OUT
			}
		"ease":
			return {
				"trans_type": Tween.TRANS_SINE,
				"ease_type": Tween.EASE_IN_OUT
			}
		"ease-in":
			return {
				"trans_type": Tween.TRANS_SINE,
				"ease_type": Tween.EASE_IN
			}
		"ease-out":
			return {
				"trans_type": Tween.TRANS_SINE,
				"ease_type": Tween.EASE_OUT
			}
		"ease-in-out":
			return {
				"trans_type": Tween.TRANS_SINE,
				"ease_type": Tween.EASE_IN_OUT
			}
		_:
			# Default to ease for unsupported values (like cubic-bezier)
			return {
				"trans_type": Tween.TRANS_SINE,
				"ease_type": Tween.EASE_IN_OUT
			}


## Parse transition-property value.
## Returns array of property names.
static func parse_transition_property(value: String) -> Array:
	var properties: Array = []
	var parts = value.split(",")

	for part in parts:
		var prop = part.strip_edges()
		if not prop.is_empty() and prop != "none":
			properties.append(prop)

	return properties


## Parse transition-duration value.
## Returns array of durations in seconds.
static func parse_transition_duration(value: String) -> Array:
	var durations: Array = []
	var parts = value.split(",")

	for part in parts:
		durations.append(parse_duration(part.strip_edges()))

	return durations


## Parse transition-timing-function value.
## Returns array of timing dictionaries.
static func parse_transition_timing_function(value: String) -> Array:
	var timings: Array = []
	var parts = value.split(",")

	for part in parts:
		timings.append(parse_timing_function(part.strip_edges()))

	return timings


## Parse transition-delay value.
## Returns array of delays in seconds.
static func parse_transition_delay(value: String) -> Array:
	var delays: Array = []
	var parts = value.split(",")

	for part in parts:
		delays.append(parse_duration(part.strip_edges()))

	return delays
