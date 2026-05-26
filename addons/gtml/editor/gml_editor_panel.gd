@tool
extends Control

## GML Editor Panel - Main screen editor for HTML/CSS files attached to GmlView nodes.
## Displays editable CodeEdit tabs for HTML and CSS content with save/reload functionality.

const HtmlSyntaxHighlighter = preload("res://addons/gtml/editor/html_syntax_highlighter.gd")
const CssSyntaxHighlighter = preload("res://addons/gtml/editor/css_syntax_highlighter.gd")
const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlSearchEngineScript = preload("res://addons/gtml/src/editor/GmlSearchEngine.gd")
const GmlJumpResolverScript = preload("res://addons/gtml/src/editor/GmlJumpResolver.gd")
const GmlEditorContextScript = preload("res://addons/gtml/src/editor/GmlEditorContext.gd")

#region Node References

@onready var main_container: VBoxContainer = $MainContainer
@onready var toolbar: HBoxContainer = $MainContainer/Toolbar
@onready var file_label: Label = $MainContainer/Toolbar/FileLabel
@onready var save_button: Button = $MainContainer/Toolbar/SaveButton
@onready var reload_button: Button = $MainContainer/Toolbar/ReloadButton
@onready var tab_container: TabContainer = $MainContainer/TabContainer
@onready var html_tab: MarginContainer = $MainContainer/TabContainer/HTML
@onready var html_code_edit: CodeEdit = $MainContainer/TabContainer/HTML/HtmlCodeEdit
@onready var css_tab: MarginContainer = $MainContainer/TabContainer/CSS
@onready var css_code_edit: CodeEdit = $MainContainer/TabContainer/CSS/CssCodeEdit
@onready var status_bar: HBoxContainer = $MainContainer/StatusBar
@onready var html_path_label: Label = $MainContainer/StatusBar/HtmlPathLabel
@onready var css_path_label: Label = $MainContainer/StatusBar/CssPathLabel
@onready var no_selection_container: CenterContainer = $NoSelectionContainer

# Search bar references
@onready var search_bar: HBoxContainer = $MainContainer/SearchBar
@onready var search_input: LineEdit = $MainContainer/SearchBar/SearchInput
@onready var match_case_check: CheckBox = $MainContainer/SearchBar/MatchCaseCheck
@onready var regex_check: CheckBox = $MainContainer/SearchBar/RegexCheck
@onready var prev_button: Button = $MainContainer/SearchBar/PrevButton
@onready var next_button: Button = $MainContainer/SearchBar/NextButton
@onready var match_count_label: Label = $MainContainer/SearchBar/MatchCountLabel
@onready var close_search_button: Button = $MainContainer/SearchBar/CloseSearchButton

# Replace bar references
@onready var replace_bar: HBoxContainer = $MainContainer/ReplaceBar
@onready var replace_input: LineEdit = $MainContainer/ReplaceBar/ReplaceInput
@onready var replace_button: Button = $MainContainer/ReplaceBar/ReplaceButton
@onready var replace_all_button: Button = $MainContainer/ReplaceBar/ReplaceAllButton

# Go to line dialog references
@onready var goto_line_dialog: AcceptDialog = $GotoLineDialog
@onready var line_input: SpinBox = $GotoLineDialog/VBox/LineInput

#endregion


#region State

var _current_gml_view: WeakRef = weakref(null)
var _html_path: String = ""
var _css_path: String = ""
var _html_dirty: bool = false
var _css_dirty: bool = false
var _original_html_content: String = ""
var _original_css_content: String = ""
var _html_highlighter: SyntaxHighlighter = null
var _css_highlighter: SyntaxHighlighter = null

# Inline warning panel built dynamically (so we don't have to touch the .tscn).
var _warnings_panel: PanelContainer = null
var _warnings_list: VBoxContainer = null
var _warnings_header: Label = null

# Editor state preservation (per GmlView node path)
var _editor_states: Dictionary = {}  # node_path -> { html_caret, html_scroll, css_caret, css_scroll, active_tab }
var _pending_state_restore: Dictionary = {}  # Pending state to restore when tab becomes visible

# Search state
var _search_matches: Array = []  # Array of {line, column, length}
var _current_match_index: int = -1

# Jump history (Ctrl+Click / F12 push, Alt+Left pops)
var _jump_history: Array = []  # [{source: "html"|"css", line, col}, ...]

