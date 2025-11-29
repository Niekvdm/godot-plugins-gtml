@tool
extends Control
class_name GmlView

## GmlView - Godot Markup Language View
## Builds Godot UI from HTML files with external CSS styling.
## Supports live preview in editor and @click handlers for buttons.

# Preload dependencies (use preload for scripts without class_name inner classes)
const GmlHtmlParserScript = preload("res://addons/gml/src/html_parser/GmlHtmlParser.gd")
const GmlNodeScript = preload("res://addons/gml/src/html_parser/GmlNode.gd")
const GmlRendererScript = preload("res://addons/gml/src/html_renderer/GmlRenderer.gd")
# Note: GmlCssParser and GmlStyleResolver are accessed via their class_name directly
# because they have inner classes that cause issues with preload().new()

#region Exports

@export_file("*.html") var html_path: String = "":
	set(value):
		html_path = value
		_queue_rebuild()

@export_file("*.css") var css_path: String = "":
	set(value):
		css_path = value
		_queue_rebuild()

@export var auto_reload_in_editor: bool = true

@export_group("Debug")
## When enabled, generated nodes appear in the Scene dock for inspection.
@export var show_nodes_in_editor: bool = false:
	set(value):
		show_nodes_in_editor = value
		if Engine.is_editor_hint():
			_queue_rebuild()

@export_group("Tag Defaults")
@export var h1_font_size: int = 32
@export var h2_font_size: int = 24
@export var h3_font_size: int = 20
@export var p_font_size: int = 16
@export var default_font_color: Color = Color.WHITE
@export var default_gap: int = 8
@export var default_margin: int = 0
@export var default_padding: int = 0

@export_group("Fonts")
## Dictionary mapping font family names to Font resources.
## Example: {"Orbitron": preload("res://assets/Fonts/Orbitron-Regular.ttf")}
@export var fonts: Dictionary = {}

#endregion


#region Signals

## Emitted when a button with @click attribute is pressed.
## The method_name parameter contains the value of the @click attribute.
signal button_clicked(method_name: String)

## Emitted when an anchor/link is clicked.
## Contains the href value or method_name from @click.
signal link_clicked(href: String)

## Emitted when an input value changes.
## Contains the input id/name and new value.
signal input_changed(input_id: String, value: String)

## Emitted when a select option changes.
## Contains the select id/name and selected value.
signal selection_changed(select_id: String, value: String)

## Emitted when a form is submitted (button type="submit" clicked).
## Contains a dictionary of all input values keyed by id/name.
signal form_submitted(form_data: Dictionary)

#endregion


#region Internal State

var _html_last_modified: int = 0
var _css_last_modified: int = 0
var _rebuild_queued: bool = false
## Dictionary mapping element IDs to their inner Control nodes (the actual content control)
var _elements_by_id: Dictionary = {}
## Dictionary mapping element IDs to their wrapper Control nodes (for visibility control)
var _wrappers_by_id: Dictionary = {}

#endregion


