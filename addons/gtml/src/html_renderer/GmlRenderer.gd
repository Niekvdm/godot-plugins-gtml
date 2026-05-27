@tool
class_name GmlRenderer
extends RefCounted

const GmlBindingParserScript = preload("res://addons/gtml/src/binding/GmlBindingParser.gd")
const GmlBindingApplierScript = preload("res://addons/gtml/src/binding/GmlBindingApplier.gd")
const GmlBindingExprScript = preload("res://addons/gtml/src/binding/GmlBindingExpr.gd")
const GmlBindingRegistryScript = preload("res://addons/gtml/src/binding/GmlBindingRegistry.gd")
const GmlStateScript = preload("res://addons/gtml/src/binding/GmlState.gd")

## Builds a Godot ``Control`` tree from a parsed DOM + resolved style map.
##
## The renderer is now a thin dispatcher: per-tag construction lives in the
## ``elements/`` builders, style → property translation lives in
## ``GmlDimensions`` / ``GmlWrap`` / ``GmlBackgrounds`` / ``GmlStyles``,
## resize-driven sizing lives in ``GmlPercentSizing``, and pseudo-class
## interpolation lives in ``GmlTransitionSetup`` + ``GmlTransitionManager``.


var _gml_view = null  # GmlView reference
var _styles: Dictionary = {}
var _defaults: Dictionary = {}
var _transition_manager: GmlTransitionManager = null


## Build a Control tree from the DOM root.
func build(root, styles: Dictionary, gml_view) -> Control:
	_gml_view = gml_view
	_styles = styles
	_defaults = gml_view.get_tag_defaults()
	_transition_manager = GmlTransitionManager.new()
	return _build_node(root)


func _build_context() -> Dictionary:
	return {
		"styles": _styles,
		"defaults": _defaults,
		"gml_view": _gml_view,
		"build_node": _build_node,
		"get_style": _get_node_style,
		"wrap_with_margin_padding": _wrap_with_margin_padding,
		"transition_manager": _transition_manager,
	}


## Build a single node and its children. Returns the final wrapped control.
func _build_node(node) -> Control:
	if node == null:
		return null
	if node.is_text_node:
		return _build_text_node(node)

	# v-if: omit element entirely when falsy. Scope (for v-for clones) is
	# pulled from the node's meta — empty for the normal build path.
	if node.attrs.has("v-if") and _gml_view != null and _gml_view.state != null:
		var v_if_src: String = node.attrs["v-if"]
		var v_if_scope: Dictionary = node.get_meta("_binding_scope", {})
		if not GmlBindingApplierScript.eval_v_if(v_if_src, _gml_view.state, v_if_scope):
			return null

	# v-for: expand any v-for children of this node into N siblings at THIS
	# parent's level, before the dispatched container builder iterates them.
	# This lets the parent's layout (e.g. flex-direction: row for a hotbar)
	# govern clone placement instead of forcing every v-for region into a
	# vertical host.
	_maybe_expand_v_for_children(node)

	var ctx := _build_context()
	var result: Dictionary = _dispatch(node, ctx)

	var control: Control = result.get("control")
	var inner: Control = result.get("inner", control)

	if control == null:
		return null

	_register_element_with_id(inner if inner != null else control, control, node)
	_apply_node_styles(control, node)
	GmlDimensions.apply(control, _get_node_style(node))

	# Skip transitions for Buttons (their pressed/hover styling is native).
	# For text inputs the stylebox lives on the inner LineEdit/TextEdit.
	if not (inner is Button):
		var transition_target: Control = control
		if inner is LineEdit or inner is TextEdit:
			transition_target = inner
		GmlTransitionSetup.setup(transition_target, _get_node_style(node), _transition_manager)

	# Post-build: register Vue-style bindings on the resolved control.
	_register_bindings_for_node(node, control, inner)

	return control


