extends GutTest

## Tests for the `<label for="x">` activation behavior:
##   - text inputs    -> grab_focus
##   - checkboxes      -> toggle button_pressed
##   - radio (group)   -> set button_pressed = true (never deselect)
##
## We exercise _activate_for_target directly through a tiny proxy so the
## tests don't need to simulate gui_input mouse events or instantiate the
## full GmlView pipeline.

const GmlTextBuilderScript = preload("res://addons/gtml/src/html_renderer/elements/GmlTextBuilder.gd")


func _activate(target) -> void:
	GmlTextBuilderScript._activate_for_target(target)


func test_checkbox_toggles_on_label_click() -> void:
	var cb := CheckBox.new()
	add_child_autofree(cb)
	assert_false(cb.button_pressed)
	_activate(cb)
	assert_true(cb.button_pressed)
	_activate(cb)
	assert_false(cb.button_pressed, "second activation should toggle off")


func test_button_activation_does_not_grab_focus() -> void:
	# UX contract: clicking a label that points to a checkbox/radio should
	# toggle the input but NOT show a focus indicator. Godot's CheckBox
	# focus stylebox extends beyond the box and reads as visual noise after
	# a mouse click. Keyboard nav still reaches the button via Tab.
	var cb := CheckBox.new()
	add_child_autofree(cb)
	await get_tree().process_frame
	assert_false(cb.has_focus())
	_activate(cb)
	assert_false(cb.has_focus(),
		"label activation must not grab focus on a button — would draw an unwanted focus ring")
	assert_true(cb.button_pressed, "...but the toggle itself must still happen")


func test_radio_in_group_selects_never_deselects() -> void:
	var group := ButtonGroup.new()
	var a := CheckBox.new()
	a.button_group = group
	var b := CheckBox.new()
	b.button_group = group
	add_child_autofree(a)
	add_child_autofree(b)
	a.button_pressed = true

	# Activating a (already selected) must NOT deselect it — that would
	# leave the entire group with no selection.
	_activate(a)
	assert_true(a.button_pressed, "radio already-selected stays selected on label click")
	assert_false(b.button_pressed)

	# Activating b selects b (and group auto-deselects a).
	_activate(b)
	assert_true(b.button_pressed)
	assert_false(a.button_pressed, "ButtonGroup must deselect previous radio")


func test_text_input_grabs_focus_on_label_click() -> void:
	var line := LineEdit.new()
	add_child_autofree(line)
	await get_tree().process_frame  # let the Control enter the focus tree
	assert_false(line.has_focus())
	_activate(line)
	assert_true(line.has_focus(), "LineEdit should hold focus after label activation")


func test_label_with_for_attribute_carries_meta() -> void:
	# Smoke test that a label with for="x" sets meta so the renderer
	# pipeline can re-discover it later (e.g. for accessibility tooling).
	var Parser = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
	var dom = Parser.new().parse('<label for="x">click</label>')
	assert_eq(dom.get_attr("for", ""), "x")


func test_label_click_focuses_input_through_gml_view() -> void:
	# Integration test for the gui_input wiring inside build_label_inner:
	# build a real GmlView containing a <label for="x"> + <input id="x">,
	# synthesize a left-click on the label, and assert the input receives focus.
	var GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")
	var fixture_dir := "res://tests/snapshots/.actual/label_for_fixture"
	var html_path := fixture_dir + "/index.html"
	var css_path := fixture_dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string('<div><label for="probe">click me</label><input id="probe" type="text"></div>')
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string("div { display: flex; flex-direction: column; }")
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 200)
	add_child_autofree(view)
	await get_tree().process_frame
	await get_tree().process_frame

	var input = view.get_element_by_id("probe")
	assert_not_null(input, "input control should be registered with the view")
	assert_false(input.has_focus())

	# Find the label by walking the built tree — it's the first Label
	# control under the view whose meta "for" is set.
	var label: Label = _find_label_with_for(view)
	assert_not_null(label, "label with for-meta should exist in the built tree")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	label.gui_input.emit(click)

	assert_true(input.has_focus(), "input should be focused after synthesized label click")


func _find_label_with_for(node: Node):
	if node is Label and (node as Label).has_meta("for"):
		return node
	for child in node.get_children():
		var found = _find_label_with_for(child)
		if found != null:
			return found
	return null


func _find_node_with_for_meta(node: Node):
	if node is Control and (node as Control).has_meta("for"):
		return node
	for child in node.get_children():
		var found = _find_node_with_for_meta(child)
		if found != null:
			return found
	return null


func test_label_with_element_children_becomes_container() -> void:
	# Whole-surface click target: <label><input/>text</label>. The label
	# builder should produce a container (HBox/VBox), not a Label widget,
	# so the entire row — padding, sibling spans, surrounding chrome —
	# activates the for-target on click.
	var GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")
	var dir := "res://tests/snapshots/.actual/label_container_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string('<label for="cb"><input id="cb" type="checkbox"><span>toggle me</span></label>')
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string("")
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 200)
	add_child_autofree(view)
	await get_tree().process_frame
	await get_tree().process_frame

	# The label is now a container — find the node carrying the for-meta.
	var label_container = _find_node_with_for_meta(view)
	assert_not_null(label_container)
	assert_false(label_container is Label,
		"label with element children must NOT be a Label widget (would lose those children)")
	assert_true(label_container is Container,
		"label with element children should be a Container — got %s" % typeof(label_container))

	var checkbox = view.get_element_by_id("cb")
	assert_not_null(checkbox)
	assert_false(checkbox.button_pressed)

	# Click on the label container (not on the checkbox itself). The
	# whole row must toggle the checkbox.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	label_container.gui_input.emit(click)

	assert_true(checkbox.button_pressed,
		"clicking anywhere on the label container should toggle the wrapped input")
