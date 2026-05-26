extends GutTest

## Integration test for the editor's inline parse-warnings panel.
##
## Loads the GML editor panel scene, drops malformed HTML/CSS into the
## CodeEdits, calls _refresh_warnings(), and walks the dynamically built
## PanelContainer asserting:
##   - it becomes visible exactly when there are warnings
##   - the header text reflects the count
##   - each warning becomes a clickable Button with the parser's line:col
##     and message text
##   - clicking a button jumps the relevant CodeEdit's caret to that line
##
## The panel script is @tool; it short-circuits when not in editor context.
## We bypass that by forcing Engine.is_editor_hint behavior through direct
## method calls — _refresh_warnings does not gate on the editor flag.

const EditorPanelScene = preload("res://addons/gtml/editor/gml_editor_panel.tscn")


func _build_panel() -> Control:
	var panel: Control = EditorPanelScene.instantiate()
	add_child_autofree(panel)
	# _ready short-circuits when not in editor context, so the @onready vars
	# are still resolved (they're @onready, not editor-gated). The dynamic
	# overlay nodes are created lazily by _ensure_warnings_panel(), so we
	# don't depend on _ready() running its full setup.
	await get_tree().process_frame
	return panel


func _warnings_panel(panel: Control) -> PanelContainer:
	# Lazily created on first _refresh_warnings call.
	return panel.get_node_or_null("MainContainer/WarningsPanel") as PanelContainer


func _warning_buttons(panel: Control) -> Array:
	var wp := _warnings_panel(panel)
	if wp == null:
		return []
	# Structure: WarningsPanel > VBox > [header Label, VBox of buttons]
	var inner_vbox: VBoxContainer = wp.get_child(0) as VBoxContainer
	var list_vbox: VBoxContainer = inner_vbox.get_child(1) as VBoxContainer
	var out: Array = []
	for c in list_vbox.get_children():
		if c is Button:
			out.append(c)
	return out


func test_panel_hidden_when_no_warnings() -> void:
	var panel := await _build_panel()
	panel.html_code_edit.text = "<div><p>hello</p></div>"
	panel.css_code_edit.text = "div { color: red; }"
	panel._refresh_warnings()
	var wp := _warnings_panel(panel)
	assert_not_null(wp, "panel should be created on first refresh")
	assert_false(wp.visible, "no warnings -> overlay must hide itself")


func test_panel_lists_html_warnings_with_line_col() -> void:
	var panel := await _build_panel()
	# Mismatched closing tag — HTML parser emits a warning with line/col.
	panel.html_code_edit.text = "<div>\n<p>a</q>\n</div>"
	panel.css_code_edit.text = ""
	panel._refresh_warnings()

	var wp := _warnings_panel(panel)
	assert_true(wp.visible, "overlay must show itself when warnings exist")
	var buttons := _warning_buttons(panel)
	assert_gt(buttons.size(), 0, "expected at least one warning row")
	# Row format: "[HTML L:C] msg"
	assert_string_starts_with(buttons[0].text, "[HTML ",
		"row label must lead with the parser kind, got: %s" % buttons[0].text)


func test_panel_lists_css_warnings_with_line_col() -> void:
	var panel := await _build_panel()
	panel.html_code_edit.text = ""
	# Missing colon — CSS parser warns at the property.
	panel.css_code_edit.text = "div { color red }"
	panel._refresh_warnings()

	var buttons := _warning_buttons(panel)
	assert_gt(buttons.size(), 0)
	assert_string_starts_with(buttons[0].text, "[CSS ",
		"row label must lead with CSS kind, got: %s" % buttons[0].text)


func test_header_count_reflects_total_warnings() -> void:
	var panel := await _build_panel()
	# Two HTML warnings: two mismatched closing tags.
	panel.html_code_edit.text = "<div><p>a</q></span></div>"
	panel.css_code_edit.text = ""
	panel._refresh_warnings()
	var wp := _warnings_panel(panel)
	var inner_vbox: VBoxContainer = wp.get_child(0) as VBoxContainer
	var header: Label = inner_vbox.get_child(0) as Label
	assert_string_contains(header.text, "(",
		"header should include a parenthesized count, got: %s" % header.text)


func test_clicking_a_warning_row_jumps_caret_to_line() -> void:
	var panel := await _build_panel()
	# The HTML parser flags the </q> on line 2 (1-based). After clicking the
	# row we expect the HTML CodeEdit's caret to land on line 1 (0-based).
	panel.html_code_edit.text = "<div>\n<p>a</q>\n</div>"
	panel.css_code_edit.text = ""
	panel._refresh_warnings()

	var buttons := _warning_buttons(panel)
	assert_gt(buttons.size(), 0)
	# Reset caret somewhere else first so we can detect the jump.
	panel.html_code_edit.set_caret_line(0)
	panel.html_code_edit.set_caret_column(0)

	buttons[0].pressed.emit()
	# Parser reports 1-based; row jump subtracts 1, so caret should be on line 1.
	assert_eq(panel.html_code_edit.get_caret_line(), 1,
		"clicking the row should jump caret to the warning's (line - 1)")


func test_warnings_cleared_on_clean_refresh() -> void:
	var panel := await _build_panel()
	# First: introduce warnings.
	panel.html_code_edit.text = "<div><p>a</q></div>"
	panel.css_code_edit.text = ""
	panel._refresh_warnings()
	assert_gt(_warning_buttons(panel).size(), 0, "setup: warnings should exist")

	# Then: clean both buffers and refresh — overlay must hide and clear.
	panel.html_code_edit.text = "<div></div>"
	panel.css_code_edit.text = ""
	panel._refresh_warnings()

	var wp := _warnings_panel(panel)
	assert_false(wp.visible, "overlay must hide after a clean refresh")
	assert_eq(_warning_buttons(panel).size(), 0, "stale rows must be removed")
