class_name GmlCssParser
extends RefCounted

## CSS parser for GML.
## Parses a subset of CSS into an array of rules.
##
## Supported selectors: tag, .class, #id
## Supported properties: display, flex-direction, gap, margin, padding, background-color, color, font-size, width, height,
##   align-items, justify-content, border, border-width, border-color, border-radius,
##   border-top, border-right, border-bottom, border-left,
##   border-top-width, border-right-width, border-bottom-width, border-left-width,
##   border-top-color, border-right-color, border-bottom-color, border-left-color,
##   padding-top, padding-right, padding-bottom, padding-left,
##   margin-top, margin-right, margin-bottom, margin-left,
##   font-family, font-weight, letter-spacing, text-align, opacity, min-width, max-width, min-height, max-height,
##   flex-grow, flex-shrink, border-top-left-radius, border-top-right-radius,
##   border-bottom-left-radius, border-bottom-right-radius, overflow, visibility,
##   background, background-image (linear-gradient, radial-gradient)

var _pos: int = 0
var _css: String = ""
var _length: int = 0

# Property categories for dispatch
const PASSTHROUGH_PROPS = [
	"display", "flex-direction", "align-items", "justify-content",
	"text-align", "overflow", "overflow-x", "overflow-y", "visibility"
]

const SIZE_PROPS = [
	"gap", "margin", "padding", "font-size", "border-width", "border-radius",
	"border-top-width", "border-right-width", "border-bottom-width", "border-left-width",
	"padding-top", "padding-right", "padding-bottom", "padding-left",
	"margin-top", "margin-right", "margin-bottom", "margin-left",
	"border-top-left-radius", "border-top-right-radius",
	"border-bottom-left-radius", "border-bottom-right-radius"
]

const DIMENSION_PROPS = [
	"width", "height", "min-width", "max-width", "min-height", "max-height"
]

const COLOR_PROPS = [
	"background-color", "color", "border-color",
	"border-top-color", "border-right-color", "border-bottom-color", "border-left-color"
]

const BORDER_PROPS = [
	"border", "border-top", "border-right", "border-bottom", "border-left"
]

const FLOAT_PROPS = [
	"opacity", "flex-grow", "flex-shrink"
]


## Represents a CSS rule.
class CssRule:
	var selector_type: String = ""  # "tag", "class", "id"
	var selector_value: String = ""  # The actual selector (e.g., "div", "container", "main")
	var pseudo_class: String = ""  # Pseudo-class (e.g., "hover", "active", "focus")
	var properties: Dictionary = {}  # {"display": "flex", "gap": 10, etc.}

	func _to_string() -> String:
		var pseudo_str = ":" + pseudo_class if not pseudo_class.is_empty() else ""
		return "%s:%s%s { %s }" % [selector_type, selector_value, pseudo_str, properties]


## Parse CSS string and return an array of CssRule.
func parse(css: String) -> Array:
	_css = css
	_pos = 0
	_length = css.length()

	var rules: Array = []

	while _pos < _length:
		_skip_whitespace_and_comments()
		if _pos >= _length:
			break

		var parsed_rules := _parse_rules_group()
		for rule in parsed_rules:
			rules.append(rule)

	return rules


## Parse CSS rules, handling comma-separated selectors.
## Returns an array of CssRule objects.
func _parse_rules_group() -> Array:
	_skip_whitespace_and_comments()

	# Parse all selectors (comma-separated)
	var selectors: Array = []
	while _pos < _length:
		var selector := _parse_selector()
		if selector.is_empty():
			break

		selectors.append(selector)
		_skip_whitespace_and_comments()

		# Check for comma (more selectors) or opening brace (properties)
		if _peek() == ",":
			_advance()  # consume comma
			_skip_whitespace_and_comments()
		elif _peek() == "{":
			break
		else:
			# Might be a space (descendant selector) - skip to brace
			while _pos < _length and _peek() != "{" and _peek() != ",":
				if _peek() == " " or _peek() == "\t" or _peek() == "\n":
					_skip_whitespace_and_comments()
					# If next char is a selector char, this is a descendant selector
					# Just use the first selector and skip the rest
					if _peek().is_valid_identifier() or _peek() == "." or _peek() == "#":
						while _pos < _length and _peek() != "{" and _peek() != ",":
							_advance()
						break
				else:
					break

	if selectors.is_empty():
		return []

	_skip_whitespace_and_comments()

	# Expect opening brace
	if not _consume("{"):
		push_warning("GmlCssParser: Expected '{' after selector(s)")
		return []

	# Parse properties
	var properties := _parse_properties()

	# Expect closing brace
	_skip_whitespace_and_comments()
	if not _consume("}"):
		push_warning("GmlCssParser: Expected '}' after properties")
		# Try to recover
		while _pos < _length and _peek() != "}":
			_advance()
		_advance()

	# Create a rule for each selector
	var rules: Array = []
	for selector in selectors:
		var rule := CssRule.new()

		# Extract pseudo-class if present (e.g., "button:hover" -> "button" + "hover")
		var pseudo_class: String = ""
		var base_selector: String = selector

		# Find pseudo-class (but not at the start, which would be invalid)
		var colon_pos: int = selector.find(":")
		if colon_pos > 0:
			base_selector = selector.substr(0, colon_pos)
			pseudo_class = selector.substr(colon_pos + 1)

		if base_selector.begins_with("#"):
			rule.selector_type = "id"
			rule.selector_value = base_selector.substr(1)
		elif base_selector.begins_with("."):
			rule.selector_type = "class"
			rule.selector_value = base_selector.substr(1)
		else:
			rule.selector_type = "tag"
			rule.selector_value = base_selector

		rule.pseudo_class = pseudo_class
		rule.properties = properties.duplicate()
		rules.append(rule)

	return rules


