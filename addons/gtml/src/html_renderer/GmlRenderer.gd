@tool
class_name GmlRenderer
extends RefCounted

## Renders a GmlNode tree into Godot Control nodes.
## Applies styles from CSS and defaults from GmlView.
## Delegates element building to specialized element modules.

var _gml_view = null  # GmlView reference
var _styles: Dictionary = {}
var _defaults: Dictionary = {}


## Build a Control tree from the DOM root.
func build(root, styles: Dictionary, gml_view) -> Control:
	_gml_view = gml_view
	_styles = styles
	_defaults = gml_view.get_tag_defaults()

	return _build_node(root)


## Build the context dictionary passed to element builders.
func _build_context() -> Dictionary:
	return {
		"styles": _styles,
		"defaults": _defaults,
		"gml_view": _gml_view,
		"build_node": _build_node,
		"get_style": _get_node_style,
		"wrap_with_margin_padding": _wrap_with_margin_padding,
	}


## Build a single node and its children.
## Returns the final wrapped control.
func _build_node(node) -> Control:
	if node == null:
		return null

	if node.is_text_node:
		return _build_text_node(node)

	var ctx := _build_context()
	var result: Dictionary = {"control": null, "inner": null}

	match node.tag:
		# Container elements
		"div", "section", "header", "footer", "nav", "main", "article", "aside", "form", "_root":
			result = GmlContainerElements.build_div(node, ctx)

		# Text elements
		"p":
			result = GmlTextElements.build_paragraph(node, ctx)
		"span":
			result = GmlTextElements.build_span(node, ctx)
		"h1":
			result = GmlTextElements.build_heading(node, 1, ctx)
		"h2":
			result = GmlTextElements.build_heading(node, 2, ctx)
		"h3":
			result = GmlTextElements.build_heading(node, 3, ctx)
		"h4":
			result = GmlTextElements.build_heading(node, 4, ctx)
		"h5":
			result = GmlTextElements.build_heading(node, 5, ctx)
		"h6":
			result = GmlTextElements.build_heading(node, 6, ctx)
		"label":
			result = GmlTextElements.build_label(node, ctx)
		"strong", "b":
			var control = GmlTextElements.build_bold(node, ctx)
			result = {"control": control, "inner": control}
		"em", "i":
			var control = GmlTextElements.build_italic(node, ctx)
			result = {"control": control, "inner": control}

		# Button elements
		"button":
			result = GmlButtonElements.build_button(node, ctx)

		# Input elements
		"input":
			result = GmlInputElements.build_input(node, ctx)
		"textarea":
			result = GmlInputElements.build_textarea(node, ctx)
		"select":
			result = GmlInputElements.build_select(node, ctx)
		"option":
			# Options are handled within select, skip standalone
			result = {"control": null, "inner": null}

		# Media elements
		"img":
			result = GmlMediaElements.build_image(node, ctx)
		"br":
			var control = GmlMediaElements.build_line_break()
			result = {"control": control, "inner": control}
		"hr":
			result = GmlMediaElements.build_horizontal_rule(node, ctx)
		"progress":
			result = GmlMediaElements.build_progress(node, ctx)
		"svg":
			result = GmlMediaElements.build_svg(node, ctx)

		# List elements
		"ul":
			result = GmlListElements.build_list(node, false, ctx)
		"ol":
			result = GmlListElements.build_list(node, true, ctx)
		"li":
			result = GmlListElements.build_list_item(node, ctx)

		# Anchor elements
		"a":
			result = GmlAnchorElements.build_anchor(node, ctx)

		_:
			# Unknown tag - treat as div
			push_warning("GmlRenderer: Unknown tag '%s', treating as div" % node.tag)
			result = GmlContainerElements.build_div(node, ctx)

	var control = result.get("control")
	var inner = result.get("inner", control)

	if control != null:
		# Register the element with GmlView - pass both inner and wrapper
		_register_element_with_id(inner if inner != null else control, control, node)
		# Apply styles to the WRAPPER control (for visibility, dimensions, etc.)
		_apply_node_styles(control, node)
		_apply_dimensions(control, node)

	return control


## Build a text node.
func _build_text_node(node) -> Control:
	var text = node.text.strip_edges()
	if text.is_empty():
		return null

	var label := Label.new()
	label.text = text

	var font_size: int = _defaults.get("p_font_size", 16)
	label.add_theme_font_size_override("font_size", font_size)

	var color: Color = _defaults.get("default_font_color", Color.WHITE)
	label.add_theme_color_override("font_color", color)

	return label


