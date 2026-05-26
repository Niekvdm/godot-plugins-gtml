extends GutTest

## Tests for the v0.2 selector engine: compound selectors, combinators
## (descendant, child), attribute matching, and specificity-based cascade.

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")
const GmlSelectorScript = preload("res://addons/gtml/src/css/GmlSelector.gd")


func _dom(html: String):
	return GmlHtmlParserScript.new().parse(html)


func _rules(css: String) -> Array:
	return GmlCssParserScript.new().parse(css)


func _resolve(html: String, css: String) -> Array:
	# Returns [{node, style}] flattened tuples for the whole tree.
	var dom = _dom(html)
	var rules := _rules(css)
	var styles: Dictionary = GmlStyleResolverScript.new().resolve(dom, rules)
	var out: Array = []
	_walk(dom, styles, out)
	return out


func _walk(node, styles: Dictionary, out: Array) -> void:
	if node == null or node.is_text_node:
		return
	if styles.has(node):
		out.append({"node": node, "style": styles[node]})
	for c in node.children:
		_walk(c, styles, out)


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


#region Selector parsing


func test_selector_parses_tag() -> void:
	var sel = GmlSelectorScript.parse("div")
	assert_eq(sel.compounds.size(), 1)
	assert_eq(sel.compounds[0].tag, "div")


func test_selector_parses_compound_tag_class_id() -> void:
	var sel = GmlSelectorScript.parse("div.foo#bar")
	assert_eq(sel.compounds.size(), 1)
	var c = sel.compounds[0]
	assert_eq(c.tag, "div")
	assert_has(c.classes, "foo")
	assert_eq(c.id, "bar")


func test_selector_parses_descendant() -> void:
	var sel = GmlSelectorScript.parse(".a .b")
	assert_eq(sel.compounds.size(), 2)
	assert_eq(sel.combinators.size(), 1)
	assert_eq(sel.combinators[0], " ")


func test_selector_parses_child() -> void:
	var sel = GmlSelectorScript.parse(".a > .b")
	assert_eq(sel.compounds.size(), 2)
	assert_eq(sel.combinators[0], ">")


func test_selector_parses_attribute_presence() -> void:
	var sel = GmlSelectorScript.parse("input[disabled]")
	var c = sel.compounds[0]
	assert_eq(c.tag, "input")
	assert_eq(c.attrs.size(), 1)
	assert_eq(c.attrs[0].name, "disabled")
	assert_eq(c.attrs[0].op, "")


func test_selector_parses_attribute_equality() -> void:
	var sel = GmlSelectorScript.parse('input[type="text"]')
	var c = sel.compounds[0]
	assert_eq(c.attrs.size(), 1)
	assert_eq(c.attrs[0].name, "type")
	assert_eq(c.attrs[0].op, "=")
	assert_eq(c.attrs[0].value, "text")


func test_selector_parses_pseudo() -> void:
	var sel = GmlSelectorScript.parse("button:hover")
	assert_eq(sel.compounds[0].tag, "button")
	assert_eq(sel.compounds[0].pseudos, PackedStringArray(["hover"]))


#endregion


#region Specificity


func test_specificity_id_wins_over_class() -> void:
	var s = _style_for_id("<div id='x' class='c'></div>", "#x { color: red; } .c { color: blue; }", "x")
	assert_eq(s.get("color"), Color.RED)


func test_specificity_class_wins_over_tag() -> void:
	var s = _style_for_id("<div id='x' class='c'></div>", "div { color: red; } .c { color: blue; }", "x")
	assert_eq(s.get("color"), Color.BLUE)


func test_specificity_source_order_breaks_tie() -> void:
	var s = _style_for_id("<div id='x' class='a b'></div>", ".a { color: red; } .b { color: blue; }", "x")
	assert_eq(s.get("color"), Color.BLUE)


func test_specificity_compound_beats_simple() -> void:
	# .a.b (2 classes) should beat .a (1 class) even if .a comes later
	var s = _style_for_id(
		"<div id='x' class='a b'></div>",
		".a.b { color: red; } .a { color: blue; }",
		"x")
	assert_eq(s.get("color"), Color.RED)


#endregion


#region Combinators


func test_descendant_matches_nested() -> void:
	var s = _style_for_id(
		"<div class='a'><div id='target' class='b'></div></div>",
		".a .b { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_descendant_does_not_match_outside_ancestor() -> void:
	var s = _style_for_id(
		"<div><div id='target' class='b'></div></div>",
		".a .b { color: red; }",
		"target")
	assert_false(s.has("color"), "outside .a ancestor should not match")


func test_child_matches_direct_only() -> void:
	# Direct child
	var s1 = _style_for_id(
		"<div class='a'><div id='target' class='b'></div></div>",
		".a > .b { color: red; }",
		"target")
	assert_eq(s1.get("color"), Color.RED)

	# Grandchild should NOT match
	var s2 = _style_for_id(
		"<div class='a'><div><div id='target' class='b'></div></div></div>",
		".a > .b { color: red; }",
		"target")
	assert_false(s2.has("color"), "child combinator should not match grandchildren")


#endregion


#region Attribute selectors


func test_attr_presence_match() -> void:
	var s = _style_for_id(
		"<input id='target' disabled>",
		"input[disabled] { color: red; }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_attr_equality_match() -> void:
	var s = _style_for_id(
		"<input id='target' type='text'>",
		'input[type="text"] { color: red; }',
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_attr_equality_no_match() -> void:
	var s = _style_for_id(
		"<input id='target' type='password'>",
		'input[type="text"] { color: red; }',
		"target")
	assert_false(s.has("color"))


#endregion
