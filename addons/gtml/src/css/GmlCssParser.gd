class_name GmlCssParser
extends RefCounted

## CSS parser for GML.
## Parses a subset of CSS into an array of rules.
##
## Supported selectors: tag, .class, #id
## Supported properties: display, flex-direction, gap, row-gap, column-gap, margin, padding, background-color, color, font-size, width, height,
##   align-items, justify-content, border, border-width, border-color, border-radius,
##   border-top, border-right, border-bottom, border-left,
##   border-top-width, border-right-width, border-bottom-width, border-left-width,
##   border-top-color, border-right-color, border-bottom-color, border-left-color,
##   padding-top, padding-right, padding-bottom, padding-left,
##   margin-top, margin-right, margin-bottom, margin-left,
##   font-family, font-weight, letter-spacing, text-align, opacity, min-width, max-width, min-height, max-height,
##   flex-grow, flex-shrink, flex-basis, flex-wrap, align-self, order,
##   border-top-left-radius, border-top-right-radius,
##   border-bottom-left-radius, border-bottom-right-radius, overflow, visibility,
##   background, background-image (linear-gradient, radial-gradient),
##   text-decoration, line-height, text-transform, text-indent, word-spacing, white-space, text-overflow,
##   transition, transition-property, transition-duration, transition-timing-function, transition-delay

var _pos: int = 0
var _css: String = ""
var _length: int = 0
var _warnings: Array = []  # [{line:int, col:int, msg:String}]


## Get all warnings emitted during the last parse. Each entry: {line, col, msg}.
func get_warnings() -> Array:
	return _warnings


## Compute the 1-based line and column for a given byte position.
func _line_col_for(p: int) -> Dictionary:
	var line := 1
	var col := 1
	var limit: int = mini(p, _length)
	for i in range(limit):
		if _css[i] == "\n":
			line += 1
			col = 1
		else:
			col += 1
	return {"line": line, "col": col}


func _warn(msg: String) -> void:
	var lc := _line_col_for(_pos)
	_warnings.append({"line": lc["line"], "col": lc["col"], "msg": msg})
	push_warning("GmlCssParser [%d:%d]: %s" % [lc["line"], lc["col"], msg])

# Property categories for dispatch
const PASSTHROUGH_PROPS = [
	"display", "flex-direction", "align-items", "justify-content",
	"text-align", "overflow", "overflow-x", "overflow-y", "visibility",
	"text-transform", "white-space", "text-overflow",
	"flex-wrap", "align-self", "cursor", "list-style-type"
]

const SIZE_PROPS = [
	"gap", "row-gap", "column-gap", "margin", "padding", "font-size", "border-width", "border-radius",
	"border-top-width", "border-right-width", "border-bottom-width", "border-left-width",
	"padding-top", "padding-right", "padding-bottom", "padding-left",
	"margin-top", "margin-right", "margin-bottom", "margin-left",
	"border-top-left-radius", "border-top-right-radius",
	"border-bottom-left-radius", "border-bottom-right-radius",
	"text-indent", "word-spacing", "line-height", "outline-offset"
]

const DIMENSION_PROPS = [
	"width", "height", "min-width", "max-width", "min-height", "max-height",
	"flex-basis"
]

const COLOR_PROPS = [
	"background-color", "color", "border-color",
	"border-top-color", "border-right-color", "border-bottom-color", "border-left-color"
]

const BORDER_PROPS = [
	"border", "border-top", "border-right", "border-bottom", "border-left"
]

const FLOAT_PROPS = [
	"opacity", "flex-grow", "flex-shrink", "order"
]

const TRANSITION_PROPS = [
	"transition", "transition-property", "transition-duration",
	"transition-timing-function", "transition-delay"
]


## Represents a CSS rule.
##
## v0.2: a rule carries a structured ``GmlSelector.Selector`` and the resolver
## matches against the live DOM with full combinator + specificity support.
## The legacy fields (``selector_type`` / ``selector_value`` / ``pseudo_class``)
## are derived from the rightmost compound and kept around so older callers
## and serializers continue to function.
class CssRule:
	var selector = null              # GmlSelector.Selector
	var properties: Dictionary = {}  # {"display": "flex", "gap": 10, ...}
	var source_index: int = 0        # rule's position in source for tie-breaking

	# Legacy mirror of the rightmost compound — used by code paths and
	# snapshot serializers that haven't migrated to the new selector engine yet.
	var selector_type: String = ""   # "tag" | "class" | "id"
	var selector_value: String = ""
	var pseudo_class: String = ""    # First pseudo (legacy single-pseudo callers)

	func _to_string() -> String:
		var pseudo_str: String = ":" + pseudo_class if not pseudo_class.is_empty() else ""
		return "%s:%s%s { %s }" % [selector_type, selector_value, pseudo_str, properties]

	func specificity() -> Vector3i:
		if selector == null:
			return Vector3i(0, 0, 0)
		return selector.specificity()


