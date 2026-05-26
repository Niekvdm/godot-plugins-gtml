@tool
class_name GmlRenderer
extends RefCounted

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

	return control


## Tag → element builder dispatch table.
func _dispatch(node, ctx: Dictionary) -> Dictionary:
	match node.tag:
		"div", "section", "header", "footer", "nav", "main", "article", "aside", "form", "_root":
			return GmlContainerElements.build_div(node, ctx)
		"p":
			return GmlTextElements.build_paragraph(node, ctx)
		"span":
			return GmlTextElements.build_span(node, ctx)
		"h1", "h2", "h3", "h4", "h5", "h6":
			var level: int = int(node.tag.substr(1))
			return GmlTextElements.build_heading(node, level, ctx)
		"label":
			return GmlTextElements.build_label(node, ctx)
		"strong", "b":
			var ctl = GmlTextElements.build_bold(node, ctx)
			return {"control": ctl, "inner": ctl}
		"em", "i":
			var ctl2 = GmlTextElements.build_italic(node, ctx)
			return {"control": ctl2, "inner": ctl2}
		"button":
			return GmlButtonElements.build_button(node, ctx)
		"input":
			return GmlInputElements.build_input(node, ctx)
		"textarea":
			return GmlInputElements.build_textarea(node, ctx)
		"select":
			return GmlInputElements.build_select(node, ctx)
		"option":
			return {"control": null, "inner": null}  # handled by parent <select>
		"img":
			return GmlMediaElements.build_image(node, ctx)
		"br":
			var br_ctl = GmlMediaElements.build_line_break()
			return {"control": br_ctl, "inner": br_ctl}
		"hr":
			return GmlMediaElements.build_horizontal_rule(node, ctx)
		"progress":
			return GmlMediaElements.build_progress(node, ctx)
		"svg":
			return GmlMediaElements.build_svg(node, ctx)
		"ul":
			return GmlListElements.build_list(node, false, ctx)
		"ol":
			return GmlListElements.build_list(node, true, ctx)
		"li":
			return GmlListElements.build_list_item(node, ctx)
		"a":
			return GmlAnchorElements.build_anchor(node, ctx)
		_:
			push_warning("GmlRenderer: unknown tag '%s', treating as div" % node.tag)
			return GmlContainerElements.build_div(node, ctx)


func _build_text_node(node) -> Control:
	var text: String = node.text.strip_edges()
	if text.is_empty():
		return null

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _defaults.get("p_font_size", 16))
	label.add_theme_color_override("font_color", _defaults.get("default_font_color", Color.WHITE))
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
