class_name GmlHtmlParser
extends RefCounted

## HTML parser for GML.
## Parses a subset of HTML into a GmlNode tree.
##
## Supported tags: div, p, span, h1-h6, button, img, br
## Supported attributes: id, class, src, @click, and any custom attributes

const GmlNodeScript = preload("res://addons/gtml/src/html_parser/GmlNode.gd")

const SELF_CLOSING_TAGS := ["img", "br", "hr", "input", "meta", "link", "circle", "ellipse", "line", "path", "polygon", "polyline", "rect", "use"]
const MAX_DEPTH := 100  # Prevent stack overflow on deeply nested HTML

# Minimal HTML named entity table. Anything not listed is left as the literal
# &name; sequence so user content is preserved on lookup miss.
const NAMED_ENTITIES := {
	"amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
	"nbsp": " ", "copy": "©", "reg": "®", "trade": "™",
	"hellip": "…", "mdash": "—", "ndash": "–",
	"lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
	"laquo": "«", "raquo": "»", "deg": "°", "plusmn": "±",
	"times": "×", "divide": "÷", "middot": "·", "bull": "•",
}

var _pos: int = 0
var _html: String = ""
var _length: int = 0
var _depth: int = 0


## Parse HTML string and return the root node.
## Returns null if parsing fails.
func parse(html: String):
	_html = html
	_pos = 0
	_length = html.length()
	_depth = 0

	# Create a virtual root to hold multiple top-level elements
	var root = GmlNodeScript.create_element("_root")

	while _pos < _length:
		_skip_whitespace()
		if _pos >= _length:
			break

		# Stray closing tag at the top level — skip the whole </tag> sequence
		# so it doesn't become a stuck cursor or get sliced into text fragments.
		if _peek() == "<" and _peek(1) == "/":
			_skip_closing_tag()
			continue

		var pos_before := _pos
		var node = _parse_node()
		if node != null:
			root.add_child(node)
		# Defensive termination guarantee: if _parse_node returned null and
		# didn't advance the cursor for any other reason, bump past one
		# character so the loop can make progress instead of spinning forever.
		if _pos == pos_before:
			_advance()

	# If there's only one child, return it directly
	if root.children.size() == 1:
		return root.children[0]

	# If there are multiple children, wrap them in a div
	if root.children.size() > 1:
		var wrapper = GmlNodeScript.create_element("div")
		wrapper.children = root.children
		return wrapper

	return null


## Parse a single node (element or text).
func _parse_node():
	if _pos >= _length:
		return null

	if _peek() == "<":
		if _peek(1) == "!":
			# Comment or DOCTYPE - skip it
			_skip_comment_or_doctype()
			return null
		elif _peek(1) == "/":
			# Closing tag - shouldn't happen at this level
			return null
		else:
			return _parse_element()
	else:
		return _parse_text()


## Parse an element node.
func _parse_element():
	# Check recursion depth
	_depth += 1
	if _depth > MAX_DEPTH:
		push_error("GmlHtmlParser: Maximum nesting depth exceeded (%d)" % MAX_DEPTH)
		_depth -= 1
		return null

	if not _consume("<"):
		_depth -= 1
		return null

	# Parse tag name
	var tag_name := _parse_identifier()
	if tag_name.is_empty():
		push_warning("GmlHtmlParser: Expected tag name at position %d" % _pos)
		_depth -= 1
		return null

	tag_name = tag_name.to_lower()

	# Parse attributes
	var attributes := _parse_attributes()

	_skip_whitespace()

	# Check for self-closing
	var is_self_closing := false
	if _peek() == "/":
		_advance()
		is_self_closing = true

	if not _consume(">"):
		push_warning("GmlHtmlParser: Expected '>' at position %d" % _pos)
		# Try to recover by finding the next >
		while _pos < _length and _peek() != ">":
			_advance()
		_advance()

	var node = GmlNodeScript.create_element(tag_name, attributes)

	# Self-closing tags don't have children
	if is_self_closing or tag_name in SELF_CLOSING_TAGS:
		_depth -= 1
		return node

	# Parse children
	while _pos < _length:
		_skip_whitespace_preserve_text()

		if _pos >= _length:
			break

		# Closing tag — but check whether it's a stray close for a void
		# element first (e.g. </input> after <input>). Authors who write
		# explicit void-tag closes shouldn't blow up the parent's structure.
		# Skipping the stray as a no-op keeps the child loop honest.
		if _peek() == "<" and _peek(1) == "/":
			var ahead := _peek_closing_tag_name()
			if ahead in SELF_CLOSING_TAGS:
				_skip_closing_tag()
				continue
			break

		var child = _parse_node()
		if child != null:
			node.add_child(child)

	# Parse closing tag
	_parse_closing_tag(tag_name)

	_depth -= 1
	return node


