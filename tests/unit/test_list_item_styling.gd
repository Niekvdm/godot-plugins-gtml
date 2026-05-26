extends GutTest

## Regression test for the v0.3.1 fix where GmlListBuilder.build_list used to
## build <li> controls inline, bypassing the central dispatcher and silently
## dropping per-item CSS. We assert that an <li> with a background-color rule
## actually carries that color through to a PanelContainer + StyleBoxFlat in
## the built tree.

const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")


func _build_view(html: String, css: String) -> GmlView:
	var dir := "res://tests/snapshots/.actual/list_item_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string(html)
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string(css)
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 300)
	add_child_autofree(view)
	return view


## Walk a subtree and return the first PanelContainer whose "panel" stylebox
## has a non-default bg color matching the requested color, or null.
func _find_panel_with_bg(node: Node, color: Color):
	if node is PanelContainer:
		var sb = (node as PanelContainer).get_theme_stylebox("panel")
		if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.is_equal_approx(color):
			return node
	for child in node.get_children():
		var found = _find_panel_with_bg(child, color)
		if found != null:
			return found
	return null


func test_li_background_color_lands_on_a_panelcontainer() -> void:
	# Without the v0.3.1 dispatch refactor, this test would fail because the
	# <li>'s background-color rule never reached the wrapping pipeline.
	var view := _build_view(
		'<ul><li class="row">item one</li><li class="row">item two</li></ul>',
		'.row { background-color: rgb(255, 32, 64); padding: 12px; list-style-type: none; }'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var hit = _find_panel_with_bg(view, Color(255.0 / 255.0, 32.0 / 255.0, 64.0 / 255.0))
	assert_not_null(hit, "li with background-color must produce a PanelContainer with that bg color")


func test_li_hover_state_resolves_to_state_bucket() -> void:
	# Even simpler resolver-level check: the <li>'s style includes a _hover
	# bucket after resolution. Pins the fact that the resolver sees the rule
	# (independent of whether transitions fire visually).
	const ParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
	const CssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
	const ResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")

	var dom = ParserScript.new().parse('<ul><li id="t" class="row">x</li></ul>')
	var rules = CssParserScript.new().parse('.row { background-color: blue; transition: background-color 200ms; } .row:hover { background-color: red; }')
	var styles: Dictionary = ResolverScript.new().resolve(dom, rules)

	# Find the li node
	var li = null
	for c in dom.children:
		if c.tag == "li":
			li = c
			break
	assert_not_null(li)

	var s: Dictionary = styles.get(li, {})
	assert_eq(s.get("background-color"), Color.BLUE)
	assert_true(s.has("_hover"), "resolver must emit _hover bucket for .row:hover")
	assert_eq(s["_hover"].get("background-color"), Color.RED)