func _ready() -> void:
	# Always rebuild on ready - clear any editor-created children and rebuild fresh
	# This ensures runtime behavior is consistent
	if not Engine.is_editor_hint():
		# At runtime, wait a frame for size to be set properly before building
		await get_tree().process_frame
	_rebuild()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and auto_reload_in_editor:
		_check_files_changed()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	_rebuild_queued = false
	_clear_children()

	if html_path.is_empty():
		_show_placeholder("No HTML file assigned")
		if not Engine.is_editor_hint():
			print("GmlView: No HTML file assigned")
		return

	var html_content := _load_file(html_path)
	if html_content.is_empty():
		_show_placeholder("Failed to load HTML file")
		push_error("GmlView: Failed to load HTML content from %s" % html_path)
		return

	if not Engine.is_editor_hint():
		print("GmlView: Loaded HTML (%d chars) from %s" % [html_content.length(), html_path])

	var css_content := ""
	if not css_path.is_empty():
		css_content = _load_file(css_path)
		if not Engine.is_editor_hint() and not css_content.is_empty():
			print("GmlView: Loaded CSS (%d chars) from %s" % [css_content.length(), css_path])

	# Parse HTML
	var parser = GmlHtmlParserScript.new()
	var dom_root = parser.parse(html_content)
	if dom_root == null:
		_show_placeholder("Failed to parse HTML")
		push_error("GmlView: Failed to parse HTML from %s" % html_path)
		return

	# Parse CSS
	var styles: Dictionary = {}
	if not css_content.is_empty():
		var css_parser = GmlCssParser.new()
		var css_rules = css_parser.parse(css_content)
		var style_resolver = GmlStyleResolver.new()
		styles = style_resolver.resolve(dom_root, css_rules)

	# Build UI
	var renderer = GmlRendererScript.new()
	var ui_root = renderer.build(dom_root, styles, self)
	if ui_root != null:
		# Check if root or its single child has percentage dimensions that need centering
		# The _root virtual node creates a wrapper, so check its child too
		var width_percent = ui_root.get_meta("width_percent", -1.0)
		var height_percent = ui_root.get_meta("height_percent", -1.0)
		var target_control = ui_root

		# If root has no percentage but has exactly one child, check that child
		if width_percent < 0 and height_percent < 0 and ui_root.get_child_count() == 1:
			var first_child = ui_root.get_child(0)
			if first_child is Control:
				var child_width_pct = first_child.get_meta("width_percent", -1.0)
				var child_height_pct = first_child.get_meta("height_percent", -1.0)
				if (child_width_pct > 0 and child_width_pct < 1.0) or (child_height_pct > 0 and child_height_pct < 1.0):
					# Use the child as the target and remove it from the root
					width_percent = child_width_pct
					height_percent = child_height_pct
					target_control = first_child
					ui_root.remove_child(first_child)
					# The empty root wrapper is no longer needed
					ui_root.queue_free()

		var needs_centering = (width_percent > 0 and width_percent < 1.0) or (height_percent > 0 and height_percent < 1.0)

		if needs_centering:
			# Create a centering wrapper that fills the GmlView
			var centering_wrapper := CenterContainer.new()
			centering_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
			centering_wrapper.set_offsets_preset(Control.PRESET_FULL_RECT)
			centering_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			centering_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL

			add_child(centering_wrapper)
			centering_wrapper.add_child(target_control)
			_set_owner_recursive(centering_wrapper)

			# Set up percentage sizing that updates with GmlView resize
			_setup_root_percent_sizing(target_control, width_percent, height_percent)
		else:
			add_child(target_control)
			_set_owner_recursive(target_control)
			# Make the root fill the GmlView
			if target_control is Control:
				# Use anchors and offsets to properly fill parent
				target_control.set_anchors_preset(Control.PRESET_FULL_RECT)
				target_control.set_offsets_preset(Control.PRESET_FULL_RECT)
				target_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				target_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
				# For ScrollContainer, set the size using set_deferred to avoid anchor conflict warning
				if target_control is ScrollContainer:
					target_control.set_deferred("size", size)
	else:
		push_error("GmlView: Renderer returned null ui_root")


## Set up percentage-based sizing for root control.
## This connects to GmlView resize and updates the control's size.
func _setup_root_percent_sizing(control: Control, width_pct: float, height_pct: float) -> void:
	# Connect to our own resize signal
	if not resized.is_connected(_on_self_resized_for_percent.bind(control, width_pct, height_pct)):
		resized.connect(_on_self_resized_for_percent.bind(control, width_pct, height_pct))

	# Apply initial size
	_update_root_percent_size(control, width_pct, height_pct)


## Called when GmlView resizes - update the root control's percentage-based size.
func _on_self_resized_for_percent(control: Control, width_pct: float, height_pct: float) -> void:
	if is_instance_valid(control):
		_update_root_percent_size(control, width_pct, height_pct)