## Peek at the tag name in the closing tag at the current position
## (``</tagname>``) without consuming any input. Returns "" if the cursor
## isn't sitting on a closing tag.
func _peek_closing_tag_name() -> String:
	if _peek() != "<" or _peek(1) != "/":
		return ""
	var i: int = _pos + 2
	var start: int = i
	while i < _length:
		var ch: String = _html[i]
		if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch.is_valid_int():
			i += 1
		else:
			break
	return _html.substr(start, i - start).to_lower()


## Skip past a closing tag (``</tagname>``) at the current position. Used to
## ignore stray closes for void elements without invoking the strict
## _parse_closing_tag path (which would warn and unwind).
func _skip_closing_tag() -> void:
	_consume("<")
	_consume("/")
	while _pos < _length and _peek() != ">":
		_advance()
	_consume(">")


## Parse closing tag.
func _parse_closing_tag(expected_tag: String) -> bool:
	if not _consume("<"):
		return false
	if not _consume("/"):
		return false

	var tag_name := _parse_identifier()
	if tag_name.to_lower() != expected_tag:
		push_warning("GmlHtmlParser: Expected closing tag </%s> but found </%s>" % [expected_tag, tag_name])

	_skip_whitespace()
	_consume(">")
	return true


## Parse element attributes.
func _parse_attributes() -> Dictionary:
	var attributes := {}

	while _pos < _length:
		_skip_whitespace()

		var ch := _peek()
		if ch == ">" or ch == "/" or ch == "":
			break

		# Parse attribute name (can include @ for @click etc.)
		var attr_name := _parse_attribute_name()
		if attr_name.is_empty():
			break

		_skip_whitespace()

		# Check for = and value
		if _peek() == "=":
			_advance()
			_skip_whitespace()

			var attr_value := _parse_attribute_value()
			attributes[attr_name] = attr_value
		else:
			# Boolean attribute (no value)
			attributes[attr_name] = "true"

	return attributes


## Parse attribute name (including @-prefixed attributes).
func _parse_attribute_name() -> String:
	var start := _pos

	# Allow @ as first character for @click etc.
	if _peek() == "@":
		_advance()

	while _pos < _length:
		var ch := _peek()
		# Allow letters, digits, hyphens, underscores, colons (for SVG attributes like x1, y1, etc.)
		if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch == ":" or ch.is_valid_int():
			_advance()
		else:
			break

	return _html.substr(start, _pos - start)


## Parse attribute value (with or without quotes).
func _parse_attribute_value() -> String:
	var quote := _peek()

	if quote == "\"" or quote == "'":
		_advance()
		var start := _pos

		while _pos < _length and _peek() != quote:
			_advance()

		var value := _html.substr(start, _pos - start)
		_advance()  # Skip closing quote
		return _decode_entities(value)
	else:
		# Unquoted value
		var start := _pos
		while _pos < _length:
			var ch := _peek()
			if ch == " " or ch == ">" or ch == "/" or ch == "\t" or ch == "\n":
				break
			_advance()
		return _decode_entities(_html.substr(start, _pos - start))


## Parse a text node.
func _parse_text():
	var start := _pos

	while _pos < _length and _peek() != "<":
		_advance()

	var text := _html.substr(start, _pos - start)

	# Decode HTML entities first, then collapse whitespace.
	# Entity decoding must precede normalization so &nbsp; -> " " participates
	# in the whitespace collapse instead of being preserved as a literal.
	text = _decode_entities(text)
	text = _normalize_whitespace(text)

	if text.is_empty():
		return null

	return GmlNodeScript.create_text(text)


## Parse an identifier (tag name).
func _parse_identifier() -> String:
	var start := _pos

	while _pos < _length:
		var ch := _peek()
		if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch.is_valid_int():
			_advance()
		else:
			break

	return _html.substr(start, _pos - start)


