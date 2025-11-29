@tool
class_name SvgDrawControl
extends Control

## A Control that renders SVG-like draw commands.
## Supports polygons, polylines, lines, circles, ellipses, rectangles, and paths.

# SVG viewbox and render size
var viewbox: Rect2 = Rect2(0, 0, 24, 24)
var svg_size: Vector2 = Vector2(24, 24)

# Default styles
var default_stroke: Color = Color.WHITE
var default_fill: Color = Color.TRANSPARENT
var default_stroke_width: float = 1.0

# Draw commands storage
var _draw_commands: Array = []

# Command types
enum CommandType {
	POLYGON,
	POLYLINE,
	LINE,
	CIRCLE,
	ELLIPSE,
	RECT,
	PATH
}


func _ready() -> void:
	# Ensure we redraw when size changes
	resized.connect(queue_redraw)


## Add a polygon (closed shape with fill and stroke).
func add_polygon(points: PackedVector2Array, fill: Color, stroke: Color, stroke_width: float) -> void:
	_draw_commands.append({
		"type": CommandType.POLYGON,
		"points": points,
		"fill": fill,
		"stroke": stroke,
		"stroke_width": stroke_width
	})
	queue_redraw()


## Add a polyline (open shape, stroke only).
func add_polyline(points: PackedVector2Array, stroke: Color, stroke_width: float) -> void:
	_draw_commands.append({
		"type": CommandType.POLYLINE,
		"points": points,
		"stroke": stroke,
		"stroke_width": stroke_width
	})
	queue_redraw()


## Add a line.
func add_line(from: Vector2, to: Vector2, stroke: Color, stroke_width: float) -> void:
	_draw_commands.append({
		"type": CommandType.LINE,
		"from": from,
		"to": to,
		"stroke": stroke,
		"stroke_width": stroke_width
	})
	queue_redraw()


## Add a circle.
func add_circle(center: Vector2, radius: float, fill: Color, stroke: Color, stroke_width: float) -> void:
	_draw_commands.append({
		"type": CommandType.CIRCLE,
		"center": center,
		"radius": radius,
		"fill": fill,
		"stroke": stroke,
		"stroke_width": stroke_width
	})
	queue_redraw()


## Add an ellipse.
func add_ellipse(center: Vector2, radii: Vector2, fill: Color, stroke: Color, stroke_width: float) -> void:
	_draw_commands.append({
		"type": CommandType.ELLIPSE,
		"center": center,
		"radii": radii,
		"fill": fill,
		"stroke": stroke,
		"stroke_width": stroke_width
	})
	queue_redraw()


## Add a rectangle.
func add_rect(rect: Rect2, fill: Color, stroke: Color, stroke_width: float, corner_radius: float = 0.0) -> void:
	_draw_commands.append({
		"type": CommandType.RECT,
		"rect": rect,
		"fill": fill,
		"stroke": stroke,
		"stroke_width": stroke_width,
		"corner_radius": corner_radius
	})
	queue_redraw()


## Add a path (SVG path data string).
func add_path(d: String, fill: Color, stroke: Color, stroke_width: float) -> void:
	_draw_commands.append({
		"type": CommandType.PATH,
		"d": d,
		"fill": fill,
		"stroke": stroke,
		"stroke_width": stroke_width
	})
	queue_redraw()


