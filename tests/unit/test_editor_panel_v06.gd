extends GutTest

## Integration tests for the v0.6 editor pane. Loads the panel scene,
## drives state directly, asserts the new wiring is alive without requiring
## the Godot editor host.

const EditorPanelScene = preload("res://addons/gtml/editor/gml_editor_panel.tscn")


func _panel() -> Control:
	var p: Control = EditorPanelScene.instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	return p


func test_panel_loads_with_v06_nodes() -> void:
	var p := await _panel()
	# Replace bar must exist (added in v0.6)
	assert_not_null(p.get_node_or_null("MainContainer/ReplaceBar"),
		"v0.6 Replace bar must be present in the scene")
	# Regex checkbox must exist
	assert_not_null(p.get_node_or_null("MainContainer/SearchBar/RegexCheck"),
		"v0.6 regex checkbox must be present")


func test_codeedit_autocomplete_enabled() -> void:
	var p := await _panel()
	assert_true(p.html_code_edit.code_completion_enabled)
	assert_true(p.css_code_edit.code_completion_enabled)


func test_codeedit_multiple_carets_enabled() -> void:
	var p := await _panel()
	# Godot 4.6 TextEdit property is `caret_multiple` (not the spec-doc name).
	assert_true(p.html_code_edit.caret_multiple)
	assert_true(p.css_code_edit.caret_multiple)


func test_color_gutter_present() -> void:
	var p := await _panel()
	# COLOR_GUTTER_IDX is 0 — both edits should report at least one gutter
	assert_gt(p.html_code_edit.get_gutter_count(), 0)
	assert_gt(p.css_code_edit.get_gutter_count(), 0)


func test_replace_all_through_panel() -> void:
	var p := await _panel()
	p.css_code_edit.text = ".a { color: red; } .a { color: red; }"
	p.search_input.text = "red"
	p.replace_input.text = "blue"
	p.tab_container.current_tab = p.tab_container.get_tab_idx_from_control(p.css_tab)
	p._on_replace_all_pressed()
	assert_eq(p.css_code_edit.text, ".a { color: blue; } .a { color: blue; }")
