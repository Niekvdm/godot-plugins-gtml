extends GutTest

## Tests for GmlAutocompleteSource — the engine that, given a buffer +
## cursor context, returns candidate completions. Each candidate is a
## Dictionary: {label: String, kind: String, insert_text: String}.
##
## kind values: "tag" | "attr" | "value" | "property" | "var" | "class"

func _html_ctx(text: String, line: int, col: int) -> GmlEditorContext:
	return GmlEditorContext.from_html(text, line, col, "")


func _css_ctx(text: String, line: int, col: int, html: String = "") -> GmlEditorContext:
	return GmlEditorContext.from_css(text, line, col, html)


func _labels(candidates: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for c in candidates:
		out.append(c["label"])
	return out


#region HTML tag completion

func test_html_tag_completion_after_open_bracket() -> void:
	# Cursor just past the < — expect a list of element tag names.
	var ctx = _html_ctx("<", 0, 1)
	var candidates = GmlAutocompleteSource.get_candidates(ctx)
	var labels = _labels(candidates)
	for tag in ["div", "p", "button", "input", "section", "h1", "ul", "li"]:
		assert_true(tag in labels, "missing expected tag '%s' from candidates" % tag)
	# And every candidate's kind is "tag"
	for c in candidates:
		assert_eq(c["kind"], "tag")


func test_html_tag_completion_filters_by_typed_prefix() -> void:
	# The engine returns ALL tags; the popup filters by prefix natively.
	# We just need the data to be there.
	var ctx = _html_ctx("<bu", 0, 3)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	assert_true("button" in labels)

#endregion


#region HTML attribute completion

func test_html_attr_completion_after_tag_and_space() -> void:
	# Cursor after "<div " — expect attribute names.
	var ctx = _html_ctx("<div ", 0, 5)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	for attr in ["class", "id", "title", "aria-node"]:
		assert_true(attr in labels)


func test_html_attr_completion_tag_specific_input() -> void:
	# <input attrs include type/value/checked/name/disabled
	var ctx = _html_ctx("<input ", 0, 7)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	for attr in ["type", "value", "checked", "name", "disabled", "placeholder"]:
		assert_true(attr in labels, "missing input-specific attr '%s'" % attr)


func test_html_attr_completion_tag_specific_label() -> void:
	var ctx = _html_ctx("<label ", 0, 7)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	assert_true("for" in labels, "<label> should suggest 'for'")


func test_html_attr_value_completion_for_type() -> void:
	# Inside type="…" — expect input-type keywords.
	var ctx = _html_ctx('<input type="', 0, 13)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	for v in ["text", "password", "checkbox", "radio", "range", "submit"]:
		assert_true(v in labels)

#endregion


#region CSS property + value completion

func test_css_property_completion_inside_block() -> void:
	var ctx = _css_ctx("div {\n  \n}", 1, 2)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	for prop in ["color", "background-color", "padding", "display", "font-size", "transform"]:
		assert_true(prop in labels, "missing property '%s'" % prop)


func test_css_value_completion_after_colon_for_display() -> void:
	var ctx = _css_ctx("div { display: ", 0, 15)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	for v in ["flex", "block", "none"]:
		assert_true(v in labels, "display should suggest '%s'" % v)


func test_css_value_completion_after_colon_for_cursor() -> void:
	var ctx = _css_ctx("a { cursor: ", 0, 12)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	for v in ["pointer", "text", "wait"]:
		assert_true(v in labels)


func test_css_no_completion_when_outside_block() -> void:
	# At top-level (between rules), property completions are wrong context.
	var ctx = _css_ctx("div { color: red; }\n", 1, 0)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	# We accept any list (selector tag names are fine for top-level) BUT
	# property names should NOT be in it.
	assert_false("background-color" in labels)

#endregion


#region var() and class completion

func test_var_completion_lists_declared_custom_properties() -> void:
	var css := ".app { --brand: red; --gap: 8px; }\n.btn { color: var( }"
	var ctx = _css_ctx(css, 1, 19)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	assert_true("--brand" in labels)
	assert_true("--gap" in labels)


func test_class_completion_lists_classes_declared_in_other_buffer() -> void:
	# Editing HTML `class="…"`; should pull class names from the CSS buffer.
	var html := '<div class="'
	var css := ".card {}\n.row {}\n#x {}"
	var ctx = GmlEditorContext.from_html(html, 0, html.length(), css)
	var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
	assert_true("card" in labels)
	assert_true("row" in labels)
	# IDs should NOT appear in class completion
	assert_false("x" in labels)

#endregion
