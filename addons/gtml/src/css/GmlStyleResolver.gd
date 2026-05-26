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
##
## Single-pseudo rules land in legacy flat keys (``_hover``, ``_focus``,
## ``_active``, ``_disabled``) so the existing transition path keeps working
## unchanged. Multi-pseudo rules (e.g. ``a:hover:focus``) land in a combined
## bucket keyed by ``_`` + sorted pseudos joined with ``+`` (so
## ``a:hover:focus`` and ``a:focus:hover`` produce the same ``_focus+hover``
## key). A rule whose pseudo set contains any unknown state pseudo is dropped
## with a warning — see test_multi_pseudo.
func _compute_style(node, ancestor_chain: Array, rules: Array) -> Dictionary:
	var matches: Array = []

	for rule in rules:
		if rule.selector == null:
			continue
		if not GmlSelector.matches(rule.selector, ancestor_chain):
			continue
		matches.append({
			"rule": rule,
			"specificity": rule.specificity(),
			"source_index": rule.source_index,
		})

	if matches.is_empty():
		return {}

	matches.sort_custom(_compare_matches)

	var style: Dictionary = {}
	var state_buckets: Dictionary = {}  # bucket_key -> Dict

	for m in matches:
		var props: Dictionary = m["rule"].properties
		var sps := _state_pseudos_of(m["rule"].selector)

		if sps.is_empty():
			_merge_properties(style, props)
			continue

		# Reject rules whose pseudo list contains any unknown name. Routing
		# such a rule into a known bucket would silently change the visual
		# behavior; dropping it surfaces the typo via push_warning.
		var unknown_pseudo: String = ""
		for p in sps:
			if not (p in GmlSelector.STATE_PSEUDOS):
				unknown_pseudo = p
				break
		if not unknown_pseudo.is_empty():
			push_warning("GmlStyleResolver: unknown pseudo-class ':%s' — rule dropped" % unknown_pseudo)
			continue

		var sorted_pseudos := sps.duplicate()
		sorted_pseudos.sort()
		var bucket_key: String = "+".join(sorted_pseudos)
		if not state_buckets.has(bucket_key):
			state_buckets[bucket_key] = {}
		_merge_properties(state_buckets[bucket_key], props)

	for key in state_buckets:
		style["_" + key] = state_buckets[key]

	return style


## All state pseudos on the selector's rightmost compound, in source order.
## Anything not in STATE_PSEUDOS is returned as-is so the caller can detect
## unknowns and drop the rule.
static func _state_pseudos_of(sel) -> PackedStringArray:
	if sel == null or sel.compounds.is_empty():
		return PackedStringArray()
	var last = sel.compounds[sel.compounds.size() - 1]
	return last.pseudos.duplicate()


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