#endregion


func _ready() -> void:
	if not Engine.is_editor_hint():
		return

	# Connect button signals
	save_button.pressed.connect(_on_save_pressed)
	reload_button.pressed.connect(_on_reload_pressed)

	# Connect text changed signals to track dirty state
	html_code_edit.text_changed.connect(_on_html_text_changed)
	css_code_edit.text_changed.connect(_on_css_text_changed)

	# Connect tab changed signal for deferred state restoration
	tab_container.tab_changed.connect(_on_tab_changed)

	# Connect search bar signals
	search_input.text_changed.connect(_on_search_text_changed)
	search_input.text_submitted.connect(_on_search_submitted)
	prev_button.pressed.connect(_on_search_prev)
	next_button.pressed.connect(_on_search_next)
	close_search_button.pressed.connect(_close_search)
	match_case_check.toggled.connect(_on_match_case_toggled)
	regex_check.toggled.connect(_on_regex_toggled)

	# Connect replace bar signals
	replace_button.pressed.connect(_on_replace_pressed)
	replace_all_button.pressed.connect(_on_replace_all_pressed)

	# Connect go to line dialog
	goto_line_dialog.confirmed.connect(_on_goto_line_confirmed)
	line_input.get_line_edit().text_submitted.connect(_on_goto_line_submitted)

	# Wire Ctrl+Click on the CodeEdits to trigger jumps. F12/Alt+Left are
	# handled by _unhandled_key_input alongside the other editor shortcuts.
	html_code_edit.gui_input.connect(_on_code_edit_gui_input.bind(html_code_edit))
	css_code_edit.gui_input.connect(_on_code_edit_gui_input.bind(css_code_edit))

	# Configure CodeEdit settings
	_configure_code_edit(html_code_edit)
	_configure_code_edit(css_code_edit)

	# Set up syntax highlighters
	_html_highlighter = HtmlSyntaxHighlighter.new()
	_css_highlighter = CssSyntaxHighlighter.new()
	html_code_edit.syntax_highlighter = _html_highlighter
	css_code_edit.syntax_highlighter = _css_highlighter

	# Show initial state (no selection)
	_show_no_selection()


func _configure_code_edit(code_edit: CodeEdit) -> void:
	code_edit.gutters_draw_line_numbers = true
	code_edit.gutters_draw_fold_gutter = true
	code_edit.scroll_smooth = true
	code_edit.minimap_draw = true
	code_edit.minimap_width = 80
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_edit.highlight_current_line = true
	code_edit.indent_automatic = true
	code_edit.auto_brace_completion_enabled = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		# Ctrl+S to save
		if event.keycode == KEY_S and event.ctrl_pressed:
			_on_save_pressed()
			get_viewport().set_input_as_handled()

		# Ctrl+F to open search
		elif event.keycode == KEY_F and event.ctrl_pressed:
			_open_search()
			get_viewport().set_input_as_handled()

		# Ctrl+H to toggle replace bar (also opens search bar if hidden)
		elif event.keycode == KEY_H and event.ctrl_pressed:
			if not search_bar.visible:
				_open_search()
			_toggle_replace_bar(not replace_bar.visible)
			get_viewport().set_input_as_handled()

		# Ctrl+G to go to line
		elif event.keycode == KEY_G and event.ctrl_pressed:
			_open_goto_line()
			get_viewport().set_input_as_handled()

		# Escape to close search
		elif event.keycode == KEY_ESCAPE and search_bar.visible:
			_close_search()
			get_viewport().set_input_as_handled()

		# F3 for next match, Shift+F3 for previous
		elif event.keycode == KEY_F3 and search_bar.visible:
			if event.shift_pressed:
				_on_search_prev()
			else:
				_on_search_next()
			get_viewport().set_input_as_handled()

		# F12 to jump to definition from the active CodeEdit
		elif event.keycode == KEY_F12:
			_trigger_jump_at_caret(_get_active_code_edit())
			get_viewport().set_input_as_handled()

		# Alt+Left to pop the jump history
		elif event.keycode == KEY_LEFT and event.alt_pressed:
			_pop_jump_history()
			get_viewport().set_input_as_handled()


#region Public API