## Register an element with the GmlView, tracking both inner control and wrapper.
func _register_element_with_id(inner_control: Control, wrapper_control: Control, node) -> void:
	var id = node.get_id()
	if not id.is_empty():
		inner_control.name = id
		if _gml_view != null:
			_gml_view.register_element(id, inner_control, wrapper_control)


## Get the resolved style for a node.
func _get_node_style(node) -> Dictionary:
	if _styles.has(node):
		return _styles[node]
	return {}


## Apply node-specific styles.
func _apply_node_styles(control: Control, node) -> void:
	var style = _get_node_style(node)

	# Background color (skip for controls with dedicated styling)
	if style.has("background-color") and not (control is PanelContainer) and not (control is Button):
		_apply_background_color(control, style["background-color"])

	# Opacity
	if style.has("opacity"):
		control.modulate.a = clampf(style["opacity"], 0.0, 1.0)

	# Visibility
	if style.has("visibility"):
		match style["visibility"]:
			"hidden":
				control.modulate.a = 0.0

	# Display none
	if style.has("display") and style["display"] == "none":
		control.visible = false

	# Overflow
	if style.has("overflow"):
		match style["overflow"]:
			"hidden":
				control.clip_contents = true
			"visible":
				control.clip_contents = false


## Apply width and height dimensions to a control.
func _apply_dimensions(control: Control, node) -> void:
	var style = _get_node_style(node)

	var width_percent := -1.0
	var height_percent := -1.0

	# Apply width
	if style.has("width"):
		var width_dim = style["width"]
		if width_dim is Dictionary:
			match width_dim.get("unit", ""):
				"%":
					width_percent = width_dim["value"] / 100.0
					if width_dim["value"] >= 100:
						control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					else:
						control.set_meta("width_percent", width_percent)
				"px":
					control.custom_minimum_size.x = width_dim["value"]

	# Apply height
	if style.has("height"):
		var height_dim = style["height"]
		if height_dim is Dictionary:
			match height_dim.get("unit", ""):
				"%":
					height_percent = height_dim["value"] / 100.0
					if height_dim["value"] >= 100:
						control.size_flags_vertical = Control.SIZE_EXPAND_FILL
					else:
						control.set_meta("height_percent", height_percent)
				"px":
					var height_val: float = height_dim["value"]
					control.custom_minimum_size.y = height_val
					if height_val <= 0:
						control.visible = false

	# Set up percentage sizing
	if (width_percent > 0 and width_percent < 1.0) or (height_percent > 0 and height_percent < 1.0):
		if width_percent > 0 and width_percent < 1.0:
			control.set_meta("width_percent", width_percent)
		if height_percent > 0 and height_percent < 1.0:
			control.set_meta("height_percent", height_percent)

		var control_ref = weakref(control)
		control.tree_entered.connect(func():
			var ctrl = control_ref.get_ref()
			if ctrl == null or not is_instance_valid(ctrl):
				return
			ctrl.get_tree().process_frame.connect(func():
				var ctrl2 = control_ref.get_ref()
				if ctrl2 != null and is_instance_valid(ctrl2):
					_setup_percent_sizing(ctrl2)
			, CONNECT_ONE_SHOT)
		, CONNECT_ONE_SHOT)

	# Apply min-width
	if style.has("min-width"):
		var dim = style["min-width"]
		if dim is Dictionary and dim.get("unit", "") == "px":
			control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, dim["value"])

	# Apply min-height
	if style.has("min-height"):
		var dim = style["min-height"]
		if dim is Dictionary and dim.get("unit", "") == "px":
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, dim["value"])

	# Apply max-width/max-height
	var has_max_width := false
	var has_max_height := false
	if style.has("max-width"):
		var dim = style["max-width"]
		if dim is Dictionary:
			has_max_width = true
			match dim.get("unit", ""):
				"px":
					control.set_meta("max_width", dim["value"])
					control.custom_minimum_size.x = minf(control.custom_minimum_size.x, dim["value"])
				"%":
					control.set_meta("max_width_percent", dim["value"] / 100.0)

	if style.has("max-height"):
		var dim = style["max-height"]
		if dim is Dictionary:
			has_max_height = true
			match dim.get("unit", ""):
				"px":
					control.set_meta("max_height", dim["value"])
					control.custom_minimum_size.y = minf(control.custom_minimum_size.y, dim["value"])
				"%":
					control.set_meta("max_height_percent", dim["value"] / 100.0)

	if has_max_width or has_max_height:
		var max_control_ref = weakref(control)
		control.tree_entered.connect(func():
			var ctrl = max_control_ref.get_ref()
			if ctrl == null or not is_instance_valid(ctrl):
				return
			ctrl.get_tree().process_frame.connect(func():
				var ctrl2 = max_control_ref.get_ref()
				if ctrl2 != null and is_instance_valid(ctrl2):
					_setup_max_size_enforcement(ctrl2)
			, CONNECT_ONE_SHOT)
		, CONNECT_ONE_SHOT)

	# Apply flex-grow (axis-aware based on parent's flex-direction)
	if style.has("flex-grow"):
		var grow: float = style["flex-grow"]
		if grow > 0:
			var parent = control.get_parent()
			var is_row = parent.get_meta("is_row_layout", false) if parent else false
			if is_row:
				control.size_flags_horizontal |= Control.SIZE_EXPAND
			else:
				control.size_flags_vertical |= Control.SIZE_EXPAND
			control.size_flags_stretch_ratio = grow

	# Apply flex-shrink (axis-aware based on parent's flex-direction)
	if style.has("flex-shrink"):
		var shrink: float = style["flex-shrink"]
		var parent = control.get_parent()
		var is_row = parent.get_meta("is_row_layout", false) if parent else false

		if shrink == 0:
			# Prevent shrinking by using SIZE_SHRINK_BEGIN (don't expand, don't shrink)
			if is_row:
				control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			else:
				control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		# shrink > 0 is default behavior (allow container to shrink children)

	# For 100% dimensions, use size flags
	if width_percent >= 1.0 and height_percent >= 1.0:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif width_percent >= 1.0:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif height_percent >= 1.0:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL


