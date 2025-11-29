@tool
extends SyntaxHighlighter

## HTML Syntax Highlighter for the GML Editor
## Highlights tags, attributes, strings, comments, and GML-specific attributes (@click, @submit)

# Colors (VS Code dark theme inspired)
var tag_color := Color("#569cd6")         # Blue - tag names
var attribute_color := Color("#9cdcfe")   # Light blue - regular attributes
var special_attr_color := Color("#c586c0") # Purple - id, class, style
var data_attr_color := Color("#4ec9b0")   # Teal - data-* attributes
var string_color := Color("#ce9178")      # Orange - strings
var comment_color := Color("#6a9955")     # Green - comments
var bracket_color := Color("#808080")     # Gray - < > / =
var gml_attr_color := Color("#dcdcaa")    # Yellow - @click, @submit, etc.
var doctype_color := Color("#608b4e")     # Dark green - <!DOCTYPE>
var entity_color := Color("#d7ba7d")      # Gold - &nbsp; entities

# Special HTML attributes that get highlighted differently
const SPECIAL_ATTRIBUTES := ["id", "class", "style", "href", "src", "alt", "title", "name", "type", "value", "placeholder", "for", "action", "method"]

# State for multi-line parsing
enum State {
	NORMAL,        # Outside any tag
	IN_TAG,        # Inside a tag, parsing attributes
	IN_COMMENT,    # Inside <!-- -->
}


func _get_line_syntax_highlighting(line_idx: int) -> Dictionary:
	var colors: Dictionary = {}
	var text_edit = get_text_edit()
	if not text_edit:
		return colors

	var line: String = text_edit.get_line(line_idx)
	var i: int = 0
	var length: int = line.length()

	# Determine initial state by scanning previous lines
	var state: State = _get_initial_state(text_edit, line_idx)

	# If we're continuing inside a comment from previous line
	if state == State.IN_COMMENT:
		var end = line.find("-->")
		if end == -1:
			_set_color_range(colors, 0, length, comment_color)
			return colors
		else:
			_set_color_range(colors, 0, end + 3, comment_color)
			i = end + 3
			state = State.NORMAL

	# If we're continuing inside a tag from previous line, parse attributes
	if state == State.IN_TAG:
		i = _parse_tag_attributes(line, i, length, colors)
		if i < length and line[i] == ">":
			colors[i] = {"color": bracket_color}
			i += 1
			state = State.NORMAL
		elif i + 1 < length and line[i] == "/" and line[i + 1] == ">":
			colors[i] = {"color": bracket_color}
			colors[i + 1] = {"color": bracket_color}
			i += 2
			state = State.NORMAL

	while i < length:
		var c: String = line[i]

		# Check for comments <!-- -->
		if c == "<" and i + 3 < length and line.substr(i, 4) == "<!--":
			var start = i
			var end = line.find("-->", i + 4)
			if end == -1:
				end = length
			else:
				end += 3
			_set_color_range(colors, start, end, comment_color)
			i = end
			continue

		# Check for DOCTYPE
		if c == "<" and i + 8 < length:
			var doctype_check = line.substr(i, 9).to_lower()
			if doctype_check == "<!doctype":
				var start = i
				var end = line.find(">", i)
				if end == -1:
					end = length
				else:
					end += 1
				_set_color_range(colors, start, end, doctype_color)
				i = end
				continue

		# Check for closing tag </tag>
		if c == "<" and i + 1 < length and line[i + 1] == "/":
			colors[i] = {"color": bracket_color}
			colors[i + 1] = {"color": bracket_color}
			i += 2
			# Get tag name
			var tag_start = i
			while i < length and _is_tag_char(line[i]):
				i += 1
			if i > tag_start:
				_set_color_range(colors, tag_start, i, tag_color)
			# Find closing >
			if i < length and line[i] == ">":
				colors[i] = {"color": bracket_color}
				i += 1
			continue

		# Check for HTML entities &...; (like &nbsp;, &amp;, &#123;)
		if c == "&":
			var entity_start = i
			i += 1
			if i < length and line[i] == "#":
				i += 1
				if i < length and line[i].to_lower() == "x":
					i += 1
					while i < length and _is_hex_char(line[i]):
						i += 1
				else:
					while i < length and line[i].is_valid_int():
						i += 1
			else:
				while i < length and line[i].is_valid_identifier():
					i += 1
			if i < length and line[i] == ";":
				i += 1
				_set_color_range(colors, entity_start, i, entity_color)
				continue
			else:
				i = entity_start + 1
				continue

		# Check for opening tag <tag
		if c == "<" and i + 1 < length and _is_alpha(line[i + 1]):
			colors[i] = {"color": bracket_color}
			i += 1

			# Get tag name
			var tag_start = i
			while i < length and _is_tag_char(line[i]):
				i += 1
			if i > tag_start:
				_set_color_range(colors, tag_start, i, tag_color)

			# Parse attributes until > or end of line
			i = _parse_tag_attributes(line, i, length, colors)

			# Check for tag end
			if i < length and line[i] == ">":
				colors[i] = {"color": bracket_color}
				i += 1
			elif i + 1 < length and line[i] == "/" and line[i + 1] == ">":
				colors[i] = {"color": bracket_color}
				colors[i + 1] = {"color": bracket_color}
				i += 2
			# Otherwise tag continues on next line
			continue

		i += 1

	return colors