## Walk the node's attributes + text children and register bindings on
## the resolved control. Handles :attr, v-bind:attr, v-show, and text
## interpolation in immediate text children. v-if was handled at dispatch
## time; v-for + v-model + @event(args) live in later tasks.
func _register_bindings_for_node(node, control: Control, inner: Control = null) -> void:
	if _gml_view == null or control == null:
		return
	var registry = _gml_view._binding_registry
	if registry == null:
		return
	var state = _gml_view.state
	if state == null:
		return
	var scope: Dictionary = node.get_meta("_binding_scope", {})

	for attr_name in node.attrs:
		var cls: Dictionary = GmlBindingParserScript.classify_attribute(attr_name)
		match cls["kind"]:
			"v-bind":
				var expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				if cls["target"] == "class":
					GmlBindingApplierScript.register_class_binding(control, expr, registry, state, scope)
				else:
					GmlBindingApplierScript.register_attr_binding(control, cls["target"], expr, registry, state, scope)
			"v-show":
				var v_show_expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				GmlBindingApplierScript.register_v_show(control, v_show_expr, registry, state, scope)
			"v-model":
				# The directive's VALUE is the state key (no expression parsing).
				# Use the inner control (LineEdit, CheckBox, ...) not the wrapper.
				var v_model_key: String = node.attrs[attr_name]
				var target_ctl: Control = inner if inner != null else control
				GmlBindingApplierScript.register_v_model(target_ctl, v_model_key, registry, state, scope)
			"v-on":
				# Bare @click="handler" continues through existing element
				# builders (they emit button_clicked). Only @click="handler(args)"
				# routes here — detected by parsing the value as a call.
				var raw_value: String = node.attrs[attr_name]
				var raw_ast: Dictionary = GmlBindingExprScript.parse(raw_value)
				if raw_ast.get("type") == "call":
					GmlBindingApplierScript.register_event_with_args(control, cls["target"], raw_ast, state, scope, _gml_view)
			_:
				pass

	# Text interpolation on direct text children — only meaningful for
	# elements whose body is a single text node (e.g. <span>{{ name }}</span>).
	if control is Label and node.children.size() > 0:
		var combined: String = ""
		for child in node.children:
			if child.is_text_node:
				combined += child.text
		if "{{" in combined:
			var spans: Array = GmlBindingParserScript.find_interpolations(combined)
			GmlBindingApplierScript.register_text_interpolation(control as Label, spans, registry, state, scope)

	# v-for: if this node expanded v-for children, register a binding that
	# tears down the parent's child controls and rebuilds the full child
	# list on array change. The target container is `inner` (where the
	# dispatched builder added children); fall back to `control` if no
	# separate inner was returned.
	if node.has_meta("_v_for_keys"):
		var v_for_keys: PackedStringArray = node.get_meta("_v_for_keys")
		if v_for_keys.size() > 0:
			var rebuild_target: Control = inner if inner != null else control
			var renderer = self
			var parent_node = node
			var target_ref: WeakRef = weakref(rebuild_target)
			var rebuild_children := func():
				var t = target_ref.get_ref()
				if t == null:
					return
				for ch in t.get_children():
					t.remove_child(ch)
					ch.queue_free()
				renderer._maybe_expand_v_for_children(parent_node)
				for child_node in parent_node.children:
					var child_ctl = renderer._build_node(child_node)
					if child_ctl != null:
						t.add_child(child_ctl)
			var deps: Array = []
			for k in v_for_keys:
				deps.append(k)
			registry.register({
				"deps": deps,
				"apply": rebuild_children,
				"control_ref": target_ref,
			})


