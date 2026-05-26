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


## Default state pseudos the renderer is willing to track on a generic Control.
## Buttons override this via setup_with_signals() so their active/pressed
## state participates in bucket matching too.
const TRACKED_STATES := ["hover", "focus"]


## Connect mouse_entered/exited and focus_entered/exited handlers on ``control``
## so the transition manager interpolates the style as states toggle.
## No-op if there are no transitions defined or no state buckets present.
static func setup(control: Control, style: Dictionary, transition_manager) -> void:
	var signals: Array = [
		{"state": "hover", "on_enter": control.mouse_entered, "on_exit": control.mouse_exited},
		{"state": "focus", "on_enter": control.focus_entered, "on_exit": control.focus_exited},
	]
	setup_with_signals(control, style, transition_manager, signals)


## Generic state-bucket transition setup. ``signals`` is a list of
## ``{state: String, on_enter: Signal, on_exit: Signal}`` entries that tell us
## which pseudo states to track and which Signal pair toggles each. Buttons
## use this directly to add ``active`` (button_down/up) on top of the hover +
## focus pair the generic ``setup()`` provides.
static func setup_with_signals(control: Control, style: Dictionary, transition_manager, signals: Array) -> void:
	var transitions: Array = style.get("transition", [])
	if transitions.is_empty() or transition_manager == null:
		return

	var buckets: Array = _collect_state_buckets(style)
	if buckets.is_empty():
		return

	# Only connect handlers for states some bucket actually references.
	var needed: Dictionary = {}
	for b in buckets:
		for p in (b["set"] as Array):
			needed[p] = true
	var any_signal_needed := false
	for spec in signals:
		if needed.get(spec["state"], false):
			any_signal_needed = true
			break
	if not any_signal_needed:
		return

	var base_style: Dictionary = _strip_state_keys(style)
	_normalize_border_properties(base_style)

	var stylebox_props: Dictionary = {}
	if base_style.has("border-radius"):
		stylebox_props["corner_radius"] = base_style["border-radius"]
	if base_style.has("border-width"):
		stylebox_props["border_width"] = base_style["border-width"]
	if base_style.has("border-color"):
		stylebox_props["border_color"] = base_style["border-color"]
	control.set_meta("_stylebox_props", stylebox_props)

	var state: Dictionary = {}
	for spec in signals:
		state[spec["state"]] = false

	var apply_transition := func(prev_state: Dictionary):
		var from_style: Dictionary = _compute_target(base_style, buckets, prev_state)
		var to_style: Dictionary = _compute_target(base_style, buckets, state)
		transition_manager.transition_style(control, from_style, to_style, transitions)

	for spec in signals:
		var state_name: String = spec["state"]
		if not needed.get(state_name, false):
			continue
		var enter_sig: Signal = spec["on_enter"]
		var exit_sig: Signal = spec["on_exit"]
		enter_sig.connect(func():
			var prev := state.duplicate()
			state[state_name] = true
			apply_transition.call(prev)
		)
		exit_sig.connect(func():
			var prev := state.duplicate()
			state[state_name] = false
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
		# Sort the set itself so two buckets that mention the same pseudos
		# in different source orders share a stable comparison key. The
		# resolver already emits sorted-key bucket names so this is normally
		# a no-op, but defensive sorting keeps the tie-break deterministic.
		set.sort()
		out.append({
			"set": set,
			"props": style[key],
			"size": set.size(),
			"key": "+".join(set),
		})
	# Sort by ascending set size so larger (more specific) buckets are
	# merged last in _compute_target. For same-size buckets, fall back to
	# the lexicographic key so the merge order is stable across runs —
	# Godot's sort_custom is not guaranteed stable.
	out.sort_custom(func(a, b):
		if int(a["size"]) != int(b["size"]):
			return int(a["size"]) < int(b["size"])
		return str(a["key"]) < str(b["key"])
	)
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
