class_name GmlAutocompleteSource
extends RefCounted

## Generates autocomplete candidates for a given editor context.
##
## Returns an Array of Dictionaries: {label, kind, insert_text}.
## kind ∈ {"tag", "attr", "value", "property", "var", "class"}.
## insert_text is what the editor writes — may include the typed prefix
## or a snippet (e.g. <div></div> with caret position implied).

const HTML_TAGS := [
	"a", "article", "aside", "b", "br", "button", "div", "em",
	"footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header",
	"hr", "i", "img", "input", "label", "li", "main", "nav", "ol",
	"option", "p", "progress", "section", "select", "span", "strong",
	"svg", "textarea", "ul",
]

# Attributes valid for each known tag. Falls back to CORE_ATTRS otherwise.
const CORE_ATTRS := ["class", "id", "title", "aria-node", "@click", "style"]

const TAG_ATTRS := {
	"input": ["type", "value", "checked", "name", "placeholder", "disabled", "@click", "@keydown"],
	"label": ["for"],
	"a": ["href", "@click"],
	"img": ["src", "alt"],
	"button": ["disabled", "@click"],
	"form": ["@submit"],
	"textarea": ["disabled", "placeholder", "@keydown"],
	"select": ["name", "disabled"],
	"option": ["value", "selected"],
	"progress": ["value", "max"],
}

# Values for enumerated attributes. Tag-keyed so <input type=…> differs
# from any hypothetical other tag.
const ATTR_VALUES := {
	"type:input": ["text", "password", "email", "number", "checkbox", "radio", "range", "submit"],
}

# CSS property names — union of every known property the parser dispatches.
const CSS_PROPERTIES := [
	# Layout / box
	"display", "flex-direction", "flex-grow", "flex-shrink", "flex-basis",
	"flex-wrap", "align-items", "align-self", "justify-content", "order",
	"gap", "row-gap", "column-gap",
	"padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
	"margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
	"width", "height", "min-width", "max-width", "min-height", "max-height",
	"overflow", "overflow-x", "overflow-y",
	# Colors / borders / backgrounds
	"background-color", "background", "background-image", "color",
	"border", "border-width", "border-color", "border-radius",
	"border-top", "border-right", "border-bottom", "border-left",
	"border-top-width", "border-right-width", "border-bottom-width", "border-left-width",
	"border-top-color", "border-right-color", "border-bottom-color", "border-left-color",
	"border-top-left-radius", "border-top-right-radius",
	"border-bottom-left-radius", "border-bottom-right-radius",
	"box-shadow", "outline", "outline-offset",
	# Typography
	"font-size", "font-family", "font-weight", "letter-spacing", "word-spacing",
	"line-height", "text-align", "text-transform", "text-decoration",
	"text-indent", "text-overflow", "white-space", "text-shadow",
	# Misc
	"opacity", "visibility", "cursor", "list-style-type",
	"transition", "transition-property", "transition-duration",
	"transition-timing-function", "transition-delay",
	"transform",
]

# Value keywords per property — only enumerable ones.
const CSS_VALUES := {
	"display": ["flex", "block", "inline", "none"],
	"flex-direction": ["row", "column", "row-reverse", "column-reverse"],
	"flex-wrap": ["nowrap", "wrap", "wrap-reverse"],
	"align-items": ["flex-start", "center", "flex-end", "stretch", "baseline"],
	"align-self": ["auto", "flex-start", "center", "flex-end", "stretch"],
	"justify-content": ["flex-start", "center", "flex-end", "space-between", "space-around"],
	"text-align": ["left", "center", "right", "justify"],
	"text-transform": ["none", "uppercase", "lowercase", "capitalize"],
	"white-space": ["normal", "nowrap", "pre", "pre-wrap", "pre-line"],
	"text-overflow": ["clip", "ellipsis"],
	"overflow": ["visible", "hidden", "scroll", "auto"],
	"overflow-x": ["visible", "hidden", "scroll", "auto"],
	"overflow-y": ["visible", "hidden", "scroll", "auto"],
	"visibility": ["visible", "hidden"],
	"cursor": ["default", "pointer", "text", "move", "wait", "progress", "crosshair", "help",
		"not-allowed", "grab", "grabbing", "col-resize", "row-resize"],
	"font-weight": ["100", "200", "300", "400", "500", "600", "700", "800", "900"],
	"list-style-type": ["disc", "circle", "square", "decimal", "decimal-leading-zero",
		"lower-alpha", "upper-alpha", "lower-roman", "upper-roman", "none"],
}


static func get_candidates(ctx: GmlEditorContext) -> Array:
	if ctx.kind == "html":
		return _html_candidates(ctx)
	if ctx.kind == "css":
		return _css_candidates(ctx)
	return []


static func _html_candidates(ctx: GmlEditorContext) -> Array:
	var prefix := ctx.prefix_at_cursor()
	var open := prefix.rfind("<")
	var close := prefix.rfind(">")
	if open < 0 or open <= close:
		return []

	var inside := prefix.substr(open + 1)

	# Are we still in the tag-name part? (no whitespace yet)
	if not _contains_whitespace(inside):
		return _tag_candidates()

	# Are we inside an attribute value? Look for an unclosed quote.
	var quote_open := _last_unclosed_quote(inside)
	if quote_open >= 0:
		# Find the attr name to the left of the quote: pattern is `attr="`.
		var head := inside.substr(0, quote_open)
		var eq := head.rfind("=")
		if eq < 0:
			return []
		var attr_name := _trailing_attr_name(head.substr(0, eq))
		var tag_name := _tag_at_start(inside)
		if attr_name == "class":
			return _class_candidates(ctx.other_text)
		return _attr_value_candidates(tag_name, attr_name)

	# Otherwise we're picking an attribute name.
	var tag_name := _tag_at_start(inside)
	return _attr_candidates(tag_name)


