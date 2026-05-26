extends GutTest

## v0.4: form value collection on submit + @keydown event attribute.
##
## GmlView.get_form_data() walks the registered inputs and returns
## {id: value} for text inputs, checkboxes, radios (only the selected
## one per group), sliders, and selects. Submit buttons trigger the
## form_submitted signal with that dict.
##
## @keydown="handler" on an input fires the key_pressed signal with the
## handler name + the InputEventKey.

const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")


func _build_view(html: String) -> GmlView:
	var dir := "res://tests/snapshots/.actual/forms_keys_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string(html)
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string("")
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 300)
	add_child_autofree(view)
	return view


#region Form value collection


func test_get_form_data_collects_text_inputs() -> void:
	var view := _build_view(
		'<form><input id="name" type="text" value="Ada"><input id="email" type="text" value="ada@example.com"></form>'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(view.has_method("get_form_data"), "GmlView should expose get_form_data()")
	var data: Dictionary = view.get_form_data()
	assert_eq(data.get("name"), "Ada")
	assert_eq(data.get("email"), "ada@example.com")


func test_get_form_data_collects_checkbox_state() -> void:
	var view := _build_view(
		'<form><input id="opt_in" type="checkbox" checked><input id="opt_out" type="checkbox"></form>'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var data: Dictionary = view.get_form_data()
	assert_eq(data.get("opt_in"), true)
	assert_eq(data.get("opt_out"), false)


func test_get_form_data_collects_selected_radio_only() -> void:
	var view := _build_view(
		'<form>'
		+ '<input id="r1" type="radio" name="size" value="s">'
		+ '<input id="r2" type="radio" name="size" value="m" checked>'
		+ '<input id="r3" type="radio" name="size" value="l">'
		+ '</form>'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var data: Dictionary = view.get_form_data()
	# Only the selected radio's value appears — keyed by the group name.
	assert_eq(data.get("size"), "m")
	# Unselected radios are not in the dict.
	assert_false(data.has("r1"))
	assert_false(data.has("r3"))


func test_submit_button_emits_form_submitted_with_data() -> void:
	var view := _build_view(
		'<form>'
		+ '<input id="title" type="text" value="hello">'
		+ '<input type="submit" value="Save">'
		+ '</form>'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var emitted := []
	view.form_submitted.connect(func(data: Dictionary):
		emitted.append(data)
	)

	# Find the submit button and "click" it.
	var btn: Button = _find_button(view, "Save")
	assert_not_null(btn)
	btn.pressed.emit()

	assert_eq(emitted.size(), 1, "form_submitted should fire exactly once")
	assert_eq(emitted[0].get("title"), "hello")


#endregion


#region @keydown


func test_keydown_attribute_emits_key_pressed() -> void:
	var view := _build_view(
		'<input id="search" type="text" @keydown="on_search_key">'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(view.has_signal("key_pressed"), "GmlView should expose key_pressed signal")

	var emitted := []
	view.key_pressed.connect(func(handler: String, key: InputEvent):
		emitted.append({"handler": handler, "keycode": key.keycode if key is InputEventKey else 0})
	)

	var input = view.get_element_by_id("search")
	assert_not_null(input)
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = true
	input.gui_input.emit(ev)

	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0]["handler"], "on_search_key")
	assert_eq(emitted[0]["keycode"], KEY_A)


#endregion


func _find_button(node: Node, label: String):
	if node is Button and (node as Button).text == label:
		return node
	for child in node.get_children():
		var r = _find_button(child, label)
		if r != null:
			return r
	return null