## Edit a GmlView node - loads its HTML/CSS files into the editor
func edit_gml_view(gml_view: Node) -> void:
	if gml_view == null:
		_show_no_selection()
		return

	# Check for unsaved changes before switching
	if _has_unsaved_changes():
		var current_view = _current_gml_view.get_ref()
		if current_view != null and current_view != gml_view:
			_show_unsaved_dialog(func():
				_do_edit_gml_view(gml_view)
			)
			return

	_do_edit_gml_view(gml_view)


## Clear the editor (called when GmlView is deselected)
func clear_editor() -> void:
	if _has_unsaved_changes():
		_show_unsaved_dialog(func():
			_do_clear_editor()
		)
	else:
		_do_clear_editor()


## Save current editor state (called when panel becomes invisible)
func save_state() -> void:
	_save_editor_state()

#endregion


#region Internal Methods

func _do_edit_gml_view(gml_view: Node) -> void:
	# Save state for previous view before switching
	_save_editor_state()

	_current_gml_view = weakref(gml_view)
	_html_path = gml_view.html_path
	_css_path = gml_view.css_path

	_load_files()
	_update_ui()
	_show_editor()

	# Restore state for this view (deferred to ensure UI is ready)
	call_deferred("_restore_editor_state")


func _do_clear_editor() -> void:
	# Save state before clearing
	_save_editor_state()

	_current_gml_view = weakref(null)
	_html_path = ""
	_css_path = ""
	_html_dirty = false
	_css_dirty = false
	_original_html_content = ""
	_original_css_content = ""

	html_code_edit.text = ""
	css_code_edit.text = ""

	_show_no_selection()


func _show_no_selection() -> void:
	if main_container:
		main_container.visible = false
	if no_selection_container:
		no_selection_container.visible = true


func _show_editor() -> void:
	if main_container:
		main_container.visible = true
	if no_selection_container:
		no_selection_container.visible = false


func _save_editor_state() -> void:
	var gml_view = _current_gml_view.get_ref()
	if not gml_view or not is_instance_valid(gml_view):
		return

	var node_path = str(gml_view.get_path())
	_editor_states[node_path] = {
		"html_caret_line": html_code_edit.get_caret_line(),
		"html_caret_column": html_code_edit.get_caret_column(),
		"html_scroll_v": html_code_edit.scroll_vertical,
		"html_scroll_h": html_code_edit.scroll_horizontal,
		"css_caret_line": css_code_edit.get_caret_line(),
		"css_caret_column": css_code_edit.get_caret_column(),
		"css_scroll_v": css_code_edit.scroll_vertical,
		"css_scroll_h": css_code_edit.scroll_horizontal,
		"active_tab": tab_container.current_tab,
	}


func _restore_editor_state() -> void:
	var gml_view = _current_gml_view.get_ref()
	if not gml_view or not is_instance_valid(gml_view):
		return

	var node_path = str(gml_view.get_path())
	if not _editor_states.has(node_path):
		return

	var state = _editor_states[node_path]

	# Store pending state for tab restoration
	_pending_state_restore = state.duplicate()

	# Wait a frame for UI to settle before restoring state
	await get_tree().process_frame

	# Restore active tab first
	if state.has("active_tab"):
		tab_container.current_tab = state.active_tab

	# Wait another frame for tab switch to complete
	await get_tree().process_frame

	# Restore the currently active tab's state
	_restore_current_tab_state()


func _restore_current_tab_state() -> void:
	if _pending_state_restore.is_empty():
		return

	var state = _pending_state_restore
	var html_idx = tab_container.get_tab_idx_from_control(html_tab)
	var css_idx = tab_container.get_tab_idx_from_control(css_tab)
	var current_tab = tab_container.current_tab

	# Restore HTML editor state if HTML tab is active
	if current_tab == html_idx and state.has("html_caret_line") and not _html_path.is_empty():
		html_code_edit.set_caret_line(state.html_caret_line)
		html_code_edit.set_caret_column(state.html_caret_column)
		html_code_edit.scroll_vertical = state.html_scroll_v
		html_code_edit.scroll_horizontal = state.html_scroll_h

	# Restore CSS editor state if CSS tab is active
	if current_tab == css_idx and state.has("css_caret_line") and not _css_path.is_empty():
		css_code_edit.set_caret_line(state.css_caret_line)
		css_code_edit.set_caret_column(state.css_caret_column)
		css_code_edit.scroll_vertical = state.css_scroll_v
		css_code_edit.scroll_horizontal = state.css_scroll_h


