class_name GmlMediaElements
extends RefCounted

## Static utility class for building media elements (img, svg, progress, br, hr).

const SvgDrawControlScript = preload("res://addons/gml/src/html_renderer/SvgDrawControl.gd")


## Build an image element.
static func build_image(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_image_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_image_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)
	var texture_rect := TextureRect.new()

	# Check if BOTH width and height are explicitly set
	var has_width = style.has("width") or style.has("min-width")
	var has_height = style.has("height") or style.has("min-height")

	if has_width and has_height:
		# Fully sized image - use control's size
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Apply dimensions directly to TextureRect (since we may wrap it)
		if style.has("width"):
			var width_dim = style["width"]
			if width_dim is Dictionary and width_dim.get("unit", "") == "px":
				texture_rect.custom_minimum_size.x = width_dim["value"]
		if style.has("min-width"):
			var dim = style["min-width"]
			if dim is Dictionary and dim.get("unit", "") == "px":
				texture_rect.custom_minimum_size.x = maxf(texture_rect.custom_minimum_size.x, dim["value"])
		if style.has("height"):
			var height_dim = style["height"]
			if height_dim is Dictionary and height_dim.get("unit", "") == "px":
				texture_rect.custom_minimum_size.y = height_dim["value"]
		if style.has("min-height"):
			var dim = style["min-height"]
			if dim is Dictionary and dim.get("unit", "") == "px":
				texture_rect.custom_minimum_size.y = maxf(texture_rect.custom_minimum_size.y, dim["value"])
	else:
		# Responsive image - expand to fit container width
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	var src = node.get_attr("src", "")
	if not src.is_empty():
		if ResourceLoader.exists(src):
			var texture := load(src) as Texture2D
			if texture != null:
				texture_rect.texture = texture
			else:
				push_warning("GmlMediaElements: Failed to load texture: %s" % src)
		else:
			push_warning("GmlMediaElements: Image not found: %s" % src)

	# For images with explicit dimensions, set size flags for centering
	# SIZE_SHRINK_CENTER tells the parent container to center this control
	if has_width and has_height:
		texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	return texture_rect


## Build a line break.
static func build_line_break() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	return spacer


## Build a horizontal rule.
static func build_horizontal_rule(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_horizontal_rule_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_horizontal_rule_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)

	var separator := HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if style.has("height"):
		var height_dim = style["height"]
		if height_dim is Dictionary and height_dim.get("unit", "") == "px":
			separator.custom_minimum_size.y = height_dim["value"]

	if style.has("background-color"):
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = style["background-color"]
		stylebox.content_margin_top = 0
		stylebox.content_margin_bottom = 0
		separator.add_theme_stylebox_override("separator", stylebox)

	return separator


## Build a progress bar.
static func build_progress(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_progress_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_progress_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)

	var progress := ProgressBar.new()

	var value = float(node.get_attr("value", "0"))
	var max_val = float(node.get_attr("max", "100"))

	progress.max_value = max_val
	progress.value = value
	progress.show_percentage = false

	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if style.has("height"):
		var height_dim = style["height"]
		if height_dim is Dictionary and height_dim.get("unit", "") == "px":
			progress.custom_minimum_size.y = height_dim["value"]

	return progress


## Build an SVG element.
static func build_svg(node, ctx: Dictionary) -> Dictionary:
	var inner = _build_svg_inner(node, ctx)
	var style = ctx.get_style.call(node)
	var wrapped = ctx.wrap_with_margin_padding.call(inner, style)
	return {"control": wrapped, "inner": inner}


static func _build_svg_inner(node, ctx: Dictionary) -> Control:
	var style = ctx.get_style.call(node)

	# Get viewBox dimensions
	var viewbox_str = node.get_attr("viewBox", "0 0 24 24")
	var viewbox_parts = viewbox_str.split(" ")
	var viewbox := Rect2(0, 0, 24, 24)
	if viewbox_parts.size() >= 4:
		viewbox = Rect2(
			float(viewbox_parts[0]),
			float(viewbox_parts[1]),
			float(viewbox_parts[2]),
			float(viewbox_parts[3])
		)

	var svg_width: float = float(node.get_attr("width", str(viewbox.size.x)))
	var svg_height: float = float(node.get_attr("height", str(viewbox.size.y)))

	if style.has("width"):
		var width_dim = style["width"]
		if width_dim is Dictionary and width_dim.get("unit", "") == "px":
			svg_width = width_dim["value"]
	if style.has("height"):
		var height_dim = style["height"]
		if height_dim is Dictionary and height_dim.get("unit", "") == "px":
			svg_height = height_dim["value"]

	var svg_control := SvgDrawControlScript.new()
	svg_control.viewbox = viewbox
	svg_control.svg_size = Vector2(svg_width, svg_height)
	svg_control.custom_minimum_size = Vector2(svg_width, svg_height)

	var default_stroke: Color = Color.WHITE
	var default_fill: Color = Color.TRANSPARENT
	var default_stroke_width: float = 1.0

	if node.has_attr("stroke"):
		default_stroke = _parse_svg_color(node.get_attr("stroke", ""), Color.WHITE)
	if node.has_attr("fill"):
		default_fill = _parse_svg_color(node.get_attr("fill", ""), Color.TRANSPARENT)
	if node.has_attr("stroke-width"):
		default_stroke_width = float(node.get_attr("stroke-width", "1"))

	if style.has("color"):
		default_stroke = style["color"]
	if style.has("fill"):
		if style["fill"] is Color:
			default_fill = style["fill"]

	svg_control.default_stroke = default_stroke
	svg_control.default_fill = default_fill
	svg_control.default_stroke_width = default_stroke_width

	for child in node.children:
		if child.is_text_node:
			continue
		_parse_svg_element(svg_control, child, default_stroke, default_fill, default_stroke_width)

	# Check if SVG has explicit dimensions for centering in flex containers
	var has_width = style.has("width") or style.has("min-width")
	var has_height = style.has("height") or style.has("min-height")

	if has_width and has_height:
		svg_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		svg_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	return svg_control


