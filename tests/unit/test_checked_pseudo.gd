extends GutTest

## v0.4: :checked pseudo-class for checkboxes and radio inputs.
##
## The resolver routes :checked rules into a _checked state bucket
## (joining :hover/:focus/:active/:disabled). The input builders watch the
## toggled signal and apply the bucket's properties as a Godot "pressed"
## stylebox so the checked state is visually distinct.

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")
const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")


func _resolved_style(html: String, css: String, id: String) -> Dictionary:
	var dom = GmlHtmlParserScript.new().parse(html)
	var rules := GmlCssParserScript.new().parse(css)
	var styles: Dictionary = GmlStyleResolverScript.new().resolve(dom, rules)
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


func test_checked_resolves_to_state_bucket() -> void:
	var s := _resolved_style(
		'<input id="cb" type="checkbox">',
		'input { background-color: gray; } input:checked { background-color: red; }',
		"cb")
	assert_true(s.has("_checked"),
		"resolver must emit _checked bucket from :checked rule, got keys: %s" % str(s.keys()))
	assert_eq(s["_checked"].get("background-color"), Color.RED)


func test_unknown_pseudo_still_dropped_when_combined_with_checked() -> void:
	# :checked is now a valid state pseudo; a typo combined with it must
	# still drop the whole rule rather than silently routing into _checked.
	var s := _resolved_style(
		'<input id="cb" type="checkbox">',
		'input:checked:typoed { background-color: red; }',
		"cb")
	assert_false(s.has("_checked"), "rule with unknown pseudo must be dropped wholesale")


func test_checked_bucket_in_runtime_view() -> void:
	# End-to-end: a CheckBox with a :checked rule should apply a "pressed"
	# stylebox override after build, so Godot draws the rule's appearance
	# when button_pressed becomes true.
	var dir := "res://tests/snapshots/.actual/checked_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string('<input id="cb" type="checkbox" checked>')
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string('input:checked { background-color: rgb(155, 126, 255); }')
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(200, 100)
	add_child_autofree(view)
	await get_tree().process_frame
	await get_tree().process_frame

	var cb = view.get_element_by_id("cb")
	assert_not_null(cb)
	assert_true(cb is CheckBox)
	assert_true(cb.has_theme_stylebox_override("pressed"),
		"a CheckBox with a :checked rule should install a 'pressed' theme stylebox")
	var sb = cb.get_theme_stylebox("pressed")
	assert_true(sb is StyleBoxFlat)
	assert_eq((sb as StyleBoxFlat).bg_color, Color(155.0 / 255.0, 126.0 / 255.0, 255.0 / 255.0))
