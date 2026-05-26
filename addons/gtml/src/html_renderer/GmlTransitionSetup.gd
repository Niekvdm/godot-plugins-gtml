class_name GmlTransitionSetup
extends RefCounted

## Wires hover/focus signal handlers on a control so the GmlTransitionManager
## can interpolate between style states.
##
## v0.3 supports multi-pseudo combined states. The resolver emits one bucket
## per distinct sorted pseudo set: ``_hover``, ``_focus``, ``_focus+hover``,
## etc. At each event we recompute the active set, look up every bucket whose
## set is a subset of it, and merge them in (size, source-order) order to
## produce the target style. The "more specific" bucket (e.g.
## ``_focus+hover`` over ``_hover``) wins because it's merged later.
##
## Active / disabled state pseudos parse and resolve correctly but the
## renderer does not yet emit events for them — that wiring is deferred to
## a later release. They're treated as always-false here so rules that mention
## them simply never fire.


## State pseudos the runtime currently tracks. Anything else in a bucket key
## means the bucket can never become active.
const TRACKED_STATES := ["hover", "focus"]


## Connect mouse_entered/exited and focus_entered/exited handlers on ``control``
## so the transition manager interpolates the style as states toggle.
## No-op if there are no transitions defined or no state buckets present.
static func setup(control: Control, style: Dictionary, transition_manager) -> void:
	var transitions: Array = style.get("transition", [])
	if transitions.is_empty() or transition_manager == null:
		return

	# Extract all state buckets (keys prefixed with "_"). Each bucket is
	# (sorted-pseudo-set, props). We skip "_disabled"/"_active" buckets at the
	# event level (no runtime signal), but we still parse them so future wiring
	# can pick them up.
	var buckets: Array = _collect_state_buckets(style)
	if buckets.is_empty():
		return

	# Determine which tracked events are actually needed. If no bucket
	# references hover, don't bother connecting mouse signals; same for focus.
	var needs_hover := false
	var needs_focus := false
	for b in buckets:
		if "hover" in (b["set"] as Array):
			needs_hover = true
		if "focus" in (b["set"] as Array):
			needs_focus = true
	if not (needs_hover or needs_focus):
		return

	var base_style: Dictionary = _strip_state_keys(style)
	_normalize_border_properties(base_style)

	# Cache stylebox metas so the transition manager can interpolate corner
	# radius, border width, and border color even when they come from the
	# border shorthand.
	var stylebox_props: Dictionary = {}
	if base_style.has("border-radius"):
		stylebox_props["corner_radius"] = base_style["border-radius"]
	if base_style.has("border-width"):
		stylebox_props["border_width"] = base_style["border-width"]
	if base_style.has("border-color"):
		stylebox_props["border_color"] = base_style["border-color"]
	control.set_meta("_stylebox_props", stylebox_props)

	var state := {"hover": false, "focus": false}

	var apply_transition := func(prev_state: Dictionary):
		var from_style: Dictionary = _compute_target(base_style, buckets, prev_state)
		var to_style: Dictionary = _compute_target(base_style, buckets, state)
		transition_manager.transition_style(control, from_style, to_style, transitions)

	if needs_hover:
		control.mouse_entered.connect(func():
			var prev := state.duplicate()
			state["hover"] = true
			apply_transition.call(prev)
		)
		control.mouse_exited.connect(func():
			var prev := state.duplicate()
			state["hover"] = false
			apply_transition.call(prev)
		)

	if needs_focus:
		control.focus_entered.connect(func():
			var prev := state.duplicate()
			state["focus"] = true
			apply_transition.call(prev)
		)
		control.focus_exited.connect(func():
			var prev := state.duplicate()
			state["focus"] = false
			apply_transition.call(prev)
		)


## Read every ``_*`` key on ``style`` and return them as a sorted list of
## {set: Array[String], props: Dictionary, size: int}. Sorting by size ascending
## ensures that when we apply matching buckets in order, the most specific
## (largest matching set) wins by being merged last.
static func _collect_state_buckets(style: Dictionary) -> Array:
	var out: Array = []
	for key in style.keys():
		var k := str(key)
		if not k.begins_with("_") or k.length() < 2:
			continue
		var body := k.substr(1)
		# Skip non-state internal metadata (e.g. _stylebox_props would have
		# been added by our own caching; defensive guard).
		if body == "stylebox_props":
			continue
		var set: Array = Array(body.split("+", false))
		out.append({"set": set, "props": style[key], "size": set.size()})
	out.sort_custom(func(a, b): return int(a["size"]) < int(b["size"]))
	return out


## Strip every ``_*`` state-bucket key from ``style`` so what's left is the
## base (no-state) style.
static func _strip_state_keys(style: Dictionary) -> Dictionary:
	var out: Dictionary = style.duplicate()
	for key in style.keys():
		if str(key).begins_with("_"):
			out.erase(key)
	return out


## Merge ``base`` with every bucket whose pseudo set ⊆ the active state,
## producing the style that should be shown for that state combination.
static func _compute_target(base: Dictionary, buckets: Array, active: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for b in buckets:
		var set: Array = b["set"]
		var ok := true
		for p in set:
			if not active.get(p, false):
				ok = false
				break
		if ok:
			for key in (b["props"] as Dictionary):
				out[key] = b["props"][key]
	return out


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
