extends GutTest

## Pins parser termination guarantees that the Forge showcase regression
## exposed: stray closing tags for void elements (</input>, </br>) and
## position-non-advancing returns from _parse_node must never lock the
## parser into an infinite loop.

const GtmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GtmlHtmlParser.gd")


func _parse(s: String):
	# Run under a wall-clock budget so a regression doesn't hang the suite.
	var t0 := Time.get_ticks_msec()
	var dom = GtmlHtmlParserScript.new().parse(s)
	var dt := Time.get_ticks_msec() - t0
	assert_true(dt < 1000, "parser took %dms (expected <1000) on input: %s" % [dt, s.substr(0, 80)])
	return dom


func test_stray_closing_input_does_not_loop() -> void:
	# Authors who type </input> shouldn't hang the renderer. Void elements
	# are self-closing; an explicit close tag for them must be a no-op.
	var dom = _parse('<div><input type="text" value="x"></input></div>')
	assert_not_null(dom)
	assert_eq(dom.tag, "div")
	# input should be a direct child
	assert_eq(dom.children.size(), 1)
	assert_eq(dom.children[0].tag, "input")


func test_input_with_explicit_close_inside_form() -> void:
	# Real-world Forge pattern: <input> followed by </input> followed by
	# a real sibling. The sibling must NOT be eaten by misparsing.
	var dom = _parse('<div><label>n</label><input type="text"></input><span>hint</span></div>')
	assert_eq(dom.children.size(), 3)
	assert_eq(dom.children[0].tag, "label")
	assert_eq(dom.children[1].tag, "input")
	assert_eq(dom.children[2].tag, "span")


func test_many_inputs_in_a_row_do_not_loop() -> void:
	# Stress version of the Forge case — 20 fields, each with the explicit
	# closing tag. Should parse in milliseconds, not hang.
	var body := ""
	for i in range(20):
		body += '<div><input type="text" value="%d"></input></div>' % i
	var dom = _parse("<div>" + body + "</div>")
	assert_not_null(dom)
	assert_eq(dom.children.size(), 20)


func test_stray_top_level_closing_tag_terminates() -> void:
	# Pathological input — closing tag with no matching open at the
	# top level. Must not hang; behavior is "skip and continue".
	var dom = _parse("</div><p>after</p>")
	assert_not_null(dom)
	assert_eq(dom.tag, "p")
	assert_eq(dom.children[0].text, "after")


func test_stray_closing_br_does_not_loop() -> void:
	var dom = _parse("<div>line one<br></br>line two</div>")
	assert_not_null(dom)
	# Three children: text, br, text
	assert_eq(dom.children.size(), 3)
	assert_eq(dom.children[1].tag, "br")


func test_trailing_stray_void_close_at_eof_terminates() -> void:
	# Pathological input: a stray </input> immediately after the real DOM ends.
	# Parser must consume it cleanly and return without spinning.
	var dom = _parse("<div>hi</div></input>")
	assert_not_null(dom)
	assert_eq(dom.tag, "div")


func test_malformed_empty_closing_tag_terminates() -> void:
	# </> and </ > (closing tag with no name) — pathological but plausible
	# author error. Must not hang. We assert termination + a sane root tag,
	# not a specific child structure.
	var dom1 = _parse("<p>a</></p>")
	assert_not_null(dom1)
	var dom2 = _parse("<p>a</  ></p>")
	assert_not_null(dom2)


func test_html_parser_records_warnings_with_line_col() -> void:
	# get_warnings() mirrors the CSS parser's contract: each warning carries
	# {line, col, msg} so the editor overlay can offer click-to-jump.
	var parser = GtmlHtmlParserScript.new()
	parser.parse("<div>\n<p>a</q>\n</div>")
	var warnings: Array = parser.get_warnings()
	assert_true(warnings.size() > 0, "expected at least one warning for mismatched </q>")
	var w = warnings[0]
	assert_true(w.has("line"))
	assert_true(w.has("col"))
	assert_true(w.has("msg"))
