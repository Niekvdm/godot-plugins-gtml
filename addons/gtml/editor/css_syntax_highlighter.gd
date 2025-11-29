@tool
extends SyntaxHighlighter

## CSS Syntax Highlighter for the GML Editor
## Highlights selectors, properties, values, comments, colors, and numbers

# Colors (VS Code dark theme inspired)
var selector_color := Color("#d7ba7d")    # Yellow/gold - selectors
var property_color := Color("#9cdcfe")    # Light blue - properties
var value_color := Color("#ce9178")       # Orange - values
var string_color := Color("#ce9178")      # Orange - strings
var comment_color := Color("#6a9955")     # Green - comments
var number_color := Color("#b5cea8")      # Light green - numbers
var unit_color := Color("#b5cea8")        # Light green - units (px, %, em)
var punctuation_color := Color("#808080") # Gray - : ; { } ( )
var function_color := Color("#dcdcaa")    # Yellow - functions like rgb(), url()
var color_hex_color := Color("#ce9178")   # Orange - hex colors #fff
var important_color := Color("#c586c0")   # Purple - !important
var pseudo_color := Color("#c586c0")      # Purple - :hover, ::before


enum State {
	NORMAL,      # Outside any rule
	SELECTOR,    # In selector (before {)
	PROPERTY,    # In property name (before :)
	VALUE,       # In value (after : before ;)
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

	while i < length:
		# Skip whitespace
		if line[i] == " " or line[i] == "\t":
			i += 1
			continue

		# Check for comments /* */
		if _match_string(line, i, "/*"):
			var start = i
			var end = line.find("*/", i + 2)
			if end == -1:
				end = length
			else:
				end += 2
			_set_color_range(colors, start, end, comment_color)
			i = end
			continue

		# Handle based on state
		match state:
			State.NORMAL, State.SELECTOR:
				i = _parse_selector_context(line, i, length, colors, state)
				state = _update_state_from_char(line, i - 1, state) if i > 0 else state

			State.PROPERTY:
				i = _parse_property_context(line, i, length, colors, state)
				state = _update_state_from_char(line, i - 1, state) if i > 0 else state

			State.VALUE:
				i = _parse_value_context(line, i, length, colors, state)
				state = _update_state_from_char(line, i - 1, state) if i > 0 else state

	return colors


func _parse_selector_context(line: String, i: int, length: int, colors: Dictionary, state: State) -> int:
	var start = i

	# Check for { which starts property context
	if line[i] == "{":
		colors[i] = {"color": punctuation_color}
		return i + 1

	# Check for } which ends rule
	if line[i] == "}":
		colors[i] = {"color": punctuation_color}
		return i + 1

	# Check for pseudo-class/element :hover ::before
	if line[i] == ":":
		var colon_start = i
		i += 1
		if i < length and line[i] == ":":
			i += 1  # ::before
		# Get pseudo name
		while i < length and _is_ident_char(line[i]):
			i += 1
		_set_color_range(colors, colon_start, i, pseudo_color)
		return i

	# Check for class selector .class
	if line[i] == ".":
		colors[i] = {"color": selector_color}
		i += 1
		while i < length and _is_ident_char(line[i]):
			i += 1
		_set_color_range(colors, start, i, selector_color)
		return i

	# Check for ID selector #id
	if line[i] == "#":
		colors[i] = {"color": selector_color}
		i += 1
		while i < length and _is_ident_char(line[i]):
			i += 1
		_set_color_range(colors, start, i, selector_color)
		return i

	# Check for attribute selector [attr]
	if line[i] == "[":
		while i < length and line[i] != "]":
			i += 1
		if i < length:
			i += 1
		_set_color_range(colors, start, i, selector_color)
		return i

	# Tag selector or other
	if _is_ident_start_char(line[i]):
		while i < length and _is_ident_char(line[i]):
			i += 1
		_set_color_range(colors, start, i, selector_color)
		return i

	# Punctuation (, > + ~)
	if line[i] == "," or line[i] == ">" or line[i] == "+" or line[i] == "~":
		colors[i] = {"color": punctuation_color}
		return i + 1

	return i + 1


func _parse_property_context(line: String, i: int, length: int, colors: Dictionary, state: State) -> int:
	var start = i

	# Check for } which ends rule
	if line[i] == "}":
		colors[i] = {"color": punctuation_color}
		return i + 1

	# Check for : which transitions to value
	if line[i] == ":":
		colors[i] = {"color": punctuation_color}
		return i + 1

	# Property name
	if _is_ident_start_char(line[i]) or line[i] == "-":
		while i < length and (_is_ident_char(line[i]) or line[i] == "-"):
			i += 1
		_set_color_range(colors, start, i, property_color)
		return i

	return i + 1


func _parse_value_context(line: String, i: int, length: int, colors: Dictionary, state: State) -> int:
	var start = i

	# Check for ; which ends value
	if line[i] == ";":
		colors[i] = {"color": punctuation_color}
		return i + 1

	# Check for } which ends rule
	if line[i] == "}":
		colors[i] = {"color": punctuation_color}
		return i + 1