func _on_tab_changed(_tab: int) -> void:
	# When tab changes, restore state for the newly active tab
	call_deferred("_restore_current_tab_state")


func _load_files() -> void:
	# Load HTML
	if not _html_path.is_empty() and FileAccess.file_exists(_html_path):
		var file = FileAccess.open(_html_path, FileAccess.READ)
		if file:
			_original_html_content = file.get_as_text()
			html_code_edit.text = _original_html_content
			file.close()
		else:
			html_code_edit.text = "# Error: Could not open file: " + _html_path
			_original_html_content = ""
	else:
		html_code_edit.text = ""
		_original_html_content = ""

	# Load CSS
	if not _css_path.is_empty() and FileAccess.file_exists(_css_path):
		var file = FileAccess.open(_css_path, FileAccess.READ)
		if file:
			_original_css_content = file.get_as_text()
			css_code_edit.text = _original_css_content
			file.close()
		else:
			css_code_edit.text = "/* Error: Could not open file: " + _css_path + " */"
			_original_css_content = ""
	else:
		css_code_edit.text = ""
		_original_css_content = ""

	_html_dirty = false
	_css_dirty = false


func _update_ui() -> void:
	var gml_view = _current_gml_view.get_ref()

	# Update file label
	if gml_view:
		file_label.text = gml_view.name
	else:
		file_label.text = "(no GmlView selected)"

	# Update tab visibility
	var html_idx = tab_container.get_tab_idx_from_control(html_tab)
	var css_idx = tab_container.get_tab_idx_from_control(css_tab)

	# Show/hide HTML tab
	if html_idx >= 0:
		tab_container.set_tab_hidden(html_idx, _html_path.is_empty())

	# Show/hide CSS tab
	if css_idx >= 0:
		tab_container.set_tab_hidden(css_idx, _css_path.is_empty())

	# Select first visible tab
	if not _html_path.is_empty():
		tab_container.current_tab = html_idx
	elif not _css_path.is_empty():
		tab_container.current_tab = css_idx

	# Update status bar
	html_path_label.text = "HTML: " + (_html_path if not _html_path.is_empty() else "(none)")
	css_path_label.text = "CSS: " + (_css_path if not _css_path.is_empty() else "(none)")

	_update_tab_titles()
	_update_save_button()


func _update_tab_titles() -> void:
	var html_idx = tab_container.get_tab_idx_from_control(html_tab)
	var css_idx = tab_container.get_tab_idx_from_control(css_tab)

	if html_idx >= 0:
		var title = "HTML"
		if _html_dirty:
			title += " *"
		tab_container.set_tab_title(html_idx, title)

	if css_idx >= 0:
		var title = "CSS"
		if _css_dirty:
			title += " *"
		tab_container.set_tab_title(css_idx, title)


func _update_save_button() -> void:
	save_button.disabled = not _has_unsaved_changes()


func _has_unsaved_changes() -> bool:
	return _html_dirty or _css_dirty