static func _tag_candidates() -> Array:
	var out: Array = []
	for tag in HTML_TAGS:
		out.append({"label": tag, "kind": "tag", "insert_text": tag})
	return out


static func _tag_at_start(inside_tag: String) -> String:
	for i in inside_tag.length():
		var ch := inside_tag[i]
		if ch == " " or ch == "\t" or ch == "\n":
			return inside_tag.substr(0, i).to_lower()
	return inside_tag.to_lower()


static func _contains_whitespace(s: String) -> bool:
	for ch in s:
		if ch == " " or ch == "\t" or ch == "\n":
			return true
	return false


## Locate the position of the last quote that opened an attribute value but
## hasn't been closed yet. Returns -1 if all quotes are balanced or none.
static func _last_unclosed_quote(s: String) -> int:
	var in_quote := false
	var quote_char := ""
	var last_open := -1
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if in_quote:
			if ch == quote_char:
				in_quote = false
		else:
			if ch == "\"" or ch == "'":
				in_quote = true
				quote_char = ch
				last_open = i
		i += 1
	return last_open if in_quote else -1


static func _attr_candidates(tag: String) -> Array:
	var attrs: Array = TAG_ATTRS.get(tag, [])
	# Always offer core attrs, deduped.
	var seen: Dictionary = {}
	var out: Array = []
	for a in attrs:
		seen[a] = true
		out.append({"label": a, "kind": "attr", "insert_text": a})
	for a in CORE_ATTRS:
		if not seen.has(a):
			out.append({"label": a, "kind": "attr", "insert_text": a})
	return out


static func _attr_value_candidates(tag: String, attr: String) -> Array:
	var key: String = "%s:%s" % [attr, tag]
	var vals: Array = ATTR_VALUES.get(key, [])
	var out: Array = []
	for v in vals:
		out.append({"label": v, "kind": "value", "insert_text": v})
	return out


## Last whitespace-delimited token in a string — the attribute name just
## before an = sign.
static func _trailing_attr_name(s: String) -> String:
	var stripped := s.strip_edges()
	var space := stripped.rfind(" ")
	if space < 0:
		return stripped
	return stripped.substr(space + 1)


static func _css_candidates(ctx: GmlEditorContext) -> Array:
	var prefix := ctx.prefix_at_cursor()

	# `var(` completion — even outside a block (e.g. inside a calc()) the
	# var-name list is the same. Must fire BEFORE the inside-block check.
	if prefix.contains("var(") and not _is_var_call_closed(prefix):
		return _var_candidates(ctx.text)

	# Are we inside a declaration block? Find last { vs last }.
	var abs_off := _absolute_offset(ctx)
	var open := ctx.text.substr(0, abs_off).rfind("{")
	var close := ctx.text.substr(0, abs_off).rfind("}")
	var inside_block := open > close

	if not inside_block:
		return []

	# Within the current line: is the cursor before or after a colon?
	var colon := prefix.rfind(":")
	var semi := prefix.rfind(";")
	if colon >= 0 and colon > semi:
		# After a colon — we're typing a value. Look back from the colon to
		# the property name on the current line.
		var head := prefix.substr(0, colon).strip_edges()
		# Property name is the trailing identifier (allow - and digits).
		var prop := _trailing_property_name(head)
		return _value_candidates(prop)

	# Otherwise we're typing a property name.
	return _property_candidates()


## Compute the absolute character offset of the cursor in the buffer.
static func _absolute_offset(ctx: GmlEditorContext) -> int:
	var off := 0
	for i in range(ctx.cursor_line):
		off += ctx.line_at(i).length() + 1   # +1 for the newline
	return off + ctx.cursor_col


static func _trailing_property_name(s: String) -> String:
	var i := s.length() - 1
	while i >= 0:
		var ch := s[i]
		if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch.is_valid_int():
			i -= 1
		else:
			break
	return s.substr(i + 1).to_lower()


static func _property_candidates() -> Array:
	var out: Array = []
	for p in CSS_PROPERTIES:
		out.append({"label": p, "kind": "property", "insert_text": p})
	return out


static func _value_candidates(prop: String) -> Array:
	var vals: Array = CSS_VALUES.get(prop, [])
	var out: Array = []
	for v in vals:
		out.append({"label": v, "kind": "value", "insert_text": v})
	return out


## After the last `var(` on the line, is the matching `)` already closed?
static func _is_var_call_closed(prefix: String) -> bool:
	var last_open := prefix.rfind("var(")
	if last_open < 0:
		return true
	# Count parens after the var(
	var tail := prefix.substr(last_open + 4)
	var depth := 1
	for ch in tail:
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return true
	return false


## Scan a CSS buffer for `--name:` declarations and return them as
## autocomplete candidates.
static func _var_candidates(css: String) -> Array:
	var regex := RegEx.new()
	regex.compile("(--[a-zA-Z_][\\w-]*)\\s*:")   # capture name, anchored on :
	var seen: Dictionary = {}
	var out: Array = []
	for m in regex.search_all(css):
		var name := m.get_string(1)   # group 1 = the --name only
		if not seen.has(name):
			seen[name] = true
			out.append({"label": name, "kind": "var", "insert_text": name})
	return out


## Scan a CSS buffer for `.classname` selectors and return them as candidates.
static func _class_candidates(css: String) -> Array:
	var regex := RegEx.new()
	regex.compile("\\.([a-zA-Z_][\\w-]*)")
	var seen: Dictionary = {}
	var out: Array = []
	for m in regex.search_all(css):
		var name := m.get_string(1)   # without the dot
		if not seen.has(name):
			seen[name] = true
			out.append({"label": name, "kind": "class", "insert_text": name})
	return out
