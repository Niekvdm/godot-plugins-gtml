class_name GmlClassRestyler
extends RefCounted

## Recomputes a v-bound element's VISUAL style for a given dynamic class
## set and applies the deltas in place — no structural re-wrapping.
##
## See docs/superpowers/specs/2026-05-28-class-reresolve-design.md
##
## Selector matching reads classes off the GmlNode (no injection hook),
## so resolve_visual_props temporarily sets the node's `class` attr to
## the merged static+dynamic list, runs the resolver, then restores it.

## Visual properties this module re-resolves. Anything else (layout /
## structural) is ignored — see _warn_layout_props.
const VISUAL_KEYS: Array = [
	"color",
	"background-color",
	"border-color",
	"border-width",
	"border-radius",
	"outline-color",
	"outline-width",
	"opacity",
	"font-size",
]

## Layout keys that, if present in a dynamic class, get warned about once.
const LAYOUT_KEYS: Array = [
	"display", "flex-direction", "flex-grow", "flex-shrink", "flex-wrap",
	"width", "height", "padding", "margin", "gap",
	"padding-left", "padding-right", "padding-top", "padding-bottom",
	"margin-left", "margin-right", "margin-top", "margin-bottom",
	"position",
]


## Resolve the visual-property subset for `node` as if its class list were
## `class_list`. Returns a Dictionary containing only VISUAL_KEYS that the
## cascade produced. Temporarily mutates + restores node's class attr.
static func resolve_visual_props(node, ancestor_chain: Array, class_list: PackedStringArray, css_rules: Array) -> Dictionary:
	var resolver = GmlStyleResolver.new()
	var original_class: String = node.get_attr("class", "")
	node.attrs["class"] = " ".join(class_list)
	var full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	node.attrs["class"] = original_class

	var out: Dictionary = {}
	for k in VISUAL_KEYS:
		if full.has(k):
			out[k] = full[k]
	return out


## Warn (once per control) if the recomputed full style introduces a
## layout key the dynamic class set changed. Called by restyle().
static func _warn_layout_props(control: Control, full_style: Dictionary) -> void:
	if control.get_meta("_layout_warn_done", false):
		return
	for k in LAYOUT_KEYS:
		if full_style.has(k):
			GmlBindingApplier._warn("dynamic :class changed layout prop '%s' — ignored; v0.8.2 re-resolves visual props only (color/bg/border/opacity/font-size)" % k)
			control.set_meta("_layout_warn_done", true)
			return


## Recompute the bound element's visual style for the active dynamic
## class set and apply the deltas in place. When dynamic_classes is empty
## the target is exactly base_snapshot (clean revert). transition_manager
## may be null (snap directly).
static func restyle(control: Control, node, ancestor_chain: Array, dynamic_classes: PackedStringArray, css_rules: Array, base_snapshot: Dictionary, transition_manager) -> void:
	if control == null or node == null:
		return

	# Merge static (node's own) + dynamic classes for the recompute.
	var static_classes: PackedStringArray = node.get_classes()
	var merged: PackedStringArray = PackedStringArray()
	for c in static_classes:
		if not merged.has(c):
			merged.append(c)
	for c in dynamic_classes:
		if not merged.has(c):
			merged.append(c)

	# Full recompute (for layout-warn detection) + visual subset.
	var resolver = GmlStyleResolver.new()
	var original_class: String = node.get_attr("class", "")
	node.attrs["class"] = " ".join(merged)
	var full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	node.attrs["class"] = original_class

	_warn_layout_props(control, full)

	# Target visual props: start from base, overlay recomputed visual keys.
	var target: Dictionary = {}
	for k in VISUAL_KEYS:
		if base_snapshot.has(k):
			target[k] = base_snapshot[k]
	for k in VISUAL_KEYS:
		if full.has(k):
			target[k] = full[k]

	_apply_visual(control, target, full, transition_manager)


## Apply visual props to the control in place. Stylebox-bearing controls
## (PanelContainer/Button) get bg/border mutated on their existing
## stylebox; Labels get font_color; all controls get opacity via modulate.
## When the bound control is a container (e.g. HBoxContainer for <li>),
## font_color propagates to all descendant Labels — matching CSS `color`
## inheritance so `:class` on a container re-colors its text children.
static func _apply_visual(control: Control, target: Dictionary, full_style: Dictionary, transition_manager) -> void:
	# Opacity → modulate.a
	if target.has("opacity"):
		var a = target["opacity"]
		if a is float or a is int:
			control.modulate.a = float(a)

	# Font color → theme override (Label / RichTextLabel / Button / Button descendants).
	# For container controls (e.g. HBoxContainer wrapping a <li>), propagate the
	# color to all descendant Labels so CSS `color` inheritance is respected.
	if target.has("color"):
		var col = target["color"]
		if col is Color:
			_apply_font_color(control, col)

	# Font size
	if target.has("font-size"):
		var fs = target["font-size"]
		if fs is int or fs is float:
			control.add_theme_font_size_override("font_size", int(fs))

	# Stylebox-borne props: bg / border / outline / radius.
	var box: StyleBoxFlat = _get_stylebox(control)
	if box != null:
		if target.has("background-color") and target["background-color"] is Color:
			box.bg_color = target["background-color"]
		if target.has("border-color") and target["border-color"] is Color:
			box.border_color = target["border-color"]
		if target.has("border-width"):
			var bw = target["border-width"]
			if bw is int or bw is float:
				box.border_width_left = int(bw)
				box.border_width_top = int(bw)
				box.border_width_right = int(bw)
				box.border_width_bottom = int(bw)
		if target.has("border-radius"):
			var br = target["border-radius"]
			if br is int or br is float:
				box.corner_radius_top_left = int(br)
				box.corner_radius_top_right = int(br)
				box.corner_radius_bottom_left = int(br)
				box.corner_radius_bottom_right = int(br)


## Apply font_color to control and, if it is a container, to all descendant
## Labels / RichTextLabels. Mirrors CSS `color` inheritance.
static func _apply_font_color(control: Control, col: Color) -> void:
	if control is RichTextLabel:
		control.add_theme_color_override("default_color", col)
	elif control is Label or control is Button:
		control.add_theme_color_override("font_color", col)
	else:
		# Container: propagate to all Label/RTL descendants.
		for child in control.get_children():
			if child is Control:
				_apply_font_color(child as Control, col)


## Return the StyleBoxFlat a control renders its background through, or
## null if it has none (e.g. a plain Label).
static func _get_stylebox(control: Control) -> StyleBoxFlat:
	var key: String = ""
	if control is Button:
		key = "normal"
	elif control.has_theme_stylebox("panel"):
		key = "panel"
	if key.is_empty():
		return null
	var box = control.get_theme_stylebox(key)
	if box is StyleBoxFlat:
		return box
	return null
