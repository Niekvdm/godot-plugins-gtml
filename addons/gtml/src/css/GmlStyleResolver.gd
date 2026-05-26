class_name GmlStyleResolver
extends RefCounted

## Resolves CSS rules against a DOM tree using the v0.2 selector engine.
##
## For each node we collect all rules whose selector matches that node, then
## sort by (specificity, source order) and merge properties in increasing
## priority so later wins. Pseudo-class rules (``:hover`` / ``:active`` /
## ``:focus``) feed dedicated sub-dictionaries so the renderer can swap them
## in based on runtime input state.


## Resolve all styles for a DOM tree.
## Returns ``Dictionary[GmlNode -> Dictionary]`` where the value is the merged
## style for that node, with ``_hover`` / ``_active`` / ``_focus`` sub-dicts
## holding pseudo-class overrides.
func resolve(root, rules: Array) -> Dictionary:
	var styles: Dictionary = {}
	_resolve_node(root, [], rules, styles)
	return styles


func _resolve_node(node, ancestor_chain: Array, rules: Array, styles: Dictionary) -> void:
	if node == null or node.is_text_node:
		return

	var chain := ancestor_chain.duplicate()
	chain.append(node)

	var computed := _compute_style(node, chain, rules)
	if not computed.is_empty():
		styles[node] = computed

	for child in node.children:
		_resolve_node(child, chain, rules, styles)


## Walks all rules, gathers the matching ones for ``node``, sorts them by
## (specificity, source_index), and merges them into one final style dict.
func _compute_style(node, ancestor_chain: Array, rules: Array) -> Dictionary:
	var matches: Array = []  # Array of {rule, specificity, pseudo}

	for rule in rules:
		if rule.selector == null:
			continue
		if not GmlSelector.matches(rule.selector, ancestor_chain):
			continue
		# Use the rightmost compound's pseudo to decide the style bucket.
		# Multi-pseudo (a:hover:focus) is deferred to v0.3 — we currently route
		# such rules to the first pseudo's bucket.
		var pseudo := _primary_pseudo(rule.selector)
		matches.append({
			"rule": rule,
			"specificity": rule.specificity(),
			"pseudo": pseudo,
			"source_index": rule.source_index,
		})

	if matches.is_empty():
		return {}

	matches.sort_custom(_compare_matches)

	var style: Dictionary = {}
	var hover_style: Dictionary = {}
	var active_style: Dictionary = {}
	var focus_style: Dictionary = {}
	var disabled_style: Dictionary = {}

	for m in matches:
		var props: Dictionary = m["rule"].properties
		match m["pseudo"]:
			"":
				_merge_properties(style, props)
			"hover":
				_merge_properties(hover_style, props)
			"active":
				_merge_properties(active_style, props)
			"focus":
				_merge_properties(focus_style, props)
			"disabled":
				_merge_properties(disabled_style, props)
			_:
				# Drop unknown pseudo rules — merging them into the base style
				# would let a typo like :hovr silently overwrite the un-hovered
				# appearance. Warn the developer so the typo is visible.
				push_warning("GmlStyleResolver: unknown pseudo-class ':%s' — rule dropped" % m["pseudo"])

	if not hover_style.is_empty():
		style["_hover"] = hover_style
	if not active_style.is_empty():
		style["_active"] = active_style
	if not focus_style.is_empty():
		style["_focus"] = focus_style
	if not disabled_style.is_empty():
		style["_disabled"] = disabled_style

	return style


static func _primary_pseudo(sel) -> String:
	if sel == null or sel.compounds.is_empty():
		return ""
	var last = sel.compounds[sel.compounds.size() - 1]
	if last.pseudos.is_empty():
		return ""
	return last.pseudos[0]


## Order rules so the highest-priority is last (so the final merge wins).
## Priority: specificity tuple ascending, then source_index ascending.
static func _compare_matches(a: Dictionary, b: Dictionary) -> bool:
	var sa: Vector3i = a["specificity"]
	var sb: Vector3i = b["specificity"]
	if sa.x != sb.x:
		return sa.x < sb.x
	if sa.y != sb.y:
		return sa.y < sb.y
	if sa.z != sb.z:
		return sa.z < sb.z
	return a["source_index"] < b["source_index"]


static func _merge_properties(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = source[key]