## Parse a CSS selector (including pseudo-classes like :hover).
func _parse_selector() -> String:
	var start := _pos

	while _pos < _length:
		var ch := _peek()
		# Include ":" to support pseudo-classes like :hover, :active, :focus
		if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch == "." or ch == "#" or ch == ":" or ch.is_valid_int():
			_advance()
		else:
			break

	return _css.substr(start, _pos - start)


## Parse CSS properties inside a rule block.
func _parse_properties() -> Dictionary:
	var properties := {}

	while _pos < _length:
		_skip_whitespace_and_comments()

		if _peek() == "}":
			break

		var prop_name := _parse_property_name()
		if prop_name.is_empty():
			break

		_skip_whitespace_and_comments()

		if not _consume(":"):
			push_warning("GmlCssParser: Expected ':' after property name '%s'" % prop_name)
			break

		_skip_whitespace_and_comments()

		var prop_value := _parse_property_value()

		# Parse the value into appropriate type
		properties[prop_name] = _convert_property_value(prop_name, prop_value)

		_skip_whitespace_and_comments()

		# Consume semicolon if present
		_consume(";")

	return properties


## Parse a property name.
func _parse_property_name() -> String:
	var start := _pos

	while _pos < _length:
		var ch := _peek()
		if ch.is_valid_identifier() or ch == "-":
			_advance()
		else:
			break

	return _css.substr(start, _pos - start)


## Parse a property value (until ; or }).
func _parse_property_value() -> String:
	var start := _pos

	while _pos < _length:
		var ch := _peek()
		if ch == ";" or ch == "}":
			break
		_advance()

	return _css.substr(start, _pos - start).strip_edges()


## Convert a property value string to the appropriate type.
## Dispatches to the appropriate value parser module.
func _convert_property_value(prop_name: String, value: String):
	# Passthrough properties (return as string)
	if prop_name in PASSTHROUGH_PROPS:
		return value

	# Size properties (return int)
	if prop_name in SIZE_PROPS:
		return GmlDimensionValues.parse_size(value)

	# Dimension properties (return Dictionary with value and unit)
	if prop_name in DIMENSION_PROPS:
		return GmlDimensionValues.parse_dimension(value)

	# Color properties
	if prop_name in COLOR_PROPS:
		return GmlColorValues.parse_color(value)

	# Border shorthand properties
	if prop_name in BORDER_PROPS:
		return GmlBorderValues.parse_border(value)

	# Float properties
	if prop_name in FLOAT_PROPS:
		return GmlDimensionValues.parse_float(value)

	# Font properties
	if prop_name == "font-family":
		return GmlFontValues.parse_font_family(value)

	if prop_name == "font-weight":
		return GmlFontValues.parse_font_weight(value)

	if prop_name == "letter-spacing":
		return GmlFontValues.parse_letter_spacing(value)

	# Background properties
	if prop_name == "background" or prop_name == "background-image":
		return GmlBackgroundValues.parse_background(value)

	# Box shadow
	if prop_name == "box-shadow":
		return GmlBorderValues.parse_box_shadow(value)

	# Unknown property - return as string
	return value


## Skip whitespace and CSS comments.
func _skip_whitespace_and_comments() -> void:
	while _pos < _length:
		var ch := _peek()

		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			_advance()
		elif ch == "/" and _peek(1) == "*":
			# Skip block comment
			_advance()  # /
			_advance()  # *
			while _pos < _length - 1:
				if _peek() == "*" and _peek(1) == "/":
					_advance()  # *
					_advance()  # /
					break
				_advance()
		elif ch == "/" and _peek(1) == "/":
			# Skip line comment (non-standard but useful)
			while _pos < _length and _peek() != "\n":
				_advance()
		else:
			break


## Peek at character at current position + offset.
func _peek(offset: int = 0) -> String:
	var idx := _pos + offset
	if idx >= _length:
		return ""
	return _css[idx]


## Advance position by 1.
func _advance() -> void:
	_pos += 1


## Consume expected character, return true if successful.
func _consume(expected: String) -> bool:
	if _peek() == expected:
		_advance()
		return true
	return false