## Set up percentage-based sizing for a control.
func _setup_percent_sizing(control: Control) -> void:
	if not is_instance_valid(control):
		return

	var parent = control.get_parent()
	if parent == null or not (parent is Control):
		return

	if not parent.resized.is_connected(_on_parent_resized.bind(control)):
		parent.resized.connect(_on_parent_resized.bind(control))

	var gml_view = _find_gml_view(control)
	if gml_view != null and not gml_view.resized.is_connected(_on_parent_resized.bind(control)):
		gml_view.resized.connect(_on_parent_resized.bind(control))

	_update_percent_size(control)


func _find_gml_view(control: Control) -> Control:
	var current = control.get_parent()
	while current != null:
		if current.get_script() != null and current.get_script().resource_path.ends_with("GmlView.gd"):
			return current
		current = current.get_parent()
	return null


func _on_parent_resized(control: Control) -> void:
	if is_instance_valid(control):
		_update_percent_size(control)


func _update_percent_size(control: Control) -> void:
	if not is_instance_valid(control):
		return

	var ref_size := Vector2.ZERO
	var gml_view = _find_gml_view(control)
	if gml_view != null:
		ref_size = gml_view.size
	else:
		var parent = control.get_parent()
		if parent is Control:
			ref_size = parent.size

	if ref_size == Vector2.ZERO:
		return

	var width_percent = control.get_meta("width_percent", -1.0)
	var height_percent = control.get_meta("height_percent", -1.0)
	var new_size := control.custom_minimum_size

	if width_percent > 0 and width_percent < 1.0:
		new_size.x = ref_size.x * width_percent

	if height_percent > 0 and height_percent < 1.0:
		new_size.y = ref_size.y * height_percent

	# Apply max constraints
	var max_width = control.get_meta("max_width", -1.0)
	var max_width_pct = control.get_meta("max_width_percent", -1.0)
	if max_width_pct > 0:
		var pct_max = ref_size.x * max_width_pct
		max_width = minf(max_width, pct_max) if max_width > 0 else pct_max
	if max_width > 0 and new_size.x > max_width:
		new_size.x = max_width

	var max_height = control.get_meta("max_height", -1.0)
	var max_height_pct = control.get_meta("max_height_percent", -1.0)
	if max_height_pct > 0:
		var pct_max = ref_size.y * max_height_pct
		max_height = minf(max_height, pct_max) if max_height > 0 else pct_max
	if max_height > 0 and new_size.y > max_height:
		new_size.y = max_height

	control.custom_minimum_size = new_size
	control.size = new_size