## Parse CSS string and return an array of CssRule.
func parse(css: String) -> Array:
	_css = css
	_pos = 0
	_length = css.length()
	_warnings.clear()

	var rules: Array = []

	while _pos < _length:
		_skip_whitespace_and_comments()
		if _pos >= _length:
			break

		var parsed_rules := _parse_rules_group()
		for rule in parsed_rules:
			rule.source_index = rules.size()
			rules.append(rule)

	return rules


## Parse CSS rules, handling comma-separated selectors.
## Delegates selector parsing to GmlSelector so combinators + attribute
## selectors + compound selectors are all supported.
func _parse_rules_group() -> Array:
	_skip_whitespace_and_comments()

	# Read the whole selector list up to the opening brace, then hand the
	# string off to the selector parser. This avoids reimplementing tokenization
	# in two places.
	var selector_text_start := _pos
	while _pos < _length and _peek() != "{":
		_advance()
	if _pos >= _length:
		_warn("Expected '{' after selector(s)")
		return []
	var selector_text: String = _css.substr(selector_text_start, _pos - selector_text_start).strip_edges()
	if selector_text.is_empty():
		return []

	var selectors: Array = GmlSelector.parse_group(selector_text)

	# Consume the opening brace
	_consume("{")

	# Parse properties
	var properties := _parse_properties()

	# Expect closing brace
	_skip_whitespace_and_comments()
	if not _consume("}"):
		_warn("Expected '}' after properties")
		# Try to recover
		while _pos < _length and _peek() != "}":
			_advance()
		_advance()

	# Create one rule per selector. Deep-clone properties so mutations in one
	# rule's nested dicts can never bleed into a sibling rule.
	var rules: Array = []
	for sel in selectors:
		var rule := CssRule.new()
		rule.selector = sel
		rule.properties = _deep_clone_properties(properties)
		_populate_legacy_fields(rule, sel)
		rules.append(rule)
	return rules


## Mirror the rightmost compound + first pseudo onto the legacy fields so older
## consumers (snapshot serializer, debug output) keep working until they migrate.
static func _populate_legacy_fields(rule, sel) -> void:
	if sel == null or sel.compounds.is_empty():
		return
	var last_idx: int = sel.compounds.size() - 1
	var c = sel.compounds[last_idx]
	if not c.id.is_empty():
		rule.selector_type = "id"
		rule.selector_value = c.id
	elif not c.classes.is_empty():
		rule.selector_type = "class"
		rule.selector_value = c.classes[0]
	elif not c.tag.is_empty():
		rule.selector_type = "tag"
		rule.selector_value = c.tag
	if c.pseudos.size() > 0:
		rule.pseudo_class = c.pseudos[0]


## Deep-clone a properties dictionary so nested Dictionaries / Arrays are independent.
static func _deep_clone_properties(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src:
		out[k] = _deep_clone_value(src[k])
	return out


static func _deep_clone_value(v: Variant) -> Variant:
	if v is Dictionary:
		return _deep_clone_properties(v)
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_deep_clone_value(x))
		return arr
	return v


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
			_warn("Expected ':' after property name '%s'" % prop_name)
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


## Parse a property value (until ; or } at the top level).
## Quoted strings and parenthesized expressions are treated as opaque so
## punctuation inside them (semicolons in "a;b", commas in url(foo,bar)) does
## not terminate the value.
func _parse_property_value() -> String:
	var start := _pos
	var paren_depth := 0

	while _pos < _length:
		var ch := _peek()

		if ch == "\"" or ch == "'":
			_skip_string(ch)
			continue
		if ch == "(":
			paren_depth += 1
			_advance()
			continue
		if ch == ")":
			if paren_depth > 0:
				paren_depth -= 1
			_advance()
			continue
		if paren_depth == 0 and (ch == ";" or ch == "}"):
			break
		_advance()

	return _css.substr(start, _pos - start).strip_edges()


## Skip past a quoted CSS string, handling backslash escapes.
func _skip_string(quote: String) -> void:
	_advance()  # opening quote
	while _pos < _length:
		var ch := _peek()
		if ch == "\\" and _pos + 1 < _length:
			_advance()
			_advance()
			continue
		if ch == quote:
			_advance()  # closing quote
			return
		_advance()


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

	# Text decoration (can have multiple values like "underline line-through")
	if prop_name == "text-decoration":
		return GmlFontValues.parse_text_decoration(value)

	# Background properties
	if prop_name == "background" or prop_name == "background-image":
		return GmlBackgroundValues.parse_background(value)

	# Box shadow
	if prop_name == "box-shadow":
		return GmlBorderValues.parse_box_shadow(value)

	# Text shadow
	if prop_name == "text-shadow":
		return GmlBorderValues.parse_text_shadow(value)

	# Outline
	if prop_name == "outline":
		return GmlBorderValues.parse_outline(value)

	# Transition properties
	if prop_name == "transition":
		return GmlTransitionValues.parse_transition(value)
	if prop_name == "transition-property":
		return GmlTransitionValues.parse_transition_property(value)
	if prop_name == "transition-duration":
		return GmlTransitionValues.parse_transition_duration(value)
	if prop_name == "transition-timing-function":
		return GmlTransitionValues.parse_transition_timing_function(value)
	if prop_name == "transition-delay":
		return GmlTransitionValues.parse_transition_delay(value)

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