func _parse_tag_attributes(line: String, i: int, length: int, colors: Dictionary) -> int:
	## Parse attributes inside a tag until > or end of line
	while i < length:
		var attr_c: String = line[i]

		# End of tag
		if attr_c == ">":
			return i

		# Self-closing />
		if attr_c == "/" and i + 1 < length and line[i + 1] == ">":
			return i

		# Skip whitespace
		if attr_c == " " or attr_c == "\t" or attr_c == "\n" or attr_c == "\r":
			i += 1
			continue

		# GML special attributes (@click, @submit, etc.)
		if attr_c == "@":
			var attr_start = i
			i += 1
			while i < length and _is_attr_name_char(line[i]):
				i += 1
			_set_color_range(colors, attr_start, i, gml_attr_color)
			# Handle = and value
			i = _skip_whitespace(line, i, length)
			if i < length and line[i] == "=":
				colors[i] = {"color": bracket_color}
				i += 1
				i = _parse_attribute_value(line, i, length, colors)
			continue

		# Regular attribute (starts with letter or _)
		if _is_alpha(attr_c) or attr_c == "_":
			var attr_start = i
			while i < length and _is_attr_name_char(line[i]):
				i += 1
			var attr_name = line.substr(attr_start, i - attr_start).to_lower()

			# Determine attribute color based on type
			var attr_color = attribute_color
			if attr_name.begins_with("data-"):
				attr_color = data_attr_color
			elif attr_name in SPECIAL_ATTRIBUTES:
				attr_color = special_attr_color

			_set_color_range(colors, attr_start, i, attr_color)

			# Handle = and value
			i = _skip_whitespace(line, i, length)
			if i < length and line[i] == "=":
				colors[i] = {"color": bracket_color}
				i += 1
				i = _parse_attribute_value(line, i, length, colors)
			continue

		# Unknown character, skip
		i += 1

	return i


func _get_initial_state(text_edit: TextEdit, line_idx: int) -> State:
	## Scan previous lines to determine if we're inside a tag or comment
	var in_comment := false
	var in_tag := false

	for prev_line_idx in range(line_idx):
		var prev_line = text_edit.get_line(prev_line_idx)
		var i := 0
		var len := prev_line.length()

		while i < len:
			if in_comment:
				# Look for end of comment
				var end = prev_line.find("-->", i)
				if end == -1:
					break  # Comment continues
				else:
					in_comment = false
					i = end + 3
					continue

			if in_tag:
				# Look for end of tag
				while i < len:
					var c = prev_line[i]
					if c == ">":
						in_tag = false
						i += 1
						break
					elif c == "/" and i + 1 < len and prev_line[i + 1] == ">":
						in_tag = false
						i += 2
						break
					elif c == '"' or c == "'":
						# Skip quoted strings
						var quote = c
						i += 1
						while i < len and prev_line[i] != quote:
							i += 1
						if i < len:
							i += 1
					else:
						i += 1
				continue

			var c = prev_line[i]

			# Check for comment start
			if c == "<" and i + 3 < len and prev_line.substr(i, 4) == "<!--":
				in_comment = true
				var end = prev_line.find("-->", i + 4)
				if end == -1:
					break  # Comment continues to next line
				else:
					in_comment = false
					i = end + 3
					continue

			# Check for tag start
			if c == "<" and i + 1 < len and _is_alpha(prev_line[i + 1]):
				in_tag = true
				i += 1
				# Skip tag name
				while i < len and _is_tag_char(prev_line[i]):
					i += 1
				continue

			# Check for closing tag
			if c == "<" and i + 1 < len and prev_line[i + 1] == "/":
				i += 2
				# Skip tag name
				while i < len and _is_tag_char(prev_line[i]):
					i += 1
				# Find >
				while i < len and prev_line[i] != ">":
					i += 1
				if i < len:
					i += 1
				continue

			i += 1

	if in_comment:
		return State.IN_COMMENT
	elif in_tag:
		return State.IN_TAG
	else:
		return State.NORMAL


func _skip_whitespace(line: String, i: int, length: int) -> int:
	while i < length:
		var c = line[i]
		if c != " " and c != "\t":
			break
		i += 1
	return i


func _parse_attribute_value(line: String, i: int, length: int, colors: Dictionary) -> int:
	i = _skip_whitespace(line, i, length)
	if i >= length:
		return i

	var c = line[i]

	# Quoted string
	if c == '"' or c == "'":
		var quote = c
		var start = i
		i += 1
		while i < length and line[i] != quote:
			i += 1
		if i < length:
			i += 1  # Include closing quote
		_set_color_range(colors, start, i, string_color)
		return i

	# Unquoted value (until space or > or /)
	var start = i
	while i < length:
		c = line[i]
		if c == " " or c == "\t" or c == ">" or c == "/":
			break
		i += 1
	if i > start:
		_set_color_range(colors, start, i, string_color)

	return i


func _set_color_range(colors: Dictionary, start: int, end: int, color: Color) -> void:
	for j in range(start, end):
		colors[j] = {"color": color}


func _is_alpha(c: String) -> bool:
	if c.length() != 1:
		return false
	var code = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _is_digit(c: String) -> bool:
	if c.length() != 1:
		return false
	var code = c.unicode_at(0)
	return code >= 48 and code <= 57


func _is_tag_char(c: String) -> bool:
	if c.length() != 1:
		return false
	return _is_alpha(c) or _is_digit(c) or c == "-" or c == "_"


func _is_attr_name_char(c: String) -> bool:
	if c.length() != 1:
		return false
	return _is_alpha(c) or _is_digit(c) or c == "-" or c == "_" or c == ":" or c == "."


func _is_hex_char(c: String) -> bool:
	if c.length() != 1:
		return false
	var code = c.unicode_at(0)
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 70) or (code >= 97 and code <= 102)