func _draw() -> void:
	if _draw_commands.is_empty():
		return

	# Calculate transform from viewbox to render size
	var scale_x := size.x / viewbox.size.x if viewbox.size.x > 0 else 1.0
	var scale_y := size.y / viewbox.size.y if viewbox.size.y > 0 else 1.0
	var scale_factor := minf(scale_x, scale_y)  # Maintain aspect ratio

	# Center the SVG if aspect ratios don't match
	var offset := Vector2.ZERO
	offset.x = (size.x - viewbox.size.x * scale_factor) / 2.0
	offset.y = (size.y - viewbox.size.y * scale_factor) / 2.0

	for cmd in _draw_commands:
		match cmd["type"]:
			CommandType.POLYGON:
				_draw_polygon_cmd(cmd, scale_factor, offset)
			CommandType.POLYLINE:
				_draw_polyline_cmd(cmd, scale_factor, offset)
			CommandType.LINE:
				_draw_line_cmd(cmd, scale_factor, offset)
			CommandType.CIRCLE:
				_draw_circle_cmd(cmd, scale_factor, offset)
			CommandType.ELLIPSE:
				_draw_ellipse_cmd(cmd, scale_factor, offset)
			CommandType.RECT:
				_draw_rect_cmd(cmd, scale_factor, offset)
			CommandType.PATH:
				_draw_path_cmd(cmd, scale_factor, offset)


func _transform_point(point: Vector2, scale: float, offset: Vector2) -> Vector2:
	return Vector2(
		(point.x - viewbox.position.x) * scale + offset.x,
		(point.y - viewbox.position.y) * scale + offset.y
	)


func _transform_points(points: PackedVector2Array, scale: float, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(_transform_point(p, scale, offset))
	return result


func _draw_polygon_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var points := _transform_points(cmd["points"], scale, offset)
	var fill: Color = cmd["fill"]
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale

	# Draw fill
	if fill.a > 0 and points.size() >= 3:
		var colors := PackedColorArray()
		for _i in range(points.size()):
			colors.append(fill)
		draw_polygon(points, colors)

	# Draw stroke
	if stroke.a > 0 and points.size() >= 2:
		# Close the polygon by drawing back to start
		for i in range(points.size()):
			var next_i := (i + 1) % points.size()
			draw_line(points[i], points[next_i], stroke, stroke_width, true)


func _draw_polyline_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var points := _transform_points(cmd["points"], scale, offset)
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale

	if stroke.a > 0 and points.size() >= 2:
		draw_polyline(points, stroke, stroke_width, true)


func _draw_line_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var from := _transform_point(cmd["from"], scale, offset)
	var to := _transform_point(cmd["to"], scale, offset)
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale

	if stroke.a > 0:
		draw_line(from, to, stroke, stroke_width, true)


func _draw_circle_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var center := _transform_point(cmd["center"], scale, offset)
	var radius: float = cmd["radius"] * scale
	var fill: Color = cmd["fill"]
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale

	# Draw fill
	if fill.a > 0:
		draw_circle(center, radius, fill)

	# Draw stroke (as arc)
	if stroke.a > 0:
		draw_arc(center, radius, 0, TAU, 64, stroke, stroke_width, true)


func _draw_ellipse_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var center := _transform_point(cmd["center"], scale, offset)
	var radii: Vector2 = cmd["radii"] * scale
	var fill: Color = cmd["fill"]
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale

	# Generate ellipse points
	var points := PackedVector2Array()
	var segments := 64
	for i in range(segments):
		var angle := float(i) / float(segments) * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))

	# Draw fill
	if fill.a > 0:
		var colors := PackedColorArray()
		for _i in range(points.size()):
			colors.append(fill)
		draw_polygon(points, colors)

	# Draw stroke
	if stroke.a > 0:
		points.append(points[0])  # Close the shape
		draw_polyline(points, stroke, stroke_width, true)


func _draw_rect_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var rect: Rect2 = cmd["rect"]
	var fill: Color = cmd["fill"]
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale
	var corner_radius: float = cmd["corner_radius"] * scale

	# Transform rect
	var top_left := _transform_point(rect.position, scale, offset)
	var scaled_size := rect.size * scale
	var transformed_rect := Rect2(top_left, scaled_size)

	# Draw fill
	if fill.a > 0:
		if corner_radius > 0:
			# Draw rounded rectangle
			_draw_rounded_rect_fill(transformed_rect, corner_radius, fill)
		else:
			draw_rect(transformed_rect, fill)

	# Draw stroke
	if stroke.a > 0:
		if corner_radius > 0:
			_draw_rounded_rect_stroke(transformed_rect, corner_radius, stroke, stroke_width)
		else:
			draw_rect(transformed_rect, stroke, false, stroke_width)


