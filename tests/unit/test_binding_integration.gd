extends GutTest

## End-to-end tests: instantiate GmlView, set state, verify DOM reacts.

const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")


func _build_view(html: String, css: String = "") -> GmlView:
	var dir := "res://tests/snapshots/.actual/binding_fixture"
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
	view.size = Vector2(400, 200)
	add_child_autofree(view)
	return view


func _find_first_label(node: Node) -> Label:
	if node is Label:
		return node
	for c in node.get_children():
		var l = _find_first_label(c)
		if l != null:
			return l
	return null


func test_text_interpolation_updates_dom_on_set() -> void:
	var view := _build_view('<span>Hello, {{ name }}!</span>')
	view.state.set("name", "Ada")
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label)
	assert_eq(label.text, "Hello, Ada!")

	view.state.set("name", "Bob")
	await get_tree().process_frame
	assert_eq(label.text, "Hello, Bob!")


func test_v_if_omits_subtree_when_falsy() -> void:
	# Empty initial state → v-if="show" reads null → falsy → element omitted.
	var view := _build_view('<div><span v-if="show">shown</span></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_null(label, "v-if=false should omit the span entirely")


func test_v_show_initially_hides_then_shows() -> void:
	var view := _build_view('<div><span v-show="visible">x</span></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label, "v-show keeps element in tree")
	assert_false(label.visible)
	view.state.set("visible", true)
	await get_tree().process_frame
	assert_true(label.visible)