## Expand v-for children of the given parent DOM node into N siblings,
## stamping each clone with its loop-scope. Mutates parent_node.children
## but stashes the ORIGINAL template list as a meta on first call so
## subsequent re-expansions (on array change) start from the templates,
## not from the already-expanded set.
func _maybe_expand_v_for_children(parent_node) -> void:
	if _gml_view == null or _gml_view.state == null:
		return

	# Get the canonical template list — captured once and held on the
	# parent's meta. Without this, the second expansion would treat the
	# previous expansion's clones as templates and double-count.
	var originals: Array
	if parent_node.has_meta("_original_children"):
		originals = parent_node.get_meta("_original_children")
	else:
		var has_v_for: bool = false
		for c in parent_node.children:
			if not c.is_text_node and c.attrs.has("v-for"):
				has_v_for = true
				break
		if not has_v_for:
			return
		originals = parent_node.children.duplicate()
		parent_node.set_meta("_original_children", originals)

	var state = _gml_view.state
	var parent_scope: Dictionary = parent_node.get_meta("_binding_scope", {})
	var expanded: Array = []
	var v_for_keys: PackedStringArray = PackedStringArray()

	for child in originals:
		if not child.is_text_node and child.attrs.has("v-for"):
			var spec = GmlBindingApplierScript.parse_v_for(child.attrs["v-for"])
			if spec == null:
				push_warning("GmlRenderer: invalid v-for expression: %s" % child.attrs["v-for"])
				continue
			if not v_for_keys.has(spec["array_key"]):
				v_for_keys.append(spec["array_key"])
			var arr = state.get(spec["array_key"])
			if arr == null:
				continue
			if not (arr is Array):
				push_warning("GmlRenderer: v-for source '%s' is not an Array" % spec["array_key"])
				continue
			for i in (arr as Array).size():
				var item = arr[i]
				var clone = _clone_dom_node(child)
				clone.attrs.erase("v-for")
				var scope: Dictionary = parent_scope.duplicate()
				scope[spec["loop_var"]] = item
				if spec["index_var"] != "":
					scope[spec["index_var"]] = i
				_stamp_scope(clone, scope)
				expanded.append(clone)
		else:
			expanded.append(child)

	parent_node.children = expanded
	parent_node.set_meta("_v_for_keys", v_for_keys)


## Deep clone of a DOM node + all descendants. Each cloned node gets a
## fresh meta dict so the v-for caller can stamp _binding_scope on every
## descendant without polluting the template.
##
## CSS styles are resolved once at render-time and stored in _styles
## keyed by DOM node identity. v-for clones materialize AFTER that pass,
## so they would have empty styles and render as un-styled text. To fix,
## we copy the template's resolved style into _styles for each clone —
## every descendant of a v-for clone inherits its template's style entry.
func _clone_dom_node(node):
	var GmlNode = preload("res://addons/gtml/src/html_parser/GmlNode.gd")
	var clone
	if node.is_text_node:
		clone = GmlNode.create_text(node.text)
	else:
		clone = GmlNode.create_element(node.tag, node.attrs.duplicate())
	if _styles.has(node):
		_styles[clone] = _styles[node]
	for child in node.children:
		clone.children.append(_clone_dom_node(child))
	return clone


## Stamp the given scope dict onto a cloned node + every descendant. Used
## by v-for so {{ item.name }} in a text child resolves against the loop
## variable rather than the global state.
func _stamp_scope(node, scope: Dictionary) -> void:
	node.set_meta("_binding_scope", scope)
	for child in node.children:
		_stamp_scope(child, scope)


