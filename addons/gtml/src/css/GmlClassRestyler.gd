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