func _setup_max_size_enforcement(control: Control) -> void:
	if not is_instance_valid(control):
		return

	if not control.resized.is_connected(_enforce_max_size.bind(control)):
		control.resized.connect(_enforce_max_size.bind(control))

	var parent = control.get_parent()
	if parent is Control and not parent.resized.is_connected(_enforce_max_size.bind(control)):
		parent.resized.connect(_enforce_max_size.bind(control))

	_enforce_max_size(control)


func _enforce_max_size(control: Control) -> void:
	if not is_instance_valid(control):
		return

	var max_w := control.get_meta("max_width", -1.0) as float
	var max_h := control.get_meta("max_height", -1.0) as float
	var max_w_pct := control.get_meta("max_width_percent", -1.0) as float
	var max_h_pct := control.get_meta("max_height_percent", -1.0) as float

	if max_w_pct > 0 or max_h_pct > 0:
		var ref_size := Vector2.ZERO
		var gml_view = _find_gml_view(control)
		if gml_view != null:
			ref_size = gml_view.size
		else:
			var parent = control.get_parent()
			if parent is Control:
				ref_size = parent.size

		if ref_size != Vector2.ZERO:
			if max_w_pct > 0:
				var pct_max_w = ref_size.x * max_w_pct
				max_w = minf(max_w, pct_max_w) if max_w > 0 else pct_max_w
			if max_h_pct > 0:
				var pct_max_h = ref_size.y * max_h_pct
				max_h = minf(max_h, pct_max_h) if max_h > 0 else pct_max_h

	if max_w > 0 or max_h > 0:
		var new_size := control.size
		var new_min := control.custom_minimum_size

		if max_w > 0:
			new_size.x = minf(new_size.x, max_w)
			new_min.x = minf(new_min.x, max_w)
		if max_h > 0:
			new_size.y = minf(new_size.y, max_h)
			new_min.y = minf(new_min.y, max_h)

		control.custom_minimum_size = new_min
		control.size = new_size


## Apply background color using a StyleBoxFlat.
func _apply_background_color(control: Control, color: Color) -> void:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = color

	if control is PanelContainer:
		control.add_theme_stylebox_override("panel", style_box)
	elif control is Button:
		control.add_theme_stylebox_override("normal", style_box)


## Wrap a control with margin/padding containers if needed.
func _wrap_with_margin_padding(control: Control, style: Dictionary) -> Control:
	var has_margin = style.has("margin") and style["margin"] > 0 \
		or style.has("margin-top") or style.has("margin-right") or style.has("margin-bottom") or style.has("margin-left")
	var has_padding = style.has("padding") and style["padding"] > 0 \
		or style.has("padding-top") or style.has("padding-right") or style.has("padding-bottom") or style.has("padding-left")
	var has_bg = style.has("background-color")
	var has_gradient = style.has("background") or style.has("background-image")
	var has_border = style.has("border") or style.has("border-width") or style.has("border-radius") \
		or style.has("border-top") or style.has("border-right") or style.has("border-bottom") or style.has("border-left") \
		or style.has("border-top-width") or style.has("border-right-width") or style.has("border-bottom-width") or style.has("border-left-width") \
		or style.has("box-shadow")
	var has_scroll = style.get("overflow", "") in ["scroll", "auto"] \
		or style.get("overflow-y", "") in ["scroll", "auto"] \
		or style.get("overflow-x", "") in ["scroll", "auto"]

	if not has_margin and not has_padding and not has_bg and not has_gradient and not has_border and not has_scroll:
		return control

	var result := control

	# Apply padding
	if has_padding:
		var base_padding: int = style.get("padding", 0)
		var padding_container := MarginContainer.new()
		padding_container.add_theme_constant_override("margin_left", style.get("padding-left", base_padding))
		padding_container.add_theme_constant_override("margin_right", style.get("padding-right", base_padding))
		padding_container.add_theme_constant_override("margin_top", style.get("padding-top", base_padding))
		padding_container.add_theme_constant_override("margin_bottom", style.get("padding-bottom", base_padding))
		padding_container.add_child(result)
		result = padding_container

	# Apply gradient background
	var gradient_applied := false
	if has_gradient:
		var bg_data = style.get("background", style.get("background-image", {}))
		if bg_data is Dictionary and bg_data.get("type", "") in ["linear-gradient", "radial-gradient", "image"]:
			var gradient_control = _create_gradient_background(bg_data, style)
			if gradient_control != null:
				gradient_control.add_child(result)
				result = gradient_control
				gradient_applied = true

	# Apply background color AND border
	if (has_bg or has_border) and not gradient_applied:
		var panel := PanelContainer.new()
		var style_box := StyleBoxFlat.new()

		if has_bg:
			style_box.bg_color = style["background-color"]
		else:
			style_box.bg_color = Color.TRANSPARENT

		if has_border:
			GmlStyles.apply_border_to_stylebox(style_box, style)

		panel.add_theme_stylebox_override("panel", style_box)
		panel.add_child(result)
		result = panel

	# Apply border on top of gradient if needed
	if gradient_applied and has_border:
		var border_panel := PanelContainer.new()
		var border_style_box := StyleBoxFlat.new()
		border_style_box.bg_color = Color.TRANSPARENT
		GmlStyles.apply_border_to_stylebox(border_style_box, style)
		border_panel.add_theme_stylebox_override("panel", border_style_box)
		border_panel.add_child(result)
		result = border_panel

	# Apply margin
	if has_margin:
		var base_margin: int = style.get("margin", 0)
		var margin_container := MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", style.get("margin-left", base_margin))
		margin_container.add_theme_constant_override("margin_right", style.get("margin-right", base_margin))
		margin_container.add_theme_constant_override("margin_top", style.get("margin-top", base_margin))
		margin_container.add_theme_constant_override("margin_bottom", style.get("margin-bottom", base_margin))
		margin_container.add_child(result)
		result = margin_container

	# Apply scroll
	if has_scroll:
		var scroll_container := ScrollContainer.new()
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var overflow = style.get("overflow", "")
		var overflow_x = style.get("overflow-x", overflow)
		var overflow_y = style.get("overflow-y", overflow)

		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if overflow_x in ["scroll", "auto"] else ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if overflow_y in ["scroll", "auto"] else ScrollContainer.SCROLL_MODE_DISABLED

		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		result.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if overflow_y in ["scroll", "auto"] else Control.SIZE_EXPAND_FILL

		scroll_container.follow_focus = true
		scroll_container.add_child(result)
		result = scroll_container

	return result


