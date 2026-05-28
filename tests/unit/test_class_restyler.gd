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


# ─── restyle() apply path (Task 3) ─────────────────────────

func _panel_with_box() -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.1)
	p.add_theme_stylebox_override("panel", box)
	add_child_autofree(p)
	return p


func test_restyle_applies_background_color_to_panel() -> void:
	var rules := _rules(".active { background-color: #ffcc00; }")
	var n = _node("div", "card")
	var p := _panel_with_box()
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["card"]), rules)
	GmlClassRestyler.restyle(p, n, [n], PackedStringArray(["card", "active"]), rules, base, null)
	var box: StyleBoxFlat = p.get_theme_stylebox("panel")
	assert_almost_eq(box.bg_color.r, 1.0, 0.02)
	assert_almost_eq(box.bg_color.g, 0.8, 0.05)


func test_restyle_applies_font_color_to_label() -> void:
	var rules := _rules(".rare { color: #b59aff; }")
	var n = _node("span", "name")
	var label := Label.new()
	add_child_autofree(label)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["name"]), rules)
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["name", "rare"]), rules, base, null)
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 0.71, 0.05)
	assert_almost_eq(c.b, 1.0, 0.05)


func test_restyle_applies_opacity() -> void:
	var rules := _rules(".dim { opacity: 0.5; }")
	var n = _node("div", "box")
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["box"]), rules)
	GmlClassRestyler.restyle(ctrl, n, [n], PackedStringArray(["box", "dim"]), rules, base, null)
	assert_almost_eq(ctrl.modulate.a, 0.5, 0.02)


func test_restyle_removing_class_reverts_to_base_snapshot() -> void:
	var rules := _rules(".base { color: #ffffff; } .rare { color: #b59aff; }")
	var n = _node("span", "base")
	var label := Label.new()
	add_child_autofree(label)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["base"]), rules)
	# Add rare → purple.
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["base", "rare"]), rules, base, null)
	# Remove rare → revert to base white.
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["base"]), rules, base, null)
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 1.0, 0.02)
	assert_almost_eq(c.b, 1.0, 0.02)


func test_restyle_revert_clears_override_when_no_static_rule() -> void:
	# No static class rule supplies `color`, so base_snapshot lacks it.
	# Adding `.rare` applies purple; removing it must CLEAR the override
	# (revert to theme default), not leave the element stuck purple.
	var rules := _rules(".rare { color: #b59aff; }")
	var n = _node("span", "plain")   # 'plain' has no CSS rule
	var label := Label.new()
	add_child_autofree(label)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["plain"]), rules)
	assert_false(base.has("color"), "no static rule → base lacks color")
	# Add rare → purple override applied.
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["plain", "rare"]), rules, base, null)
	assert_true(label.has_theme_color_override("font_color"), "rare applies an override")
	# Remove rare → override must be cleared.
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["plain"]), rules, base, null)
	assert_false(label.has_theme_color_override("font_color"), "revert must clear the stale override")


func test_restyle_layout_prop_in_dynamic_class_warns() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var rules := _rules(".grow { display: flex; color: #fff; }")
	var n = _node("div", "box")
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["box"]), rules)
	GmlClassRestyler.restyle(ctrl, n, [n], PackedStringArray(["box", "grow"]), rules, base, null)
	var layout_warns: Array = captured.filter(func(m): return "layout prop" in m)
	assert_gt(layout_warns.size(), 0, "layout prop in dynamic class must warn")
	GmlBindingApplier._on_warning = Callable()
