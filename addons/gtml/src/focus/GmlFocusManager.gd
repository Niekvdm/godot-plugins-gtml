class_name GmlFocusManager
extends RefCounted

## Keyboard/gamepad focus traversal for a built GTML Control tree.
##
## Reads the _gml_* focus meta stamped at build time by the renderer
## and wires focus_next / focus_previous (+ neighbor_bottom/top mirrors)
## in document order honoring HTML tabindex rules + focus-trap groups.
##
## Pure ordering — does NOT set focus_mode (the build stamp does that)
## and does NOT grab focus (GmlView orchestrates autofocus once per
## rebuild via find_autofocus). Idempotent: re-running clears + rewrites
## all four neighbor properties, so it's safe after every reconcile.

const META_FOCUSABLE := "_gml_focusable"
const META_TABINDEX := "_gml_tabindex"
const META_TAB_SKIP := "_gml_tab_skip"
const META_AUTOFOCUS := "_gml_autofocus"
const META_TRAP := "_gml_focus_trap"


## Walk `root`, collect focusables, group by trap subtree, order each
## group by (tabindex, doc_order), wire the chain.
static func wire_focus(root: Control) -> void:
	if root == null:
		return
	var entries: Array = _collect(root)

	var groups: Dictionary = {}
	for e in entries:
		var trap = e["trap_group"]
		var gkey: int = trap.get_instance_id() if trap != null else 0
		if not groups.has(gkey):
			groups[gkey] = {"trap": trap, "items": []}
		groups[gkey]["items"].append(e)

	for gkey in groups:
		var g: Dictionary = groups[gkey]
		var is_trap: bool = g["trap"] != null
		var ordered: Array = _order(g["items"])
		_wire_chain(ordered, is_trap)


## Pre-order (document-order) collection of focusable entries. Each:
##   {control, doc_order, tabindex, tab_skip, trap_group}
static func _collect(root: Control) -> Array:
	var out: Array = []
	var counter: Array = [0]
	_walk(root, null, out, counter)
	return out


static func _walk(ctrl, current_trap, out: Array, counter: Array) -> void:
	if not (ctrl is Control):
		return
	var doc: int = counter[0]
	counter[0] += 1
	var trap_here = current_trap
	if (ctrl as Control).get_meta(META_TRAP, false):
		trap_here = ctrl
	if (ctrl as Control).get_meta(META_FOCUSABLE, false):
		out.append({
			"control": ctrl,
			"doc_order": doc,
			"tabindex": int((ctrl as Control).get_meta(META_TABINDEX, 0)),
			"tab_skip": bool((ctrl as Control).get_meta(META_TAB_SKIP, false)),
			"trap_group": trap_here,
		})
	for child in (ctrl as Control).get_children():
		_walk(child, trap_here, out, counter)


## Apply HTML tabindex ordering to a group's items, excluding tab_skip.
static func _order(items: Array) -> Array:
	var tabbable: Array = items.filter(func(e): return not e["tab_skip"])
	var positive: Array = tabbable.filter(func(e): return e["tabindex"] > 0)
	var natural: Array = tabbable.filter(func(e): return e["tabindex"] <= 0)
	positive.sort_custom(func(a, b):
		if a["tabindex"] != b["tabindex"]:
			return a["tabindex"] < b["tabindex"]
		return a["doc_order"] < b["doc_order"]
	)
	natural.sort_custom(func(a, b): return a["doc_order"] < b["doc_order"])
	var out: Array = []
	for e in positive:
		out.append(e)
	for e in natural:
		out.append(e)
	return out


## Wire focus_next/previous (+ neighbor mirrors) across an ordered list.
## wrap=true (trap groups) cycles last↔first; wrap=false clears the ends.
static func _wire_chain(ordered: Array, wrap: bool) -> void:
	var n: int = ordered.size()
	for i in n:
		var c: Control = ordered[i]["control"]
		var next_path: NodePath = NodePath("")
		var prev_path: NodePath = NodePath("")
		if i + 1 < n:
			next_path = c.get_path_to(ordered[i + 1]["control"])
		elif wrap and n > 1:
			next_path = c.get_path_to(ordered[0]["control"])
		if i - 1 >= 0:
			prev_path = c.get_path_to(ordered[i - 1]["control"])
		elif wrap and n > 1:
			prev_path = c.get_path_to(ordered[n - 1]["control"])
		c.focus_next = next_path
		c.focus_previous = prev_path
		c.focus_neighbor_bottom = next_path
		c.focus_neighbor_top = prev_path


## First focusable with _gml_autofocus in document order, or null.
static func find_autofocus(root: Control) -> Control:
	if root == null:
		return null
	for e in _collect(root):
		if (e["control"] as Control).get_meta(META_AUTOFOCUS, false):
			return e["control"]
	return null


## The first control in the ROOT group's Tab order (positive-tabindex
## first, then natural), excluding focus-trap subtrees and tab_skip
## elements. This is what focus_first() should grab — NOT raw document
## order, which would ignore tabindex and could land inside a trap.
static func first_tabbable(root: Control) -> Control:
	if root == null:
		return null
	var root_group: Array = _collect(root).filter(func(e): return e["trap_group"] == null)
	var ordered: Array = _order(root_group)
	if ordered.is_empty():
		return null
	return ordered[0]["control"]
