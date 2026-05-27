extends GutTest

## Direct unit tests for parser correctness. These pin specific contracts
## (entity handling, self-closing tags, attribute parsing) that snapshot tests
## would catch only indirectly.

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")


func _parse_html(s: String):
	return GmlHtmlParserScript.new().parse(s)


func _parse_css(s: String) -> Array:
	return GmlCssParserScript.new().parse(s)


func test_single_element() -> void:
	var dom = _parse_html("<div></div>")
	assert_eq(dom.tag, "div")
	assert_eq(dom.children.size(), 0)


func test_attributes_quoted_and_unquoted() -> void:
	var dom = _parse_html('<div id="x" class=foo data-n="1"></div>')
	assert_eq(dom.attrs.get("id", ""), "x")
	assert_eq(dom.attrs.get("class", ""), "foo")
	assert_eq(dom.attrs.get("data-n", ""), "1")


func test_self_closing_void_tag() -> void:
	var dom = _parse_html("<div><br><img src=foo></div>")
	assert_eq(dom.children.size(), 2)
	assert_eq(dom.children[0].tag, "br")
	assert_eq(dom.children[1].tag, "img")


func test_text_node_normalization() -> void:
	var dom = _parse_html("<p>  hello   world  </p>")
	assert_eq(dom.children.size(), 1)
	assert_eq(dom.children[0].text, "hello world")


func test_comment_skipped() -> void:
	var dom = _parse_html("<div><!-- comment --><p>x</p></div>")
	assert_eq(dom.children.size(), 1)
	assert_eq(dom.children[0].tag, "p")


func test_at_click_attribute_preserved() -> void:
	var dom = _parse_html('<button @click="handle">go</button>')
	assert_eq(dom.attrs.get("@click", ""), "handle")


func test_css_tag_selector() -> void:
	var rules = _parse_css("div { color: red; }")
	assert_eq(rules.size(), 1)
	assert_eq(rules[0].selector_type, "tag")
	assert_eq(rules[0].selector_value, "div")


func test_css_class_id_selectors() -> void:
	var rules = _parse_css(".foo { color: red; } #bar { color: blue; }")
	assert_eq(rules.size(), 2)
	assert_eq(rules[0].selector_type, "class")
	assert_eq(rules[0].selector_value, "foo")
	assert_eq(rules[1].selector_type, "id")
	assert_eq(rules[1].selector_value, "bar")


func test_css_pseudo_class() -> void:
	var rules = _parse_css("button:hover { color: red; }")
	assert_eq(rules.size(), 1)
	assert_eq(rules[0].selector_value, "button")
	assert_eq(rules[0].pseudo_class, "hover")


func test_css_comma_selectors() -> void:
	var rules = _parse_css("a, b { color: red; }")
	assert_eq(rules.size(), 2)
	assert_eq(rules[0].selector_value, "a")
	assert_eq(rules[1].selector_value, "b")


func test_parser_accepts_colon_prefix_attribute() -> void:
	var dom = _parse_html('<div :class="x">y</div>')
	assert_eq(dom.attrs.get(":class", ""), "x")


func test_parser_accepts_v_directive_attribute() -> void:
	var dom = _parse_html('<div v-if="cond"></div>')
	assert_eq(dom.attrs.get("v-if", ""), "cond")