	# Check for !important
	if line[i] == "!":
		var imp_start = i
		i += 1
		while i < length and _is_ident_char(line[i]):
			i += 1
		_set_color_range(colors, imp_start, i, important_color)
		return i

	# Check for hex color #fff or #ffffff
	if line[i] == "#":
		var hex_start = i
		i += 1
		while i < length and _is_hex_char(line[i]):
			i += 1
		_set_color_range(colors, hex_start, i, color_hex_color)
		return i

	# Check for string "..." or '...'
	if line[i] == '"' or line[i] == "'":
		var quote = line[i]
		i += 1
		while i < length and line[i] != quote:
			i += 1
		if i < length:
			i += 1
		_set_color_range(colors, start, i, string_color)
		return i

	# Check for number (including negative)
	if _is_digit(line[i]) or (line[i] == "-" and i + 1 < length and _is_digit(line[i + 1])) or (line[i] == "." and i + 1 < length and _is_digit(line[i + 1])):
		var num_start = i
		if line[i] == "-":
			i += 1
		# Integer part
		while i < length and _is_digit(line[i]):
			i += 1
		# Decimal part
		if i < length and line[i] == ".":
			i += 1
			while i < length and _is_digit(line[i]):
				i += 1
		_set_color_range(colors, num_start, i, number_color)
		# Unit (px, %, em, rem, etc.)
		if i < length and (_is_ident_start_char(line[i]) or line[i] == "%"):
			var unit_start = i
			if line[i] == "%":
				i += 1
			else:
				while i < length and _is_ident_char(line[i]):
					i += 1
			_set_color_range(colors, unit_start, i, unit_color)
		return i

	# Check for function like rgb(), url(), etc.
	if _is_ident_start_char(line[i]):
		var ident_start = i
		while i < length and _is_ident_char(line[i]):
			i += 1
		# Check if followed by (
		if i < length and line[i] == "(":
			_set_color_range(colors, ident_start, i, function_color)
			colors[i] = {"color": punctuation_color}
			i += 1
			# Parse function arguments
			var paren_depth = 1
			while i < length and paren_depth > 0:
				if line[i] == "(":
					paren_depth += 1
					colors[i] = {"color": punctuation_color}
				elif line[i] == ")":
					paren_depth -= 1
					colors[i] = {"color": punctuation_color}
				elif line[i] == ",":
					colors[i] = {"color": punctuation_color}
				elif _is_digit(line[i]) or (line[i] == "." and i + 1 < length and _is_digit(line[i + 1])):
					# Number in function
					var num_start = i
					while i < length and (_is_digit(line[i]) or line[i] == "."):
						i += 1
					_set_color_range(colors, num_start, i, number_color)
					# Unit
					if i < length and (_is_ident_start_char(line[i]) or line[i] == "%"):
						var unit_start = i
						if line[i] == "%":
							i += 1
						else:
							while i < length and _is_ident_char(line[i]):
								i += 1
						_set_color_range(colors, unit_start, i, unit_color)
					continue
				i += 1
			return i
		else:
			# Regular value identifier
			_set_color_range(colors, ident_start, i, value_color)
			return i

	# Punctuation
	if line[i] == "(" or line[i] == ")" or line[i] == ",":
		colors[i] = {"color": punctuation_color}
		return i + 1

	return i + 1


func _get_initial_state(text_edit: TextEdit, line_idx: int) -> State:
	# Scan previous lines to determine state
	var brace_depth = 0
	var in_value = false

	for prev_line_idx in range(line_idx):
		var prev_line = text_edit.get_line(prev_line_idx)
		for c in prev_line:
			if c == "{":
				brace_depth += 1
				in_value = false
			elif c == "}":
				brace_depth = max(0, brace_depth - 1)
				in_value = false
			elif c == ":" and brace_depth > 0:
				in_value = true
			elif c == ";":
				in_value = false

	if brace_depth == 0:
		return State.SELECTOR
	elif in_value:
		return State.VALUE
	else:
		return State.PROPERTY


func _update_state_from_char(line: String, i: int, current_state: State) -> State:
	if i < 0 or i >= line.length():
		return current_state

	var c = line[i]
	match c:
		"{":
			return State.PROPERTY
		"}":
			return State.SELECTOR
		":":
			if current_state == State.PROPERTY:
				return State.VALUE
		";":
			if current_state == State.VALUE:
				return State.PROPERTY

	return current_state


func _set_color_range(colors: Dictionary, start: int, end: int, color: Color) -> void:
	for j in range(start, end):
		colors[j] = {"color": color}


func _match_string(line: String, pos: int, match: String) -> bool:
	if pos + match.length() > line.length():
		return false
	return line.substr(pos, match.length()) == match


func _is_ident_start_char(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


func _is_ident_char(c: String) -> bool:
	return _is_ident_start_char(c) or (c >= "0" and c <= "9") or c == "-" or c == "_"


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


func _is_hex_char(c: String) -> bool:
	return _is_digit(c) or (c >= "a" and c <= "f") or (c >= "A" and c <= "F")