func _draw_rounded_rect_fill(rect: Rect2, radius: float, color: Color) -> void:
	radius = minf(radius, minf(rect.size.x / 2, rect.size.y / 2))

	var points := PackedVector2Array()
	var segments := 8  # Segments per corner

	# Top-right corner
	for i in range(segments + 1):
		var angle := -PI / 2 + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius
		))

	# Bottom-right corner
	for i in range(segments + 1):
		var angle := 0 + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius
		))

	# Bottom-left corner
	for i in range(segments + 1):
		var angle := PI / 2 + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius
		))

	# Top-left corner
	for i in range(segments + 1):
		var angle := PI + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius
		))

	var colors := PackedColorArray()
	for _i in range(points.size()):
		colors.append(color)
	draw_polygon(points, colors)


func _draw_rounded_rect_stroke(rect: Rect2, radius: float, color: Color, width: float) -> void:
	radius = minf(radius, minf(rect.size.x / 2, rect.size.y / 2))

	var points := PackedVector2Array()
	var segments := 8

	# Top-right corner
	for i in range(segments + 1):
		var angle := -PI / 2 + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius
		))

	# Bottom-right corner
	for i in range(segments + 1):
		var angle := 0 + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + rect.size.x - radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius
		))

	# Bottom-left corner
	for i in range(segments + 1):
		var angle := PI / 2 + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + radius + cos(angle) * radius,
			rect.position.y + rect.size.y - radius + sin(angle) * radius
		))

	# Top-left corner
	for i in range(segments + 1):
		var angle := PI + (float(i) / float(segments)) * (PI / 2)
		points.append(Vector2(
			rect.position.x + radius + cos(angle) * radius,
			rect.position.y + radius + sin(angle) * radius
		))

	# Close the shape
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _draw_path_cmd(cmd: Dictionary, scale: float, offset: Vector2) -> void:
	var d: String = cmd["d"]
	var fill: Color = cmd["fill"]
	var stroke: Color = cmd["stroke"]
	var stroke_width: float = cmd["stroke_width"] * scale

	# Parse SVG path data
	var points := _parse_path_data(d)
	if points.is_empty():
		return

	# Transform points
	var transformed := _transform_points(points, scale, offset)

	# Draw fill
	if fill.a > 0 and transformed.size() >= 3:
		var colors := PackedColorArray()
		for _i in range(transformed.size()):
			colors.append(fill)
		draw_polygon(transformed, colors)

	# Draw stroke
	if stroke.a > 0 and transformed.size() >= 2:
		draw_polyline(transformed, stroke, stroke_width, true)


