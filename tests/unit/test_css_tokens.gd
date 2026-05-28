extends GutTest

## v0.4: CSS custom properties (--name) and calc() resolution.
##
## Custom properties cascade through the DOM; var(--name) substitutes at
## resolve time against the cumulative ancestor scope. calc() evaluates
## simple arithmetic on numeric values with units.

const GtmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GtmlHtmlParser.gd")
const GtmlCssParserScript = preload("res://addons/gtml/src/css/GtmlCssParser.gd")
const GtmlStyleResolverScript = preload("res://addons/gtml/src/css/GtmlStyleResolver.gd")


func _style_for_id(html: String, css: String, id: String) -> Dictionary:
	var dom = GtmlHtmlParserScript.new().parse(html)
	var rules := GtmlCssParserScript.new().parse(css)
	var styles: Dictionary = GtmlStyleResolverScript.new().resolve(dom, rules)
	var node = _find_by_id(dom, id)
	if node == null:
		return {}
	return styles.get(node, {})


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


#region Custom properties — declaration + substitution


func test_var_substitution_same_rule() -> void:
	# A custom prop declared on the same selector — should resolve.
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { --brand: red; color: var(--brand); }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_var_substitution_from_ancestor_scope() -> void:
	# Custom prop on the parent should inherit to children's scope.
	var s := _style_for_id(
		"<div class='root'><p id='target'>x</p></div>",
		".root { --brand: blue; } p { color: var(--brand); }",
		"target")
	assert_eq(s.get("color"), Color.BLUE)


func test_var_with_fallback() -> void:
	# var(--undefined, fallback) should use the fallback when the variable
	# is not in scope.
	var s := _style_for_id(
		"<p id='target'>x</p>",
		"p { color: var(--missing, red); }",
		"target")
	assert_eq(s.get("color"), Color.RED)


func test_inner_scope_overrides_outer() -> void:
	# A redeclaration on a deeper scope must shadow the outer one for that
	# subtree.
	var s := _style_for_id(
		"<div class='outer'><div class='inner'><p id='target'>x</p></div></div>",
		".outer { --brand: red; } .inner { --brand: blue; } p { color: var(--brand); }",
		"target")
	assert_eq(s.get("color"), Color.BLUE)


func test_var_in_dimension_property() -> void:
	# Variables in dimension props (width/padding) round-trip through the
	# numeric type parser after substitution.
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { --pad: 24px; padding: var(--pad); }",
		"target")
	assert_eq(s.get("padding"), 24)


func test_custom_property_name_with_digit() -> void:
	# Pin the lexer change that allowed digits in property names. Without
	# it, --surface-2 truncated to --surface- and parsing collapsed.
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { --surface-2: blue; color: var(--surface-2); }",
		"target")
	assert_eq(s.get("color"), Color.BLUE)


#endregion


#region calc()


func test_calc_arithmetic_int() -> void:
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { padding: calc(16 + 8); }",
		"target")
	assert_eq(s.get("padding"), 24)


func test_calc_with_units_px() -> void:
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { width: calc(200px + 40px); }",
		"target")
	var w = s.get("width")
	assert_true(w is Dictionary)
	assert_eq(w.get("unit"), "px")
	assert_eq(w.get("value"), 240)


func test_calc_with_var() -> void:
	# calc() composes with var() — the var resolves first, then arithmetic.
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { --base: 16; padding: calc(var(--base) * 2); }",
		"target")
	assert_eq(s.get("padding"), 32)


#endregion
