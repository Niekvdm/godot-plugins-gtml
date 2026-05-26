extends GutTest

## v0.3 selector engine extensions:
##   - Sibling combinators (+ adjacent, ~ general)
##   - Substring attribute matchers (~=, ^=, $=, *=)
##   - Structural pseudo-classes (:not, :nth-child, :first-child, :last-child,
##     :only-child)

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")
const GmlSelectorScript = preload("res://addons/gtml/src/css/GmlSelector.gd")


func _dom(html: String):
	return GmlHtmlParserScript.new().parse(html)


func _rules(css: String) -> Array:
	return GmlCssParserScript.new().parse(css)


func _style_for_id(html: String, css: String, id: String) -> Dictionary:
	var dom = _dom(html)
	var rules := _rules(css)
	var styles: Dictionary = GmlStyleResolverScript.new().resolve(dom, rules)
	var found = _find_by_id(dom, id)
	if found == null:
		return {}
	return styles.get(found, {})


func _find_by_id(node, id: String):
	if node == null or node.is_text_node:
		return null
	if node.get_id() == id:
		return node
	for c in node.children:
		var r = _find_by_id(c, id)
		if r != null:
			return r
	return null


#region Sibling combinators


func test_adjacent_sibling_matches_immediate_next() -> void:
	var s = _style_for_id(
		"<div><p class='a'></p><p id='target' class='b'></p></div>",
		".a + .b { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_adjacent_sibling_does_not_match_skipped() -> void:
	# .b separated from .a by another sibling — must NOT match (+ is strict)
	var s = _style_for_id(
		"<div><p class='a'></p><p class='middle'></p><p id='target' class='b'></p></div>",
		".a + .b { color: red; }",
		"target")
	assert_false(s.has("color"))


func test_general_sibling_matches_any_following() -> void:
	# .b is two positions after .a — must still match ~
	var s = _style_for_id(
		"<div><p class='a'></p><p class='middle'></p><p id='target' class='b'></p></div>",
		".a ~ .b { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_sibling_does_not_match_when_no_preceding() -> void:
	var s = _style_for_id(
		"<div><p id='target' class='b'></p></div>",
		".a ~ .b { color: red; }",
		"target")
	assert_false(s.has("color"))


#endregion


#region Substring attribute matchers


func test_attr_whitespace_word_includes() -> void:
	var s = _style_for_id(
		'<div id="target" class="foo bar baz"></div>',
		'[class~="bar"] { color: red; }',
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_attr_whitespace_word_no_substring_match() -> void:
	# ~= matches whole words only — "bar" must not match "barley"
	var s = _style_for_id(
		'<div id="target" class="barley"></div>',
		'[class~="bar"] { color: red; }',
		"target")
	assert_false(s.has("color"))


func test_attr_prefix_match() -> void:
	var s = _style_for_id(
		'<a id="target" href="https://example.com">x</a>',
		'[href^="https://"] { color: red; }',
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_attr_suffix_match() -> void:
	var s = _style_for_id(
		'<img id="target" src="logo.png">',
		'[src$=".png"] { color: red; }',
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_attr_substring_match() -> void:
	var s = _style_for_id(
		'<a id="target" href="https://api.example.com/v1/users">x</a>',
		'[href*="example"] { color: red; }',
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_attr_substring_no_match() -> void:
	var s = _style_for_id(
		'<a id="target" href="https://other.com/">x</a>',
		'[href*="example"] { color: red; }',
		"target")
	assert_false(s.has("color"))


#endregion


#region Structural pseudo-classes


func test_first_child_matches() -> void:
	var s = _style_for_id(
		"<ul><li id='target'>a</li><li>b</li></ul>",
		"li:first-child { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_first_child_does_not_match_second() -> void:
	var s = _style_for_id(
		"<ul><li>a</li><li id='target'>b</li></ul>",
		"li:first-child { color: red; }",
		"target")
	assert_false(s.has("color"))


func test_last_child_matches() -> void:
	var s = _style_for_id(
		"<ul><li>a</li><li id='target'>b</li></ul>",
		"li:last-child { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_only_child_matches_when_alone() -> void:
	var s = _style_for_id(
		"<ul><li id='target'>solo</li></ul>",
		"li:only-child { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_only_child_does_not_match_with_siblings() -> void:
	var s = _style_for_id(
		"<ul><li id='target'>a</li><li>b</li></ul>",
		"li:only-child { color: red; }",
		"target")
	assert_false(s.has("color"))


func test_nth_child_integer() -> void:
	var s = _style_for_id(
		"<ul><li>a</li><li id='target'>b</li><li>c</li></ul>",
		"li:nth-child(2) { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_nth_child_odd() -> void:
	var s = _style_for_id(
		"<ul><li>a</li><li id='target'>b</li><li>c</li></ul>",
		"li:nth-child(odd) { color: red; }",
		"target")
	# Position 2 is even — odd should NOT match
	assert_false(s.has("color"))


func test_nth_child_even() -> void:
	var s = _style_for_id(
		"<ul><li>a</li><li id='target'>b</li><li>c</li></ul>",
		"li:nth-child(even) { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_not_excludes_class() -> void:
	var s = _style_for_id(
		"<div><p id='target'></p><p class='special'></p></div>",
		"p:not(.special) { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_not_does_not_match_when_excluded_class_present() -> void:
	var s = _style_for_id(
		"<div><p></p><p id='target' class='special'></p></div>",
		"p:not(.special) { color: red; }",
		"target")
	assert_false(s.has("color"))


func test_nested_not_double_negative_matches() -> void:
	# :not(:not(.x)) is the double-negative — should match elements WITH .x.
	# Guards against accidental infinite recursion in the matcher.
	var s = _style_for_id(
		"<div><p id='target' class='x'></p></div>",
		"p:not(:not(.x)) { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_adjacent_sibling_parses_without_spaces() -> void:
	# .a+.b (no whitespace around the combinator) must parse identically to
	# ".a + .b". This pins the lexer branch that fires when a combinator
	# character appears immediately after the previous compound.
	var s = _style_for_id(
		"<div><p class='a'></p><p id='target' class='b'></p></div>",
		".a+.b { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_nth_child_an_plus_b() -> void:
	# nth-child(2n+1) -> 1st, 3rd, 5th. Third <li> (target) should match.
	var s = _style_for_id(
		"<ul><li>a</li><li>b</li><li id='target'>c</li></ul>",
		"li:nth-child(2n+1) { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_nth_child_negative_an_plus_b() -> void:
	# nth-child(-n+2) -> first 2 elements. Second <li> (target) matches; third doesn't.
	var s_in = _style_for_id(
		"<ul><li>a</li><li id='target'>b</li><li>c</li></ul>",
		"li:nth-child(-n+2) { color: red; }",
		"target")
	assert_eq(s_in.get("color"), Color.RED)

	var s_out = _style_for_id(
		"<ul><li>a</li><li>b</li><li id='target'>c</li></ul>",
		"li:nth-child(-n+2) { color: red; }",
		"target")
	assert_false(s_out.has("color"))


#endregion
