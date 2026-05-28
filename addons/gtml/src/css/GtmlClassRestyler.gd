class_name GtmlClassRestyler
extends RefCounted

## Recomputes a v-bound element's VISUAL style for a given dynamic class
## set and applies the deltas in place — no structural re-wrapping.
##
## See docs/superpowers/specs/2026-05-28-class-reresolve-design.md
##
## Selector matching reads classes off the GtmlNode (no injection hook),
## so resolve_visual_props temporarily sets the node's `class` attr to
## the merged static+dynamic list, runs the resolver, then restores it.

## Visual properties this module re-resolves. Anything else (layout /
## structural) is ignored — see _warn_layout_props.
## NOTE: outline-* is intentionally NOT here — GTML's outline isn't a
## StyleBoxFlat field we can mutate in place; outline re-resolution is
## deferred. Declaring it without an apply branch would silently fail.
const VISUAL_KEYS: Array = [
	"color",
	"background-color",
	"border-color",
	"border-width",
	"border-radius",
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
	var resolver = GtmlStyleResolver.new()
	var original_class: String = node.get_attr("class", "")
	node.attrs["class"] = " ".join(class_list)
	var full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	node.attrs["class"] = original_class

	var out: Dictionary = {}
	for k in VISUAL_KEYS:
		if full.has(k):
			out[k] = full[k]
	return out


## Layout keys whose value the dynamic class actually changed relative to the
## base (static-only) style. A key is "changed" if its value differs — merely
## being present in both (e.g. a padded element that also has a color-only
## dynamic class) is NOT a change and must not warn.
static func changed_layout_keys(full_style: Dictionary, base_style: Dictionary) -> Array:
	var out: Array = []
	for k in LAYOUT_KEYS:
		if full_style.get(k, null) != base_style.get(k, null):
			out.append(k)
	return out


## Warn (once per control) only if the dynamic class set actually changed a
## layout key relative to the base style. Called by restyle().
static func _warn_layout_props(control: Control, full_style: Dictionary, base_style: Dictionary) -> void:
	if control.get_meta("_layout_warn_done", false):
		return
	var changed: Array = changed_layout_keys(full_style, base_style)
	if not changed.is_empty():
		GtmlBindingApplier._warn("dynamic :class changed layout prop '%s' — ignored; v0.8.2 re-resolves visual props only (color/bg/border/opacity/font-size)" % changed[0])
		control.set_meta("_layout_warn_done", true)


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
	var resolver = GtmlStyleResolver.new()
	var original_class: String = node.get_attr("class", "")
	node.attrs["class"] = " ".join(merged)
	var full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	node.attrs["class"] = original_class

	# Base (static-only) style: warn only when the dynamic class actually
	# changes a layout key, not merely because the element has one.
	var base_full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	_warn_layout_props(control, full, base_full)

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
	# Keys applied on the previous restyle (so we can CLEAR overrides that
	# no longer apply — e.g. a dynamic class removed and no static rule
	# supplies that property, so base_snapshot lacks it too). Without this,
	# theme overrides from a prior cycle would stick forever.
	var prev_keys: Array = control.get_meta("_restyle_keys", [])

	# Opacity → modulate.a (revert to 1.0 when no longer applied).
	if target.has("opacity"):
		var a = target["opacity"]
		if a is float or a is int:
			control.modulate.a = float(a)
	elif "opacity" in prev_keys:
		control.modulate.a = 1.0

	# Font color → theme override (Label / RichTextLabel / Button / Button descendants).
	# For container controls (e.g. HBoxContainer wrapping a <li>), propagate the
	# color to all descendant Labels so CSS `color` inheritance is respected.
	if target.has("color"):
		var col = target["color"]
		if col is Color:
			_apply_font_color(control, col)
	elif "color" in prev_keys:
		_clear_font_color(control)

	# Font size (clear the override when no longer applied).
	if target.has("font-size"):
		var fs = target["font-size"]
		if fs is int or fs is float:
			control.add_theme_font_size_override("font_size", int(fs))
	elif "font-size" in prev_keys:
		_clear_font_size(control)

	# Record which keys we applied this pass for next-time clearing.
	var applied: Array = []
	for k in VISUAL_KEYS:
		if target.has(k):
			applied.append(k)
	control.set_meta("_restyle_keys", applied)

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


## Remove the font-color override applied by _apply_font_color, recursing
## into containers the same way. Used on revert when no rule supplies color.
static func _clear_font_color(control: Control) -> void:
	if control is RichTextLabel:
		control.remove_theme_color_override("default_color")
	elif control is Label or control is Button:
		control.remove_theme_color_override("font_color")
	else:
		for child in control.get_children():
			if child is Control:
				_clear_font_color(child as Control)


## Remove the font-size override (revert path).
static func _clear_font_size(control: Control) -> void:
	if control.has_theme_font_size_override("font_size"):
		control.remove_theme_font_size_override("font_size")


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