## Tag → element builder dispatch table.
func _dispatch(node, ctx: Dictionary) -> Dictionary:
	match node.tag:
		"div", "section", "header", "footer", "nav", "main", "article", "aside", "form", "_root":
			return GmlContainerBuilder.build_div(node, ctx)
		"p":
			return GmlTextBuilder.build_paragraph(node, ctx)
		"span":
			return GmlTextBuilder.build_span(node, ctx)
		"h1", "h2", "h3", "h4", "h5", "h6":
			var level: int = int(node.tag.substr(1))
			return GmlTextBuilder.build_heading(node, level, ctx)
		"label":
			return GmlTextBuilder.build_label(node, ctx)
		"strong", "b":
			var ctl = GmlTextBuilder.build_bold(node, ctx)
			return {"control": ctl, "inner": ctl}
		"em", "i":
			var ctl2 = GmlTextBuilder.build_italic(node, ctx)
			return {"control": ctl2, "inner": ctl2}
		"button":
			return GmlButtonBuilder.build_button(node, ctx)
		"input":
			return GmlInputBuilder.build_input(node, ctx)
		"textarea":
			return GmlInputBuilder.build_textarea(node, ctx)
		"select":
			return GmlInputBuilder.build_select(node, ctx)
		"option":
			return {"control": null, "inner": null}  # handled by parent <select>
		"img":
			return GmlMediaBuilder.build_image(node, ctx)
		"br":
			var br_ctl = GmlMediaBuilder.build_line_break()
			return {"control": br_ctl, "inner": br_ctl}
		"hr":
			return GmlMediaBuilder.build_horizontal_rule(node, ctx)
		"progress":
			return GmlMediaBuilder.build_progress(node, ctx)
		"svg":
			return GmlMediaBuilder.build_svg(node, ctx)
		"ul":
			return GmlListBuilder.build_list(node, false, ctx)
		"ol":
			return GmlListBuilder.build_list(node, true, ctx)
		"li":
			return GmlListBuilder.build_list_item(node, ctx)
		"a":
			return GmlAnchorBuilder.build_anchor(node, ctx)
		_:
			push_warning("GmlRenderer: unknown tag '%s', treating as div" % node.tag)
			return GmlContainerBuilder.build_div(node, ctx)


func _build_text_node(node) -> Control:
	var text: String = node.text.strip_edges()
	if text.is_empty():
		return null

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _defaults.get("p_font_size", 16))
	label.add_theme_color_override("font_color", _defaults.get("default_font_color", Color.WHITE))

	# Text interpolation: if the literal text contains {{ }} markers,
	# register a binding that re-renders the label whenever any of its
	# dep keys change. Scope (for v-for clones) is read from node meta
	# stamped during clone.
	if "{{" in text and _gml_view != null and _gml_view.state != null:
		var registry = _gml_view._binding_registry
		if registry != null:
			var scope: Dictionary = node.get_meta("_binding_scope", {})
			var spans: Array = GmlBindingParserScript.find_interpolations(text)
			GmlBindingApplierScript.register_text_interpolation(label, spans, registry, _gml_view.state, scope)

	return label


## Register an element with the GmlView so consumers can look it up.
##   - ``aria-node`` becomes Control.name (accessible identification)
##   - ``title`` becomes tooltip_text
##   - ``id`` is used for GmlView.get_element_by_id() lookups
func _register_element_with_id(inner_control: Control, wrapper_control: Control, node) -> void:
	var aria_node: String = node.get_attr("aria-node", "")
	if not aria_node.is_empty():
		inner_control.name = aria_node

	var title: String = node.get_attr("title", "")
	if not title.is_empty():
		inner_control.tooltip_text = title

	var id: String = node.get_id()
	if id.is_empty():
		return
	if aria_node.is_empty():
		inner_control.name = id
	if _gml_view != null:
		_gml_view.register_element(id, inner_control, wrapper_control)


func _get_node_style(node) -> Dictionary:
	if _styles.has(node):
		return _styles[node]
	return {}


## Apply visual styles that act on the wrapper control directly (background
## color when no dedicated stylebox is in play, opacity, visibility, overflow).
## Layout/dimension props are GmlDimensions' job; container chrome is GmlWrap's.
func _apply_node_styles(control: Control, node) -> void:
	var style := _get_node_style(node)

	if style.has("background-color") and not (control is PanelContainer) and not (control is Button):
		_apply_background_color(control, style["background-color"])

	if style.has("opacity"):
		control.modulate.a = clampf(style["opacity"], 0.0, 1.0)

	if style.has("visibility") and style["visibility"] == "hidden":
		control.modulate.a = 0.0

	if style.has("display") and style["display"] == "none":
		control.visible = false

	if style.has("overflow"):
		match style["overflow"]:
			"hidden":
				control.clip_contents = true
			"visible":
				control.clip_contents = false


func _apply_background_color(control: Control, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", box)
	elif control is Button:
		control.add_theme_stylebox_override("normal", box)


## Thin shim around GmlWrap so element builders keep their existing call site.
func _wrap_with_margin_padding(control: Control, style: Dictionary) -> Control:
	return GmlWrap.apply(control, style)