func _show_unsaved_dialog(on_discard: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Unsaved Changes"
	dialog.dialog_text = "You have unsaved changes. Do you want to save them before continuing?"
	dialog.ok_button_text = "Save"
	dialog.add_button("Discard", true, "discard")
	dialog.add_cancel_button("Cancel")

	dialog.confirmed.connect(func():
		_save_files()
		on_discard.call()
		dialog.queue_free()
	)

	dialog.custom_action.connect(func(action):
		if action == "discard":
			_html_dirty = false
			_css_dirty = false
			on_discard.call()
			dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

#endregion


#region Signal Handlers

func _on_html_text_changed() -> void:
	_html_dirty = html_code_edit.text != _original_html_content
	_update_tab_titles()
	_update_save_button()


func _on_css_text_changed() -> void:
	_css_dirty = css_code_edit.text != _original_css_content
	_update_tab_titles()
	_update_save_button()


func _on_save_pressed() -> void:
	_save_files()


func _on_reload_pressed() -> void:
	if _has_unsaved_changes():
		var dialog = ConfirmationDialog.new()
		dialog.title = "Reload Files"
		dialog.dialog_text = "You have unsaved changes. Reloading will discard them. Continue?"
		dialog.ok_button_text = "Reload"

		dialog.confirmed.connect(func():
			_load_files()
			_update_tab_titles()
			_update_save_button()
			dialog.queue_free()
		)

		dialog.canceled.connect(func():
			dialog.queue_free()
		)

		add_child(dialog)
		dialog.popup_centered()
	else:
		_load_files()


func _save_files() -> void:
	var saved_any = false

	# Save HTML
	if _html_dirty and not _html_path.is_empty():
		var absolute_path = ProjectSettings.globalize_path(_html_path)
		var file = FileAccess.open(absolute_path, FileAccess.WRITE)
		if file:
			file.store_string(html_code_edit.text)
			file.flush()
			file.close()
			_original_html_content = html_code_edit.text
			_html_dirty = false
			saved_any = true
			print("GmlEditorPanel: Saved HTML to ", absolute_path)
		else:
			var error = FileAccess.get_open_error()
			push_error("GmlEditorPanel: Failed to save HTML to %s (error: %d)" % [absolute_path, error])

	# Save CSS
	if _css_dirty and not _css_path.is_empty():
		var absolute_path = ProjectSettings.globalize_path(_css_path)
		var file = FileAccess.open(absolute_path, FileAccess.WRITE)
		if file:
			file.store_string(css_code_edit.text)
			file.flush()
			file.close()
			_original_css_content = css_code_edit.text
			_css_dirty = false
			saved_any = true
			print("GmlEditorPanel: Saved CSS to ", absolute_path)
		else:
			var error = FileAccess.get_open_error()
			push_error("GmlEditorPanel: Failed to save CSS to %s (error: %d)" % [absolute_path, error])

	if saved_any:
		_update_tab_titles()
		_update_save_button()
		# GmlView will auto-detect file changes via modification time
		_refresh_warnings()

#endregion


#region Parse warnings panel

## Lazily build a PanelContainer at the bottom of MainContainer holding a
## VBoxContainer of warning rows. Each warning is a Button that jumps the
## relevant CodeEdit to the warning's line + column on click.
func _ensure_warnings_panel() -> void:
	if _warnings_panel != null and is_instance_valid(_warnings_panel):
		return

	_warnings_panel = PanelContainer.new()
	_warnings_panel.name = "WarningsPanel"
	_warnings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warnings_panel.visible = false

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	_warnings_panel.add_child(inner)

	_warnings_header = Label.new()
	_warnings_header.text = "Parse warnings"
	_warnings_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	inner.add_child(_warnings_header)

	_warnings_list = VBoxContainer.new()
	_warnings_list.add_theme_constant_override("separation", 1)
	inner.add_child(_warnings_list)

	main_container.add_child(_warnings_panel)


## Re-parse the current editor buffers, gather warnings from both parsers,
## and rebuild the inline panel. Called after every save so authors get
## fast feedback without leaving the editor.
func _refresh_warnings() -> void:
	_ensure_warnings_panel()

	# Clear previous rows
	for child in _warnings_list.get_children():
		_warnings_list.remove_child(child)
		child.queue_free()

	var html_warnings: Array = []
	var css_warnings: Array = []

	if not html_code_edit.text.is_empty():
		var html_parser = GmlHtmlParserScript.new()
		html_parser.parse(html_code_edit.text)
		html_warnings = html_parser.get_warnings()

	if not css_code_edit.text.is_empty():
		var css_parser = GmlCssParserScript.new()
		css_parser.parse(css_code_edit.text)
		css_warnings = css_parser.get_warnings()

	var total: int = html_warnings.size() + css_warnings.size()
	if total == 0:
		_warnings_panel.visible = false
		return

	_warnings_panel.visible = true
	_warnings_header.text = "Parse warnings (%d)" % total

	for w in html_warnings:
		_append_warning_row("HTML", w, html_code_edit, html_tab)
	for w in css_warnings:
		_append_warning_row("CSS", w, css_code_edit, css_tab)


func _append_warning_row(kind: String, w: Dictionary, code_edit: CodeEdit, tab: Control) -> void:
	var btn := Button.new()
	btn.text = "[%s %d:%d] %s" % [kind, int(w.get("line", 0)), int(w.get("col", 0)), str(w.get("msg", ""))]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	btn.pressed.connect(func():
		# Activate the tab, then jump the caret to the warning's line.
		var idx := tab_container.get_tab_idx_from_control(tab)
		if idx >= 0:
			tab_container.current_tab = idx
		var line: int = maxi(int(w.get("line", 1)) - 1, 0)
		var col: int = maxi(int(w.get("col", 1)) - 1, 0)
		code_edit.set_caret_line(line)
		code_edit.set_caret_column(col)
		code_edit.grab_focus()
	)
	_warnings_list.add_child(btn)

#endregion


#region Search & Go to Line

func _get_active_code_edit() -> CodeEdit:
	var html_idx = tab_container.get_tab_idx_from_control(html_tab)
	if tab_container.current_tab == html_idx:
		return html_code_edit
	return css_code_edit


func _open_search() -> void:
	search_bar.visible = true
	search_input.grab_focus()
	# If there's selected text, use it as search term
	var code_edit = _get_active_code_edit()
	var selected = code_edit.get_selected_text()
	if not selected.is_empty() and not "\n" in selected:
		search_input.text = selected
		_perform_search()
	search_input.select_all()


func _close_search() -> void:
	search_bar.visible = false
	replace_bar.visible = false
	_clear_search_highlights()
	_search_matches.clear()
	_current_match_index = -1
	match_count_label.text = ""
	# Return focus to code edit
	_get_active_code_edit().grab_focus()


func _toggle_replace_bar(show_it: bool) -> void:
	replace_bar.visible = show_it
	if show_it:
		replace_input.grab_focus()


func _on_replace_pressed() -> void:
	if _search_matches.is_empty() or _current_match_index < 0:
		return
	var code_edit := _get_active_code_edit()
	var m: Dictionary = _search_matches[_current_match_index]
	# Engine.replace_one expects {line, col, length}; panel state uses 'column'.
	var engine_match := {"line": m["line"], "col": m["column"], "length": m["length"]}
	code_edit.text = GmlSearchEngineScript.replace_one(code_edit.text, engine_match, replace_input.text)
	_perform_search()
	_on_search_next()


func _on_replace_all_pressed() -> void:
	var code_edit := _get_active_code_edit()
	var result: Dictionary = GmlSearchEngineScript.replace_all(
		code_edit.text,
		search_input.text,
		replace_input.text,
		match_case_check.button_pressed,
		regex_check.button_pressed,
	)
	code_edit.text = result["new_text"]
	match_count_label.text = "Replaced %d" % result["count"]
	_perform_search()


func _on_search_text_changed(_new_text: String) -> void:
	_perform_search()


func _on_search_submitted(_text: String) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_on_search_prev()
	else:
		_on_search_next()


func _on_match_case_toggled(_pressed: bool) -> void:
	_perform_search()


func _on_regex_toggled(_pressed: bool) -> void:
	_perform_search()


func _on_search_next() -> void:
	if _search_matches.is_empty():
		return
	_current_match_index = (_current_match_index + 1) % _search_matches.size()
	_goto_match(_current_match_index)


func _on_search_prev() -> void:
	if _search_matches.is_empty():
		return
	_current_match_index -= 1
	if _current_match_index < 0:
		_current_match_index = _search_matches.size() - 1
	_goto_match(_current_match_index)


func _perform_search() -> void:
	_clear_search_highlights()
	_search_matches.clear()
	_current_match_index = -1

	var search_text = search_input.text
	if search_text.is_empty():
		match_count_label.text = ""
		return

	var code_edit = _get_active_code_edit()
	var engine_matches: Array = GmlSearchEngineScript.find_all(
		code_edit.text,
		search_text,
		match_case_check.button_pressed,
		regex_check.button_pressed,
	)

	# Translate engine's {line, col, length} -> panel's {line, column, length}
	# so existing _goto_match / _highlight_matches logic keeps working.
	for em in engine_matches:
		_search_matches.append({
			"line": em["line"],
			"column": em["col"],
			"length": em["length"],
		})

	# Update match count label
	if _search_matches.is_empty():
		match_count_label.text = "No matches"
	else:
		match_count_label.text = "%d matches" % _search_matches.size()
		# Find the match closest to current caret
		var caret_line = code_edit.get_caret_line()
		var caret_col = code_edit.get_caret_column()
		_current_match_index = 0
		for i in range(_search_matches.size()):
			var m = _search_matches[i]
			if m.line > caret_line or (m.line == caret_line and m.column >= caret_col):
				_current_match_index = i
				break

	_highlight_matches()


func _highlight_matches() -> void:
	var code_edit = _get_active_code_edit()
	for match in _search_matches:
		code_edit.set_line_background_color(match.line, Color(0.3, 0.3, 0.0, 0.3))


func _clear_search_highlights() -> void:
	var code_edit = _get_active_code_edit()
	for i in range(code_edit.get_line_count()):
		code_edit.set_line_background_color(i, Color(0, 0, 0, 0))


func _goto_match(index: int) -> void:
	if index < 0 or index >= _search_matches.size():
		return

	var match = _search_matches[index]
	var code_edit = _get_active_code_edit()

	# Clear previous highlight and set new one
	_clear_search_highlights()
	_highlight_matches()
	code_edit.set_line_background_color(match.line, Color(0.5, 0.5, 0.0, 0.5))

	# Go to match position and select it
	code_edit.set_caret_line(match.line)
	code_edit.set_caret_column(match.column)
	code_edit.select(match.line, match.column, match.line, match.column + match.length)
	code_edit.center_viewport_to_caret()

	# Update label to show current position
	match_count_label.text = "%d / %d" % [index + 1, _search_matches.size()]


func _open_goto_line() -> void:
	var code_edit = _get_active_code_edit()
	line_input.max_value = code_edit.get_line_count()
	line_input.value = code_edit.get_caret_line() + 1
	goto_line_dialog.popup_centered()
	# Select the input value for easy typing
	line_input.get_line_edit().select_all()
	line_input.get_line_edit().grab_focus()


func _on_goto_line_confirmed() -> void:
	var code_edit = _get_active_code_edit()
	var target_line = int(line_input.value) - 1  # Convert to 0-indexed
	target_line = clamp(target_line, 0, code_edit.get_line_count() - 1)
	code_edit.set_caret_line(target_line)
	code_edit.set_caret_column(0)
	code_edit.center_viewport_to_caret()
	code_edit.grab_focus()


func _on_goto_line_submitted(_text: String) -> void:
	_on_goto_line_confirmed()
	goto_line_dialog.hide()

#endregion


#region Jumps (Ctrl+Click / F12 / Alt+Left)

func _on_code_edit_gui_input(event: InputEvent, code_edit: CodeEdit) -> void:
	# Handle key events here too — CodeEdit otherwise swallows them
	# (Alt+Left = move-word-backward, etc.) before _unhandled_key_input.
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			_trigger_jump_at_caret(code_edit)
			code_edit.accept_event()
			return
		if event.alt_pressed and event.keycode == KEY_LEFT:
			_pop_jump_history()
			code_edit.accept_event()
			return
		return

	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.ctrl_pressed:
		return
	# Caret update from the click happens after gui_input; defer one frame
	# so get_caret_line/column reflect the clicked position.
	await get_tree().process_frame
	_trigger_jump_at_caret(code_edit)


func _trigger_jump_at_caret(code_edit: CodeEdit) -> void:
	if code_edit == null:
		return
	var kind: String = "html" if code_edit == html_code_edit else "css"
	var other: String = css_code_edit.text if kind == "html" else html_code_edit.text
	var ctx: GmlEditorContext
	if kind == "html":
		ctx = GmlEditorContextScript.from_html(
			code_edit.text,
			code_edit.get_caret_line(),
			code_edit.get_caret_column(),
			other,
		)
	else:
		ctx = GmlEditorContextScript.from_css(
			code_edit.text,
			code_edit.get_caret_line(),
			code_edit.get_caret_column(),
			other,
		)

	var jump = GmlJumpResolverScript.resolve(ctx)
	if jump == null:
		return

	# Push current position to history BEFORE jumping so Alt+Left returns here.
	_jump_history.append({
		"source": kind,
		"line": code_edit.get_caret_line(),
		"col": code_edit.get_caret_column(),
	})

	_go_to(jump["target_kind"], int(jump["line"]), int(jump.get("col", 0)))


func _go_to(target_kind: String, line: int, col: int) -> void:
	var target_edit: CodeEdit = html_code_edit if target_kind == "html" else css_code_edit
	var target_tab: Control = html_tab if target_kind == "html" else css_tab
	var idx: int = tab_container.get_tab_idx_from_control(target_tab)
	if idx >= 0:
		tab_container.current_tab = idx
	target_edit.set_caret_line(line)
	target_edit.set_caret_column(col)
	target_edit.center_viewport_to_caret()
	target_edit.grab_focus()


func _pop_jump_history() -> void:
	if _jump_history.is_empty():
		return
	var prev: Dictionary = _jump_history.pop_back()
	_go_to(prev["source"], int(prev["line"]), int(prev["col"]))

#endregion
