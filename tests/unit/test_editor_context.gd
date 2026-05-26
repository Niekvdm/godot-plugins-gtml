extends GutTest

## Tests for GmlEditorContext — the shared "current buffer state" struct
## passed to autocomplete + jump + color engines.

func test_from_html_captures_kind_and_cursor() -> void:
	var ctx = GmlEditorContext.from_html("<div></div>", 2, 5, "<p></p>")
	assert_eq(ctx.kind, "html")
	assert_eq(ctx.text, "<div></div>")
	assert_eq(ctx.cursor_line, 2)
	assert_eq(ctx.cursor_col, 5)
	assert_eq(ctx.other_text, "<p></p>")


func test_from_css_captures_kind_and_cursor() -> void:
	var ctx = GmlEditorContext.from_css("div {}", 0, 3, "<div></div>")
	assert_eq(ctx.kind, "css")
	assert_eq(ctx.text, "div {}")
	assert_eq(ctx.cursor_line, 0)
	assert_eq(ctx.cursor_col, 3)
	assert_eq(ctx.other_text, "<div></div>")


func test_line_at_returns_indexed_line() -> void:
	var ctx = GmlEditorContext.from_html("<div>\n<p>x</p>\n</div>", 1, 0, "")
	assert_eq(ctx.line_at(0), "<div>")
	assert_eq(ctx.line_at(1), "<p>x</p>")
	assert_eq(ctx.line_at(2), "</div>")


func test_prefix_at_cursor_returns_text_before_cursor_on_current_line() -> void:
	var ctx = GmlEditorContext.from_css("div {\n  color: red;\n}", 1, 11, "")
	# Line 1 is "  color: red;"; col 11 is just after "color: re"
	# (2 leading spaces + "color: re" = 11 chars, cursor_col is exclusive upper bound)
	assert_eq(ctx.prefix_at_cursor(), "  color: re")


func test_prefix_at_cursor_clamps_when_col_past_eol() -> void:
	# Cursor reported past the end of the line should still return the whole line.
	var ctx = GmlEditorContext.from_css("hi", 0, 99, "")
	assert_eq(ctx.prefix_at_cursor(), "hi")


func test_prefix_at_cursor_returns_empty_when_line_out_of_range() -> void:
	# cursor_line beyond last line — line_at returns "", so prefix is "".
	var ctx = GmlEditorContext.from_html("<div>", 5, 3, "")
	assert_eq(ctx.prefix_at_cursor(), "")


func test_line_at_out_of_range_returns_empty() -> void:
	var ctx = GmlEditorContext.from_html("one\ntwo", 0, 0, "")
	assert_eq(ctx.line_at(-1), "")
	assert_eq(ctx.line_at(5), "")
