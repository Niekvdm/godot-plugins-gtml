extends GutTest

## Tests for GmlClassRestyler.resolve_visual_props — recompute the
## visual-property subset for a node with an explicit class list.

const GmlNodeScript = preload("res://addons/gtml/src/html_parser/GmlNode.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")


func _rules(css: String) -> Array:
	return GmlCssParserScript.new().parse(css)


func _node(tag: String, classes: String) -> Variant:
	var n = GmlNodeScript.create_element(tag, {"class": classes})
	return n


func test_resolve_visual_props_pulls_color() -> void:
	var rules := _rules(".rare { color: #b59aff; }")
	var n = _node("span", "rare")
	var props: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["rare"]), rules)
	assert_true(props.has("color"))


func test_resolve_visual_props_pulls_background() -> void:
	var rules := _rules(".active { background-color: #ffcc00; }")
	var n = _node("div", "active")
	var props: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["active"]), rules)
	assert_true(props.has("background-color"))


func test_resolve_visual_props_excludes_layout_keys() -> void:
	var rules := _rules(".x { color: #fff; display: flex; width: 100px; padding: 8px; }")
	var n = _node("div", "x")
	var props: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["x"]), rules)
	assert_true(props.has("color"), "color is a visual prop")
	assert_false(props.has("display"), "display is layout — excluded")
	assert_false(props.has("width"), "width is layout — excluded")
	assert_false(props.has("padding"), "padding is layout — excluded")


func test_resolve_visual_props_compound_selector_needs_both() -> void:
	var rules := _rules(".item.rare { color: #b59aff; }")
	var n = _node("li", "item")
	# Only "item" active → compound .item.rare does NOT match.
	var props_one: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["item"]), rules)
	assert_false(props_one.has("color"), "compound needs both classes")
	# Both active → matches.
	var props_both: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["item", "rare"]), rules)
	assert_true(props_both.has("color"))


func test_resolve_visual_props_restores_node_class_attr() -> void:
	# The restyler temporarily mutates the node's class attr; it MUST
	# restore the original afterwards.
	var rules := _rules(".rare { color: #fff; }")
	var n = _node("span", "base")
	GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["base", "rare"]), rules)
	assert_eq(n.get_attr("class", ""), "base", "original class attr must be restored")
