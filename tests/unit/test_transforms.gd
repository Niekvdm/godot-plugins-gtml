extends GutTest

## v0.4: CSS transform property — translate / scale / rotate.
##
## Maps to Control.position / scale / rotation. Multiple transforms compose
## left-to-right. pivot_offset defaults to size/2 so scale/rotate behave
## like CSS's default transform-origin: 50% 50%.

const GtmlCssParserScript = preload("res://addons/gtml/src/css/GtmlCssParser.gd")
const GtmlViewScript = preload("res://addons/gtml/src/GtmlView.gd")


func _parse(css: String) -> Array:
	return GtmlCssParserScript.new().parse(css)


#region Transform value parsing


func test_translate_parses_to_vector() -> void:
	var rules := _parse("div { transform: translate(10px, 20px); }")
	var t = rules[0].properties.get("transform")
	assert_true(t is Dictionary)
	assert_eq(t.get("translate"), Vector2(10, 20))


func test_translate_single_arg_uses_zero_y() -> void:
	var rules := _parse("div { transform: translate(15px); }")
	var t = rules[0].properties.get("transform")
	assert_eq(t.get("translate"), Vector2(15, 0))


func test_scale_uniform() -> void:
	var rules := _parse("div { transform: scale(1.05); }")
	var t = rules[0].properties.get("transform")
	assert_eq(t.get("scale"), Vector2(1.05, 1.05))


func test_scale_x_y() -> void:
	var rules := _parse("div { transform: scale(1.1, 0.9); }")
	var t = rules[0].properties.get("transform")
	assert_eq(t.get("scale"), Vector2(1.1, 0.9))


func test_rotate_deg_converts_to_radians() -> void:
	var rules := _parse("div { transform: rotate(45deg); }")
	var t = rules[0].properties.get("transform")
	# 45 degrees == PI / 4 radians
	assert_almost_eq(t.get("rotate"), PI / 4.0, 0.001)


func test_multiple_transforms_combine() -> void:
	var rules := _parse("div { transform: translate(10px, 0) scale(1.05) rotate(10deg); }")
	var t = rules[0].properties.get("transform")
	assert_eq(t.get("translate"), Vector2(10, 0))
	assert_eq(t.get("scale"), Vector2(1.05, 1.05))
	assert_almost_eq(t.get("rotate"), PI / 18.0, 0.001)


#endregion


#region Runtime application


func _build_view_with(html: String, css: String) -> GtmlView:
	var dir := "res://tests/snapshots/.actual/transform_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string(html)
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string(css)
	fc.close()

	var view: GtmlView = GtmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 300)
	add_child_autofree(view)
	return view


func _find_by_id(node, id: String):
	if node is Control and (node as Control).name == id:
		return node
	for child in node.get_children():
		var r = _find_by_id(child, id)
		if r != null:
			return r
	return null


func test_transform_scale_applied_to_control() -> void:
	var view := _build_view_with(
		'<div id="box" style="">box</div>',
		'#box { width: 100px; height: 100px; transform: scale(1.5); }'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var box: Control = view.get_element_by_id("box")
	assert_not_null(box)
	assert_eq(box.scale, Vector2(1.5, 1.5))


func test_transform_rotate_applied_to_control() -> void:
	var view := _build_view_with(
		'<div id="box">box</div>',
		'#box { width: 100px; height: 100px; transform: rotate(90deg); }'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var box: Control = view.get_element_by_id("box")
	assert_not_null(box)
	assert_almost_eq(box.rotation, PI / 2.0, 0.001)
#endregion
