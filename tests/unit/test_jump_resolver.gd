extends GutTest

## Tests for GmlJumpResolver.resolve(ctx) — given a cursor on a jumpable
## token, returns {target_kind, line, col} or null.

func _resolve(kind: String, text: String, line: int, col: int, other: String):
	var ctx = (
		GmlEditorContext.from_html(text, line, col, other) if kind == "html"
		else GmlEditorContext.from_css(text, line, col, other)
	)
	return GmlJumpResolver.resolve(ctx)


func test_html_class_jumps_to_css_rule() -> void:
	var html := '<div class="card"></div>'
	var css := ".card {\n  color: red;\n}\n"
	# Cursor inside "card" on line 0
	var jump = _resolve("html", html, 0, 14, css)
	assert_not_null(jump)
	assert_eq(jump["target_kind"], "css")
	assert_eq(jump["line"], 0)


func test_html_id_jumps_to_css_rule() -> void:
	var html := '<div id="main"></div>'
	var css := ".x {}\n#main {\n  padding: 8px;\n}\n"
	var jump = _resolve("html", html, 0, 11, css)
	assert_not_null(jump)
	assert_eq(jump["target_kind"], "css")
	assert_eq(jump["line"], 1)


func test_css_class_selector_jumps_to_first_html_use() -> void:
	var html := "<div>\n<p class=\"row\">x</p>\n</div>"
	var css := ".row { color: red; }"
	# Cursor inside ".row"
	var jump = _resolve("css", css, 0, 2, html)
	assert_not_null(jump)
	assert_eq(jump["target_kind"], "html")
	assert_eq(jump["line"], 1)


func test_css_id_selector_jumps_to_html_element() -> void:
	var html := "<div>\n<span id=\"target\">x</span>\n</div>"
	var css := "#target {}"
	var jump = _resolve("css", css, 0, 2, html)
	assert_not_null(jump)
	assert_eq(jump["target_kind"], "html")
	assert_eq(jump["line"], 1)


func test_var_use_jumps_to_declaration() -> void:
	var css := ".app { --brand: red; }\n.btn { color: var(--brand); }"
	# Cursor inside "var(--brand)" on line 1
	var jump = _resolve("css", css, 1, 20, "")
	assert_not_null(jump)
	assert_eq(jump["target_kind"], "css")
	assert_eq(jump["line"], 0)


func test_var_declaration_jumps_to_first_use() -> void:
	var css := ".app { --brand: red; }\n.btn { color: var(--brand); }"
	# Cursor inside "--brand:" on line 0
	var jump = _resolve("css", css, 0, 10, "")
	assert_not_null(jump)
	assert_eq(jump["target_kind"], "css")
	assert_eq(jump["line"], 1)


func test_no_jump_on_unknown_token_returns_null() -> void:
	var jump = _resolve("html", "<div>nothing</div>", 0, 8, "")
	assert_null(jump)


func test_html_class_with_no_matching_rule_returns_null() -> void:
	var html := '<div class="missing"></div>'
	var css := ".other {}"
	var jump = _resolve("html", html, 0, 14, css)
	assert_null(jump)


func test_html_text_after_closed_attr_returns_null() -> void:
	# Bug regression: cursor on text content AFTER a class="…" attribute
	# previously misread the closing quote and jumped to a phantom CSS rule
	# if the text happened to match a class name.
	var html := '<div class="card">hello</div>'
	var css := ".card {}\n.hello {}"
	# Cursor on "hello" (col ~20)
	var jump = _resolve("html", html, 0, 20, css)
	assert_null(jump, "text content after a closed attr must not jump")


func test_css_class_selector_jumps_when_cursor_on_dot() -> void:
	# Cursor on the `.` of `.row` selector should jump just like cursor on `row`.
	var html := "<div>\n<p class=\"row\">x</p>\n</div>"
	var css := ".row { color: red; }"
	var jump = _resolve("css", css, 0, 0, html)
	assert_not_null(jump, "cursor on selector prefix should jump")
	assert_eq(jump["target_kind"], "html")