## Skip whitespace characters.
func _skip_whitespace() -> void:
	while _pos < _length:
		var ch := _peek()
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			_advance()
		else:
			break


## Skip whitespace but preserve some for text parsing context.
func _skip_whitespace_preserve_text() -> void:
	# Only skip if next non-whitespace is a tag
	var temp_pos := _pos
	while temp_pos < _length:
		var ch := _html[temp_pos]
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			temp_pos += 1
		else:
			break

	if temp_pos < _length and _html[temp_pos] == "<":
		_pos = temp_pos


## Skip HTML comment or DOCTYPE.
func _skip_comment_or_doctype() -> void:
	if _peek() != "<" or _peek(1) != "!":
		return

	_advance()  # <
	_advance()  # !

	if _peek() == "-" and _peek(1) == "-":
		# Comment: <!-- ... -->
		_advance()  # -
		_advance()  # -

		while _pos < _length - 2:
			if _html[_pos] == "-" and _html[_pos + 1] == "-" and _html[_pos + 2] == ">":
				_pos += 3
				return
			_advance()
	else:
		# DOCTYPE or other: skip until >
		while _pos < _length and _peek() != ">":
			_advance()
		_advance()


## Normalize whitespace in text content.
func _normalize_whitespace(text: String) -> String:
	# Replace multiple whitespace with single space
	var result := ""
	var last_was_space := false

	for ch in text:
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			if not last_was_space:
				result += " "
				last_was_space = true
		else:
			result += ch
			last_was_space = false

	return result.strip_edges()


## Peek at character at current position + offset.
func _peek(offset: int = 0) -> String:
	var idx := _pos + offset
	if idx >= _length:
		return ""
	return _html[idx]


## Advance position by 1.
func _advance() -> void:
	_pos += 1


## Consume expected character, return true if successful.
func _consume(expected: String) -> bool:
	if _peek() == expected:
		_advance()
		return true
	return false


## Decode HTML entities in a string. Unknown entities are passed through verbatim
## so user content is preserved on lookup miss.
static func _decode_entities(s: String) -> String:
	if s.find("&") < 0:
		return s

	var out := ""
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch != "&":
			out += ch
			i += 1
			continue

		# Find terminating semicolon within a reasonable window. The window
		# must cover the longest plausible entity: numeric refs like
		# &#x10FFFF; (10 chars) and possibly overflowing user input we still
		# want to recognize-and-replace (vs. passing through as literal "&").
		var semi := s.find(";", i + 1)
		if semi < 0 or semi - i > 16:
			out += ch
			i += 1
			continue

		var entity := s.substr(i + 1, semi - i - 1)
		# Numeric entities: always consumed. Valid -> decoded codepoint,
		# invalid (overflow / surrogate / non-numeric) -> U+FFFD replacement.
		# Named entities: decoded if known, otherwise preserved verbatim so
		# user-authored "&unknown;" content survives intact.
		if entity.begins_with("#"):
			out += _decode_numeric_entity(entity)
		else:
			var named := _decode_named_entity(entity)
			if named.is_empty():
				out += s.substr(i, semi - i + 1)
			else:
				out += named
		i = semi + 1
	return out


## Decode a numeric character reference ("#65", "#x2603"). Returns U+FFFD
## (the Unicode replacement character) for any unparseable, overflowing, or
## surrogate codepoint per the HTML spec — never an empty string and never
## the raw entity, so invalid numeric refs can't masquerade as user text.
const REPLACEMENT_CHAR := "�"

static func _decode_numeric_entity(entity: String) -> String:
	var num_part := entity.substr(1)
	var code: int = 0
	if num_part.begins_with("x") or num_part.begins_with("X"):
		code = num_part.substr(1).hex_to_int()
	elif num_part.is_valid_int():
		code = num_part.to_int()
	else:
		return REPLACEMENT_CHAR
	if code <= 0 or code > 0x10FFFF:
		return REPLACEMENT_CHAR
	if code >= 0xD800 and code <= 0xDFFF:
		return REPLACEMENT_CHAR
	return String.chr(code)


## Decode a named entity. Returns "" if unknown — caller is responsible for
## preserving the raw "&name;" verbatim in that case.
static func _decode_named_entity(entity: String) -> String:
	if entity.is_empty():
		return ""
	if NAMED_ENTITIES.has(entity):
		return NAMED_ENTITIES[entity]
	return ""