## Parse SVG path data string into points.
## Supports: M, L, H, V, Z (and lowercase relative versions)
## Limited support for curves (approximated as lines)
func _parse_path_data(d: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	var current := Vector2.ZERO
	var start := Vector2.ZERO

	# Tokenize the path data
	var tokens := _tokenize_path(d)
	var i := 0

	while i < tokens.size():
		var cmd_token = tokens[i]
		i += 1

		match cmd_token:
			"M":  # Move to (absolute)
				if i + 1 < tokens.size():
					current = Vector2(float(tokens[i]), float(tokens[i + 1]))
					start = current
					points.append(current)
					i += 2
					# Additional coordinate pairs are treated as line-to
					while i + 1 < tokens.size() and _is_number(tokens[i]):
						current = Vector2(float(tokens[i]), float(tokens[i + 1]))
						points.append(current)
						i += 2

			"m":  # Move to (relative)
				if i + 1 < tokens.size():
					current += Vector2(float(tokens[i]), float(tokens[i + 1]))
					start = current
					points.append(current)
					i += 2
					while i + 1 < tokens.size() and _is_number(tokens[i]):
						current += Vector2(float(tokens[i]), float(tokens[i + 1]))
						points.append(current)
						i += 2

			"L":  # Line to (absolute)
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					current = Vector2(float(tokens[i]), float(tokens[i + 1]))
					points.append(current)
					i += 2

			"l":  # Line to (relative)
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					current += Vector2(float(tokens[i]), float(tokens[i + 1]))
					points.append(current)
					i += 2

			"H":  # Horizontal line (absolute)
				while i < tokens.size() and _is_number(tokens[i]):
					current.x = float(tokens[i])
					points.append(current)
					i += 1

			"h":  # Horizontal line (relative)
				while i < tokens.size() and _is_number(tokens[i]):
					current.x += float(tokens[i])
					points.append(current)
					i += 1

			"V":  # Vertical line (absolute)
				while i < tokens.size() and _is_number(tokens[i]):
					current.y = float(tokens[i])
					points.append(current)
					i += 1

			"v":  # Vertical line (relative)
				while i < tokens.size() and _is_number(tokens[i]):
					current.y += float(tokens[i])
					points.append(current)
					i += 1

			"Z", "z":  # Close path
				if not points.is_empty() and points[points.size() - 1] != start:
					points.append(start)
				current = start

			"C":  # Cubic Bezier (absolute) - simplified to endpoint
				while i + 5 < tokens.size() and _is_number(tokens[i]):
					# Skip control points, just use endpoint
					current = Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
					points.append(current)
					i += 6

			"c":  # Cubic Bezier (relative) - simplified to endpoint
				while i + 5 < tokens.size() and _is_number(tokens[i]):
					current += Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
					points.append(current)
					i += 6

			"S":  # Smooth cubic Bezier (absolute) - simplified to endpoint
				while i + 3 < tokens.size() and _is_number(tokens[i]):
					current = Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
					points.append(current)
					i += 4

			"s":  # Smooth cubic Bezier (relative) - simplified to endpoint
				while i + 3 < tokens.size() and _is_number(tokens[i]):
					current += Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
					points.append(current)
					i += 4

			"Q":  # Quadratic Bezier (absolute) - simplified to endpoint
				while i + 3 < tokens.size() and _is_number(tokens[i]):
					current = Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
					points.append(current)
					i += 4

			"q":  # Quadratic Bezier (relative) - simplified to endpoint
				while i + 3 < tokens.size() and _is_number(tokens[i]):
					current += Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
					points.append(current)
					i += 4

			"T":  # Smooth quadratic Bezier (absolute) - simplified to endpoint
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					current = Vector2(float(tokens[i]), float(tokens[i + 1]))
					points.append(current)
					i += 2

			"t":  # Smooth quadratic Bezier (relative) - simplified to endpoint
				while i + 1 < tokens.size() and _is_number(tokens[i]):
					current += Vector2(float(tokens[i]), float(tokens[i + 1]))
					points.append(current)
					i += 2

			"A", "a":  # Arc - skip for now, complex to implement
				# Skip 7 parameters per arc
				while i + 6 < tokens.size() and _is_number(tokens[i]):
					i += 7

	return points


## Tokenize SVG path data into commands and numbers.
func _tokenize_path(d: String) -> Array:
	var tokens := []
	var current := ""
	var i := 0

	while i < d.length():
		var ch := d[i]

		if ch in "MmLlHhVvZzCcSsQqTtAa":
			if not current.is_empty():
				tokens.append(current)
				current = ""
			tokens.append(ch)
		elif ch == "," or ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			if not current.is_empty():
				tokens.append(current)
				current = ""
		elif ch == "-" and not current.is_empty() and not current.ends_with("e") and not current.ends_with("E"):
			# Negative sign starts a new number (unless after exponent)
			tokens.append(current)
			current = ch
		else:
			current += ch

		i += 1

	if not current.is_empty():
		tokens.append(current)

	return tokens


func _is_number(s: String) -> bool:
	if s.is_empty():
		return false
	var first := s[0]
	return first.is_valid_int() or first == "-" or first == "." or first == "+"