## Parse an SVG child element into draw commands.
static func _parse_svg_element(svg_control, node, parent_stroke: Color, parent_fill: Color, parent_stroke_width: float) -> void:
	var stroke := parent_stroke
	var fill := parent_fill
	var stroke_width := parent_stroke_width

	if node.has_attr("stroke"):
		stroke = _parse_svg_color(node.get_attr("stroke", ""), parent_stroke)
	if node.has_attr("fill"):
		fill = _parse_svg_color(node.get_attr("fill", ""), parent_fill)
	if node.has_attr("stroke-width"):
		stroke_width = float(node.get_attr("stroke-width", str(parent_stroke_width)))

	match node.tag:
		"polygon":
			var points_str = node.get_attr("points", "")
			var points := _parse_svg_points(points_str)
			if points.size() >= 3:
				svg_control.add_polygon(points, fill, stroke, stroke_width)

		"polyline":
			var points_str = node.get_attr("points", "")
			var points := _parse_svg_points(points_str)
			if points.size() >= 2:
				svg_control.add_polyline(points, stroke, stroke_width)

		"line":
			var x1 := float(node.get_attr("x1", "0"))
			var y1 := float(node.get_attr("y1", "0"))
			var x2 := float(node.get_attr("x2", "0"))
			var y2 := float(node.get_attr("y2", "0"))
			svg_control.add_line(Vector2(x1, y1), Vector2(x2, y2), stroke, stroke_width)

		"circle":
			var cx := float(node.get_attr("cx", "0"))
			var cy := float(node.get_attr("cy", "0"))
			var r := float(node.get_attr("r", "0"))
			svg_control.add_circle(Vector2(cx, cy), r, fill, stroke, stroke_width)

		"ellipse":
			var cx := float(node.get_attr("cx", "0"))
			var cy := float(node.get_attr("cy", "0"))
			var rx := float(node.get_attr("rx", "0"))
			var ry := float(node.get_attr("ry", "0"))
			svg_control.add_ellipse(Vector2(cx, cy), Vector2(rx, ry), fill, stroke, stroke_width)

		"rect":
			var x := float(node.get_attr("x", "0"))
			var y := float(node.get_attr("y", "0"))
			var w := float(node.get_attr("width", "0"))
			var h := float(node.get_attr("height", "0"))
			var rx := float(node.get_attr("rx", "0"))
			var ry := float(node.get_attr("ry", "0"))
			svg_control.add_rect(Rect2(x, y, w, h), fill, stroke, stroke_width, maxf(rx, ry))

		"path":
			var d: String = node.get_attr("d", "")
			if not d.is_empty():
				svg_control.add_path(d, fill, stroke, stroke_width)

		"g":
			for child in node.children:
				if not child.is_text_node:
					_parse_svg_element(svg_control, child, stroke, fill, stroke_width)


## Parse SVG color value.
static func _parse_svg_color(value: String, default: Color) -> Color:
	value = value.strip_edges().to_lower()

	if value.is_empty() or value == "inherit":
		return default
	if value == "none" or value == "transparent":
		return Color.TRANSPARENT
	if value == "currentcolor":
		return default

	var named_colors := {
		"white": Color.WHITE,
		"black": Color.BLACK,
		"red": Color.RED,
		"green": Color.GREEN,
		"blue": Color.BLUE,
		"yellow": Color.YELLOW,
		"cyan": Color.CYAN,
		"magenta": Color.MAGENTA,
		"gray": Color.GRAY,
		"grey": Color.GRAY,
		"orange": Color.ORANGE,
		"purple": Color.PURPLE,
		"pink": Color.PINK,
	}
	if named_colors.has(value):
		return named_colors[value]

	if value.begins_with("#"):
		return Color.from_string(value, default)

	if value.begins_with("rgb"):
		var inner = value.substr(value.find("(") + 1)
		inner = inner.substr(0, inner.find(")"))
		var parts = inner.split(",")
		if parts.size() >= 3:
			var r := float(parts[0].strip_edges()) / 255.0
			var g := float(parts[1].strip_edges()) / 255.0
			var b := float(parts[2].strip_edges()) / 255.0
			var a := 1.0
			if parts.size() >= 4:
				a = float(parts[3].strip_edges())
			return Color(r, g, b, a)

	return default


## Parse SVG points string into PackedVector2Array.
static func _parse_svg_points(points_str: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	points_str = points_str.strip_edges()

	if points_str.is_empty():
		return result

	var values := PackedFloat64Array()
	var current := ""

	for ch in points_str:
		if ch == "," or ch == " " or ch == "\t" or ch == "\n":
			if not current.is_empty():
				values.append(float(current))
				current = ""
		else:
			current += ch

	if not current.is_empty():
		values.append(float(current))

	var i := 0
	while i + 1 < values.size():
		result.append(Vector2(values[i], values[i + 1]))
		i += 2

	return result
