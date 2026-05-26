class_name GmlJumpResolver
extends RefCounted

## Resolves a cursor position to a jump target.
## Returns {target_kind, line, col} or null.

static func resolve(ctx: GmlEditorContext) -> Variant:
	if ctx.kind == "html":
		return _resolve_html(ctx)
	if ctx.kind == "css":
		return _resolve_css(ctx)
	return null


# ─── HTML side ────────────────────────────────────────────────────

static func _resolve_html(ctx: GmlEditorContext) -> Variant:
	var line := ctx.line_at(ctx.cursor_line)
	var token := _token_at(line, ctx.cursor_col, "[\\w-]+")
	if token.is_empty():
		return null

	# Is the token sitting inside an attribute value? Walk back from the
	# cursor on the same line to find the nearest attr name and "=".
	var attr := _attr_around_cursor(line, ctx.cursor_col)
	if attr == "class":
		return _find_in_css(ctx.other_text, "." + token)
	if attr == "id":
		return _find_in_css(ctx.other_text, "#" + token)
	return null


# ─── CSS side ─────────────────────────────────────────────────────

static func _resolve_css(ctx: GmlEditorContext) -> Variant:
	var line := ctx.line_at(ctx.cursor_line)
	var col := ctx.cursor_col

	# var(--name) use → declaration
	var var_name := _var_name_around_cursor(line, col)
	if not var_name.is_empty():
		return _find_var_declaration(ctx.text, var_name, ctx.cursor_line)

	# --name: declaration → first use
	var decl_name := _var_decl_around_cursor(line, col)
	if not decl_name.is_empty():
		return _find_var_use(ctx.text, decl_name, ctx.cursor_line)

	# Selector .class → HTML element
	var class_sel := _selector_token_around_cursor(line, col, ".")
	if not class_sel.is_empty():
		return _find_in_html(ctx.other_text, "class", class_sel)

	# Selector #id → HTML element
	var id_sel := _selector_token_around_cursor(line, col, "#")
	if not id_sel.is_empty():
		return _find_in_html(ctx.other_text, "id", id_sel)

	return null


# ─── Helpers ──────────────────────────────────────────────────────

static func _token_at(line: String, col: int, pattern: String) -> String:
	var re := RegEx.new()
	re.compile(pattern)
	for m in re.search_all(line):
		if col >= m.get_start() and col <= m.get_end():
			return m.get_string()
	return ""


## Walk forward from line start; return the attribute name whose value
## contains the cursor. Returns "" if cursor isn't inside an attr value.
##
## Tracks quote-pair state so text content AFTER a closed attribute value
## doesn't get misclassified as being inside an attribute.
static func _attr_around_cursor(line: String, col: int) -> String:
	var i := 0
	var n := line.length()
	var in_value := false
	var quote := ""
	var attr_name := ""
	var attr_name_end := -1
	var value_start := -1
	while i < n:
		var ch := line[i]
		if in_value:
			if ch == quote:
				# Closing quote — check if cursor was inside this value.
				if col > value_start and col <= i:
					return attr_name
				in_value = false
				quote = ""
				attr_name = ""
			i += 1
			continue
		# Outside a value — look for `attr_name =` followed by a quote.
		if ch == "=":
			# Scan back for the attribute name preceding the `=`.
			var j := i - 1
			while j >= 0 and (line[j] == " " or line[j] == "\t"):
				j -= 1
			attr_name_end = j + 1
			var k := j
			while k >= 0 and (line[k].is_valid_identifier() or line[k] == "-" or line[k] == "_" or line[k] == "@"):
				k -= 1
			attr_name = line.substr(k + 1, attr_name_end - k - 1)
			# Look forward past = and whitespace for the opening quote.
			var m := i + 1
			while m < n and (line[m] == " " or line[m] == "\t"):
				m += 1
			if m < n and (line[m] == "\"" or line[m] == "'"):
				in_value = true
				quote = line[m]
				value_start = m
				i = m + 1
				continue
		i += 1
	# Unterminated value — cursor inside it counts.
	if in_value and col > value_start:
		return attr_name
	return ""


static func _var_name_around_cursor(line: String, col: int) -> String:
	var re := RegEx.new()
	re.compile("var\\(\\s*(--[\\w-]+)")
	for m in re.search_all(line):
		if col >= m.get_start() and col <= m.get_end():
			return m.get_string(1)
	return ""


static func _var_decl_around_cursor(line: String, col: int) -> String:
	# `--name:` at the start of a declaration
	var re := RegEx.new()
	re.compile("(--[\\w-]+)\\s*:")
	for m in re.search_all(line):
		var name_start := m.get_start()
		var name_end := name_start + m.get_string(1).length()
		if col >= name_start and col <= name_end:
			return m.get_string(1)
	return ""


## Selector token (.class or #id) containing the cursor. Pass "." for class,
## "#" for id. Returns the bare name (no prefix).
static func _selector_token_around_cursor(line: String, col: int, prefix: String) -> String:
	var re := RegEx.new()
	re.compile("\\%s([a-zA-Z_][\\w-]*)" % prefix)
	for m in re.search_all(line):
		if col >= m.get_start() and col <= m.get_end():
			return m.get_string(1)
	return ""


static func _find_in_css(css: String, selector: String) -> Variant:
	var lines := css.split("\n")
	# Look for selector followed by optional whitespace then { or , or end
	var re := RegEx.new()
	re.compile("\\%s\\b" % selector)
	for i in range(lines.size()):
		var m := re.search(lines[i])
		if m != null:
			return {"target_kind": "css", "line": i, "col": m.get_start()}
	return null


static func _find_in_html(html: String, attr: String, value: String) -> Variant:
	var lines := html.split("\n")
	var re := RegEx.new()
	if attr == "class":
		# class attribute may have multiple whitespace-separated values
		re.compile('class="[^"]*\\b%s\\b[^"]*"' % value)
	else:
		re.compile('%s="%s"' % [attr, value])
	for i in range(lines.size()):
		var m := re.search(lines[i])
		if m != null:
			return {"target_kind": "html", "line": i, "col": m.get_start()}
	return null


static func _find_var_declaration(css: String, var_name: String, ignore_line: int) -> Variant:
	var lines := css.split("\n")
	var re := RegEx.new()
	re.compile("\\%s\\s*:" % var_name)
	for i in range(lines.size()):
		if i == ignore_line:
			continue
		var m := re.search(lines[i])
		if m != null:
			return {"target_kind": "css", "line": i, "col": m.get_start()}
	return null


static func _find_var_use(css: String, var_name: String, ignore_line: int) -> Variant:
	var lines := css.split("\n")
	var re := RegEx.new()
	re.compile("var\\(\\s*\\%s\\b" % var_name)
	for i in range(lines.size()):
		if i == ignore_line:
			continue
		var m := re.search(lines[i])
		if m != null:
			return {"target_kind": "css", "line": i, "col": m.get_start()}
	return null