## Create a gradient background control.
func _create_gradient_background(bg_data: Dictionary, style: Dictionary) -> Control:
	var bg_type = bg_data.get("type", "")

	match bg_type:
		"linear-gradient":
			return _create_linear_gradient_control(bg_data, style)
		"radial-gradient":
			return _create_radial_gradient_control(bg_data, style)
		"image":
			return _create_image_background_control(bg_data, style)
		_:
			return null


func _create_linear_gradient_control(bg_data: Dictionary, style: Dictionary) -> Control:
	var colors: Array = bg_data.get("colors", [])
	var offsets: Array = bg_data.get("offsets", [])
	var angle: float = bg_data.get("angle", 180.0)

	if colors.size() < 2:
		push_warning("GmlRenderer: Linear gradient needs at least 2 colors")
		return null

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	gradient_texture.height = 256
	GmlStyles.apply_gradient_angle(gradient_texture, angle)

	var container := PanelContainer.new()
	var texture_rect := TextureRect.new()
	texture_rect.texture = gradient_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	container.add_child(texture_rect)
	container.move_child(texture_rect, 0)

	if style.has("border-radius") or style.has("border-top-left-radius"):
		container.clip_contents = true

	return container


func _create_radial_gradient_control(bg_data: Dictionary, style: Dictionary) -> Control:
	var colors: Array = bg_data.get("colors", [])
	var offsets: Array = bg_data.get("offsets", [])

	if colors.size() < 2:
		push_warning("GmlRenderer: Radial gradient needs at least 2 colors")
		return null

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	gradient_texture.height = 256
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)

	var container := PanelContainer.new()
	var texture_rect := TextureRect.new()
	texture_rect.texture = gradient_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	container.add_child(texture_rect)
	container.move_child(texture_rect, 0)

	if style.has("border-radius") or style.has("border-top-left-radius"):
		container.clip_contents = true

	return container


func _create_image_background_control(bg_data: Dictionary, style: Dictionary) -> Control:
	var url: String = bg_data.get("url", "")
	if url.is_empty():
		return null

	if not ResourceLoader.exists(url):
		push_warning("GmlRenderer: Background image not found: %s" % url)
		return null

	var texture := load(url) as Texture2D
	if texture == null:
		push_warning("GmlRenderer: Failed to load background image: %s" % url)
		return null

	var container := PanelContainer.new()
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	container.add_child(texture_rect)
	container.move_child(texture_rect, 0)

	return container
