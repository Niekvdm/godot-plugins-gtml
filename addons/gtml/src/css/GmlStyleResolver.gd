class_name GmlStyleResolver
extends RefCounted

## Resolves CSS rules to DOM nodes.
## Matches selectors and merges styles with proper cascade priority.
##
## Priority (lowest to highest): tag < class < id
## Pseudo-classes (:hover, :active, :focus) are resolved separately.

## Resolve all styles for a DOM tree.
## Returns a Dictionary mapping GmlNode -> style Dictionary.
## The style Dictionary contains:
##   - Regular properties at the top level
##   - "_hover" key with hover-specific properties (if any)
##   - "_active" key with active-specific properties (if any)
##   - "_focus" key with focus-specific properties (if any)
func resolve(root, rules: Array) -> Dictionary:
	var styles: Dictionary = {}
	_resolve_node(root, rules, styles)
	return styles


## Recursively resolve styles for a node and its children.
func _resolve_node(node, rules: Array, styles: Dictionary) -> void:
	if node == null or node.is_text_node:
		return

	# Compute style for this node (including pseudo-class styles)
	var computed_style := _compute_style(node, rules)
	if not computed_style.is_empty():
		styles[node] = computed_style

	# Process children
	for child in node.children:
		_resolve_node(child, rules, styles)


## Compute the final style for a single node.
func _compute_style(node, rules: Array) -> Dictionary:
	var style: Dictionary = {}
	var hover_style: Dictionary = {}
	var active_style: Dictionary = {}
	var focus_style: Dictionary = {}

	# Apply rules in cascade order: tag < class < id

	# 1. Tag rules
	for rule in rules:
		if rule.selector_type == "tag" and rule.selector_value == node.tag:
			_apply_rule_by_pseudo(rule, style, hover_style, active_style, focus_style)

	# 2. Class rules
	var classes = node.get_classes()
	for rule in rules:
		if rule.selector_type == "class" and rule.selector_value in classes:
			_apply_rule_by_pseudo(rule, style, hover_style, active_style, focus_style)

	# 3. ID rules
	var id = node.get_id()
	if not id.is_empty():
		for rule in rules:
			if rule.selector_type == "id" and rule.selector_value == id:
				_apply_rule_by_pseudo(rule, style, hover_style, active_style, focus_style)

	# Add pseudo-class styles as nested dictionaries
	if not hover_style.is_empty():
		style["_hover"] = hover_style
	if not active_style.is_empty():
		style["_active"] = active_style
	if not focus_style.is_empty():
		style["_focus"] = focus_style

	return style


## Apply a rule to the appropriate style dictionary based on pseudo-class.
func _apply_rule_by_pseudo(rule, style: Dictionary, hover_style: Dictionary, active_style: Dictionary, focus_style: Dictionary) -> void:
	match rule.pseudo_class:
		"hover":
			_merge_properties(hover_style, rule.properties)
		"active":
			_merge_properties(active_style, rule.properties)
		"focus":
			_merge_properties(focus_style, rule.properties)
		"":
			# No pseudo-class - apply to base style
			_merge_properties(style, rule.properties)
		_:
			# Unknown pseudo-class - apply to base style with warning
			push_warning("GmlStyleResolver: Unknown pseudo-class ':%s'" % rule.pseudo_class)
			_merge_properties(style, rule.properties)


## Merge properties from source into target.
func _merge_properties(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = source[key]
