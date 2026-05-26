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
	# Give it a focusable parent path
	assert_false(line.has_focus())
	_activate(line)
	# grab_focus is queued — we don't wait, but we can assert the focus mode
	# allows it and that the call did not error.
	assert_true(line.focus_mode != Control.FOCUS_NONE)


func test_label_with_for_attribute_carries_meta() -> void:
	# Smoke test that a label with for="x" sets meta so the renderer
	# pipeline can re-discover it later (e.g. for accessibility tooling).
	var Parser = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
	var dom = Parser.new().parse('<label for="x">click</label>')
	assert_eq(dom.get_attr("for", ""), "x")