## Update a root control's size based on percentage of GmlView size.
## Respects max-width/max-height constraints stored as metadata.
func _update_root_percent_size(control: Control, width_pct: float, height_pct: float) -> void:
	if not is_instance_valid(control):
		return

	var new_size := control.custom_minimum_size

	if width_pct > 0 and width_pct < 1.0:
		new_size.x = size.x * width_pct
	if height_pct > 0 and height_pct < 1.0:
		new_size.y = size.y * height_pct

	# Respect max-width constraint (stored as metadata)
	var max_width = control.get_meta("max_width", -1.0)
	var max_width_pct = control.get_meta("max_width_percent", -1.0)
	if max_width_pct > 0:
		var pct_max = size.x * max_width_pct
		if max_width > 0:
			max_width = minf(max_width, pct_max)
		else:
			max_width = pct_max
	if max_width > 0 and new_size.x > max_width:
		new_size.x = max_width

	# Respect max-height constraint (stored as metadata)
	var max_height = control.get_meta("max_height", -1.0)
	var max_height_pct = control.get_meta("max_height_percent", -1.0)
	if max_height_pct > 0:
		var pct_max = size.y * max_height_pct
		if max_height > 0:
			max_height = minf(max_height, pct_max)
		else:
			max_height = pct_max
	if max_height > 0 and new_size.y > max_height:
		new_size.y = max_height

	control.custom_minimum_size = new_size
	control.size = new_size


func _clear_children() -> void:
	_elements_by_id.clear()
	_wrappers_by_id.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _show_placeholder(message: String) -> void:
	if not Engine.is_editor_hint():
		return

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)
	_set_owner_recursive(label)


## Set owner on a node and all its children recursively.
## This makes dynamically created nodes visible in the editor's Scene dock.
func _set_owner_recursive(node: Node) -> void:
	if not Engine.is_editor_hint() or not show_nodes_in_editor:
		return

	var scene_root = get_tree().edited_scene_root if get_tree() else null
	if scene_root == null:
		return

	node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child)


func _load_file(path: String) -> String:
	# Try to open the file directly - FileAccess.open works for res:// paths
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("GmlView: Could not open file: %s (error code: %d)" % [path, error])
		return ""

	var content = file.get_as_text()
	file.close()
	return content


func _check_files_changed() -> void:
	var needs_rebuild := false

	if not html_path.is_empty() and FileAccess.file_exists(html_path):
		var html_mod_time := FileAccess.get_modified_time(html_path)
		if html_mod_time != _html_last_modified:
			_html_last_modified = html_mod_time
			needs_rebuild = true

	if not css_path.is_empty() and FileAccess.file_exists(css_path):
		var css_mod_time := FileAccess.get_modified_time(css_path)
		if css_mod_time != _css_last_modified:
			_css_last_modified = css_mod_time
			needs_rebuild = true

	if needs_rebuild:
		_queue_rebuild()


#region Public API

## Get the default configuration as a dictionary.
## Used by GmlRenderer to apply tag defaults.
func get_tag_defaults() -> Dictionary:
	return {
		"h1_font_size": h1_font_size,
		"h2_font_size": h2_font_size,
		"h3_font_size": h3_font_size,
		"p_font_size": p_font_size,
		"default_font_color": default_font_color,
		"default_gap": default_gap,
		"default_margin": default_margin,
		"default_padding": default_padding,
		"fonts": fonts
	}


## Get an element by its ID attribute.
## Returns the inner Control node (e.g., Label, Button), or null if not found.
## Use this to access the content control's properties like text, disabled, etc.
func get_element_by_id(element_id: String) -> Control:
	return _elements_by_id.get(element_id, null)


## Get the wrapper control for an element by its ID.
## Returns the outermost wrapper (MarginContainer, PanelContainer, etc.) that contains the element.
## Use this to control visibility with display:none style.
## If the element has no wrapper, returns the inner control itself.
func get_wrapper_by_id(element_id: String) -> Control:
	return _wrappers_by_id.get(element_id, _elements_by_id.get(element_id, null))


## Register an element with an ID for later retrieval.
## Called by GmlRenderer when building elements with id attributes.
## inner_control: The actual content control (e.g., Label, Button)
## wrapper_control: The outermost wrapper (e.g., MarginContainer), or null if same as inner
func register_element(element_id: String, inner_control: Control, wrapper_control: Control = null) -> void:
	_elements_by_id[element_id] = inner_control
	if wrapper_control != null and wrapper_control != inner_control:
		_wrappers_by_id[element_id] = wrapper_control
	else:
		_wrappers_by_id[element_id] = inner_control


## Clear the element registry (called before rebuild).
func clear_element_registry() -> void:
	_elements_by_id.clear()
	_wrappers_by_id.clear()

#endregion
