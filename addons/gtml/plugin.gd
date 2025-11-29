@tool
extends EditorPlugin

## GML Editor Plugin - Registers GmlView custom type and provides main screen editor
## for editing HTML/CSS files attached to GmlView nodes.

const GmlEditorPanel = preload("res://addons/gml/editor/gml_editor_panel.tscn")

var _editor_panel: Control = null
var _current_gml_view: WeakRef = weakref(null)
var _editor_selection: EditorSelection = null


func _enter_tree() -> void:
	# Register GmlView as a custom type
	add_custom_type(
		"GmlView",
		"Control",
		preload("res://addons/gml/src/GmlView.gd"),
		preload("res://addons/gml/icons/gml_view.svg")
	)

	# Create and add main editor panel
	_editor_panel = GmlEditorPanel.instantiate()
	EditorInterface.get_editor_main_screen().add_child(_editor_panel)
	_make_visible(false)

	# Connect to selection changes to track selected GmlView
	_editor_selection = EditorInterface.get_selection()
	_editor_selection.selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	remove_custom_type("GmlView")

	# Disconnect selection signal
	if _editor_selection and _editor_selection.selection_changed.is_connected(_on_selection_changed):
		_editor_selection.selection_changed.disconnect(_on_selection_changed)

	# Clean up editor panel
	if is_instance_valid(_editor_panel):
		_editor_panel.queue_free()
		_editor_panel = null


#region Main Screen Plugin Methods

func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "GML"


func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/gml/icons/gml_view.svg")


func _make_visible(next_visible: bool) -> void:
	if is_instance_valid(_editor_panel):
		# Save state when hiding
		if not next_visible and _editor_panel.visible:
			_editor_panel.save_state()

		_editor_panel.visible = next_visible

		# When becoming visible, update with current selection
		if next_visible:
			_update_panel_with_selection()

#endregion


#region Selection Handling

func _on_selection_changed() -> void:
	# Only update panel if it's currently visible
	if is_instance_valid(_editor_panel) and _editor_panel.visible:
		_update_panel_with_selection()


func _update_panel_with_selection() -> void:
	if not is_instance_valid(_editor_panel):
		return

	var selected_nodes = _editor_selection.get_selected_nodes()
	var gml_view: GmlView = null

	# Find first selected GmlView
	for node in selected_nodes:
		if node is GmlView:
			gml_view = node
			break

	if gml_view:
		_current_gml_view = weakref(gml_view)
		_editor_panel.edit_gml_view(gml_view)
	else:
		_current_gml_view = weakref(null)
		_editor_panel.clear_editor()

#endregion
