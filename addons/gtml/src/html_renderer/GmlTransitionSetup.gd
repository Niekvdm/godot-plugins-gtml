class_name GmlTransitionSetup
extends RefCounted

## Wires hover/focus signal handlers on a control so the GmlTransitionManager
## can interpolate between base and pseudo-class style dictionaries.
##
## Mouse and focus state are tracked together so that, e.g., releasing hover
## while focus is still held returns the control to the focus style rather
## than the base style.


## Connect mouse_entered/exited and focus_entered/exited handlers on ``control``
## using transition definitions and pseudo-class overrides from ``style``.
## No-op if there are no transitions or no pseudo-classes to interpolate to.
static func setup(control: Control, style: Dictionary, transition_manager) -> void:
	var transitions: Array = style.get("transition", [])
	if transitions.is_empty() or transition_manager == null:
		return

	var hover_style: Dictionary = style.get("_hover", {})
	var focus_style: Dictionary = style.get("_focus", {})
	if hover_style.is_empty() and focus_style.is_empty():
		return

	# Build a clean base style with pseudo keys stripped + border shorthand exploded.
	var base_style: Dictionary = style.duplicate()
	for k in ["_hover", "_active", "_focus", "_disabled"]:
		base_style.erase(k)
	_normalize_border_properties(base_style)

	var hover_complete := base_style.duplicate()
	for key in hover_style:
		hover_complete[key] = hover_style[key]

	var focus_complete := base_style.duplicate()
	for key in focus_style:
		focus_complete[key] = focus_style[key]

	# Cache stylebox props in meta so the transition manager can reach them.
	var stylebox_props: Dictionary = {}
	if base_style.has("border-radius"):
		stylebox_props["corner_radius"] = base_style["border-radius"]
	if base_style.has("border-width"):
		stylebox_props["border_width"] = base_style["border-width"]
	if base_style.has("border-color"):
		stylebox_props["border_color"] = base_style["border-color"]
	control.set_meta("_stylebox_props", stylebox_props)

	# Shared state across the four handlers below.
	var state := {"is_hovered": false, "is_focused": false}

	if not hover_style.is_empty():
		control.mouse_entered.connect(func():
			state.is_hovered = true
			var from_style: Dictionary = focus_complete if state.is_focused else base_style
			transition_manager.transition_style(control, from_style, hover_complete, transitions)
		)
		control.mouse_exited.connect(func():
			state.is_hovered = false
			var to_style: Dictionary = focus_complete if state.is_focused else base_style
			transition_manager.transition_style(control, hover_complete, to_style, transitions)
		)

	if not focus_style.is_empty():
		control.focus_entered.connect(func():
			state.is_focused = true
			if not state.is_hovered:
				transition_manager.transition_style(control, base_style, focus_complete, transitions)
		)
		control.focus_exited.connect(func():
			state.is_focused = false
			if not state.is_hovered:
				transition_manager.transition_style(control, focus_complete, base_style, transitions)
		)


## Pull border-color and border-width out of the ``border`` shorthand so the
## transition manager can find them as standalone keys.
static func _normalize_border_properties(style: Dictionary) -> void:
	if not (style.has("border") and style["border"] is Dictionary):
		return
	var border_dict: Dictionary = style["border"]
	if not style.has("border-color") and border_dict.has("color"):
		style["border-color"] = border_dict["color"]
	if not style.has("border-width") and border_dict.has("width"):
		style["border-width"] = border_dict["width"]
