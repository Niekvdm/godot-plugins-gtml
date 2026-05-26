class_name GmlStyles
extends RefCounted

## Static utility class for applying CSS styles to Godot controls.
## Extracted from GmlRenderer for reusability across element builders.


## Apply text color to a label.
static func apply_text_color(label: Label, style: Dictionary, defaults: Dictionary) -> void:
	var color: Color
	if style.has("color"):
		color = style["color"]
	else:
		color = defaults.get("default_font_color", Color.WHITE)

	label.add_theme_color_override("font_color", color)


## Apply text styles (alignment, weight, font-family, letter-spacing, decoration, etc.) to a label.
static func apply_text_styles(label: Label, style: Dictionary, defaults: Dictionary) -> void:
	# Text alignment
	if style.has("text-align"):
		match style["text-align"]:
			"left":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			"center":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			"right":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			"justify":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL

	# Font family + font weight.
	# Weight is resolved after family so we can prefer a bold variant from the
	# fonts dict (e.g. "Roboto-Bold") over the outline-simulation fallback.
	var family: String = style.get("font-family", "")
	var weight: int = style.get("font-weight", 400)
	if not family.is_empty() or style.has("font-weight"):
		_apply_font_family_and_weight(label, family, weight, defaults)

	# Letter spacing AND word spacing both flow through a single FontVariation
	# applied to the resolved font. Calling _apply_font_spacing once handles
	# either or both keys; the helper reuses an existing FontVariation override
	# if one is already on the label.
	if style.has("letter-spacing") or style.has("word-spacing"):
		_apply_font_spacing(label, style)

	# Text transform (uppercase, lowercase, capitalize)
	if style.has("text-transform"):
		apply_text_transform(label, style["text-transform"])

	# White-space (nowrap, pre, etc.)
	if style.has("white-space"):
		apply_white_space(label, style["white-space"])

	# Text overflow (ellipsis, clip)
	if style.has("text-overflow"):
		apply_text_overflow(label, style["text-overflow"])

	# Line height
	if style.has("line-height"):
		var line_height: int = style["line-height"]
		label.add_theme_constant_override("line_spacing", line_height)

	# text-indent: no native Label support in Godot 4. Stored as metadata so
	# consumers (or future RichTextLabel-backed elements) can read it back.
	if style.has("text-indent"):
		label.set_meta("text_indent", style["text-indent"])


## Apply text-transform to a label (uppercase, lowercase, capitalize).
static func apply_text_transform(label: Label, transform: String) -> void:
	var text := label.text
	if text.is_empty():
		return

	match transform:
		"uppercase":
			label.text = text.to_upper()
		"lowercase":
			label.text = text.to_lower()
		"capitalize":
			label.text = _capitalize_words(text)
		"none", _:
			pass  # Keep original text

	label.set_meta("text_transform", transform)


## Wrap the label's current font in a FontVariation and apply CSS
## letter-spacing / word-spacing via spacing_glyph / spacing_space.
##
## If the label already has a FontVariation override we reuse it so a single
## label that has both letter-spacing and word-spacing ends up with one
## FontVariation, not two stacked.
##
## When the resolved base font is a SystemFont we cannot wrap it directly
## (FontVariation needs a FontFile/FontVariation in base_font); in that case
## we set the variation's base_font to the SystemFont and rely on Godot's
## fallback chain — spacing still applies because spacing_* is on the
## variation itself, independent of the wrapped font.
static func _apply_font_spacing(label: Label, style: Dictionary) -> void:
	var fv: FontVariation
	var existing = label.get_theme_font("font") if label.has_theme_font_override("font") else null
	if existing is FontVariation:
		fv = existing
	else:
		fv = FontVariation.new()
		if existing is Font:
			fv.base_font = existing
		label.add_theme_font_override("font", fv)

	if style.has("letter-spacing"):
		fv.spacing_glyph = int(style["letter-spacing"])
		label.set_meta("letter_spacing", style["letter-spacing"])
	if style.has("word-spacing"):
		fv.spacing_space = int(style["word-spacing"])
		label.set_meta("word_spacing", style["word-spacing"])


## Resolve font-family + font-weight against the user-supplied fonts dict.
##
## Lookup order for a request like {family: "Roboto", weight: 700}:
##   1. Roboto-Bold       (kebab convention)
##   2. RobotoBold        (concat convention)
##   3. Roboto Bold       (space convention)
##   4. Roboto-700        (weight-suffix convention)
##   5. Roboto            (regular fallback)
##
## When a bold weight (>=600) is requested but no bold variant is found, we
## fall back to the legacy outline-simulation hack so something visually
## differentiates the text. weight is stored as metadata regardless.
static func _apply_font_family_and_weight(label: Label, family: String, weight: int, defaults: Dictionary) -> void:
	label.set_meta("font_weight", weight)
	var fonts_dict: Dictionary = defaults.get("fonts", {})
	var is_bold := weight >= 600

	var chosen_font: Font = null
	var chosen_was_bold := false

	if not family.is_empty():
		if is_bold:
			for key in [family + "-Bold", family + "Bold", family + " Bold", "%s-%d" % [family, weight]]:
				if fonts_dict.has(key) and fonts_dict[key] is Font:
					chosen_font = fonts_dict[key]
					chosen_was_bold = true
					break
		if chosen_font == null and fonts_dict.has(family) and fonts_dict[family] is Font:
			chosen_font = fonts_dict[family]

	if chosen_font != null:
		label.add_theme_font_override("font", chosen_font)

	# Outline-simulation fallback: only when a bold weight was requested
	# AND no real bold variant was available.
	if is_bold and not chosen_was_bold:
		var outline_size: int = 1
		if weight >= 900:
			outline_size = 3
		elif weight >= 800:
			outline_size = 2
		label.add_theme_constant_override("outline_size", outline_size)
		label.add_theme_color_override("font_outline_color", label.get_theme_color("font_color"))


## Capitalize first letter of each word.
static func _capitalize_words(text: String) -> String:
	var words := text.split(" ")
	var result := PackedStringArray()
	for word in words:
		if word.length() > 0:
			result.append(word[0].to_upper() + word.substr(1))
		else:
			result.append(word)
	return " ".join(result)


## Apply white-space property to a label.
static func apply_white_space(label: Label, value: String) -> void:
	match value:
		"nowrap":
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
		"pre":
			# Preserve whitespace and line breaks, no wrapping
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.set_meta("white_space_pre", true)
		"pre-wrap":
			# Preserve whitespace and line breaks, allow wrapping
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.set_meta("white_space_pre", true)
		"pre-line":
			# Collapse whitespace but preserve line breaks
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
		"normal", _:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD

	label.set_meta("white_space", value)


## Apply text-overflow property to a label.
static func apply_text_overflow(label: Label, value: String) -> void:
	match value:
		"ellipsis":
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		"clip":
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
		_:
			label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	label.set_meta("text_overflow", value)


## Apply text-decoration to a label using custom draw.
## Returns a Control that wraps the label with decoration drawing.
static func apply_text_decoration(label: Label, decoration: Dictionary, color: Color) -> Control:
	var has_decoration: bool = decoration.get("underline", false) or decoration.get("line_through", false) or decoration.get("overline", false)

	if not has_decoration or decoration.get("none", false):
		label.set_meta("text_decoration", decoration)
		return label

	# Create a container that draws decorations
	var container := TextDecorationContainer.new()
	container.setup(label, decoration, color)
	return container


## Custom container that draws text decorations (underline, strikethrough, overline).
class TextDecorationContainer extends Control:
	var _label: Label
	var _decoration: Dictionary
	var _color: Color

	func setup(label: Label, decoration: Dictionary, color: Color) -> void:
		_label = label
		_decoration = decoration
		_color = color

		# Add the label as child
		add_child(label)

		# Match label sizing
		custom_minimum_size = label.custom_minimum_size
		size_flags_horizontal = label.size_flags_horizontal
		size_flags_vertical = label.size_flags_vertical

		# Connect to resize events
		resized.connect(_on_resized)
		label.resized.connect(_on_label_resized)

	func _ready() -> void:
		_update_label_layout()

	func _on_resized() -> void:
		_update_label_layout()
		queue_redraw()

	func _on_label_resized() -> void:
		custom_minimum_size = _label.get_combined_minimum_size()
		queue_redraw()

	func _update_label_layout() -> void:
		if _label:
			_label.position = Vector2.ZERO
			_label.size = size

	func _draw() -> void:
		if not _label:
			return

		var font := _label.get_theme_font("font")
		var font_size := _label.get_theme_font_size("font_size")
		var ascent := font.get_ascent(font_size)

		# Get text width for decoration lines
		var text_width := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		text_width = minf(text_width, size.x)

		# Calculate x offset based on alignment
		var x_offset := 0.0
		match _label.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x_offset = (size.x - text_width) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				x_offset = size.x - text_width

		var line_thickness := maxf(1.0, font_size / 12.0)

		# Draw underline
		if _decoration.get("underline", false):
			var y := ascent + line_thickness * 2
			draw_line(Vector2(x_offset, y), Vector2(x_offset + text_width, y), _color, line_thickness)

		# Draw line-through (strikethrough)
		if _decoration.get("line_through", false):
			var y := ascent * 0.6
			draw_line(Vector2(x_offset, y), Vector2(x_offset + text_width, y), _color, line_thickness)

		# Draw overline
		if _decoration.get("overline", false):
			var y := line_thickness
			draw_line(Vector2(x_offset, y), Vector2(x_offset + text_width, y), _color, line_thickness)


## Apply text-shadow to a label using a shadow label behind it.
## Returns a Control that wraps the label with shadow.
static func apply_text_shadow(label: Label, shadow: Dictionary) -> Control:
	if shadow.get("none", false):
		label.set_meta("text_shadow", shadow)
		return label

	var container := TextShadowContainer.new()
	container.setup(label, shadow)
	return container


## Custom container that renders text shadow behind a label.
## Simulates blur by creating multiple shadow labels at slight offsets.
class TextShadowContainer extends Control:
	var _label: Label
	var _shadow_labels: Array[Label] = []
	var _shadow: Dictionary

	func setup(label: Label, shadow: Dictionary) -> void:
		_label = label
		_shadow = shadow

		var shadow_color: Color = shadow.get("color", Color(0, 0, 0, 0.5))
		var blur: int = shadow.get("blur", 0)
		var offset_x: float = shadow.get("offset_x", 0)
		var offset_y: float = shadow.get("offset_y", 0)

		# For blur effect, create multiple shadow labels at different offsets
		var num_shadows := 1
		if blur > 0:
			num_shadows = mini(blur, 8)  # Cap at 8 shadow layers for performance

		for i in range(num_shadows):
			var shadow_label := Label.new()
			shadow_label.text = label.text
			shadow_label.horizontal_alignment = label.horizontal_alignment
			shadow_label.vertical_alignment = label.vertical_alignment
			shadow_label.autowrap_mode = label.autowrap_mode

			# Copy font settings
			if label.has_theme_font_override("font"):
				shadow_label.add_theme_font_override("font", label.get_theme_font("font"))
			if label.has_theme_font_size_override("font_size"):
				shadow_label.add_theme_font_size_override("font_size", label.get_theme_font_size("font_size"))

			# Apply shadow color with decreasing opacity for blur layers
			var layer_alpha: float
			if blur > 0:
				layer_alpha = shadow_color.a / float(num_shadows) * 1.5
			else:
				layer_alpha = shadow_color.a

			var layer_color := Color(shadow_color.r, shadow_color.g, shadow_color.b, layer_alpha)
			shadow_label.add_theme_color_override("font_color", layer_color)

			# Store offset for this shadow layer (spread out for blur)
			var spread: float = 0.0
			if blur > 0 and num_shadows > 1:
				spread = float(blur) * (float(i) / float(num_shadows - 1)) * 0.5
			shadow_label.set_meta("spread", spread)
			shadow_label.set_meta("layer", i)

			add_child(shadow_label)
			_shadow_labels.append(shadow_label)

		# Add original label on top
		add_child(label)

		# Match label sizing
		custom_minimum_size = label.custom_minimum_size
		size_flags_horizontal = label.size_flags_horizontal
		size_flags_vertical = label.size_flags_vertical

		# Connect to resize and text changes
		resized.connect(_on_resized)
		label.resized.connect(_on_label_resized)

	func _ready() -> void:
		_update_layout()

	func _on_resized() -> void:
		_update_layout()

	func _on_label_resized() -> void:
		custom_minimum_size = _label.get_combined_minimum_size()
		_update_layout()

	func _update_layout() -> void:
		if not _label or _shadow_labels.is_empty():
			return

		# Position main label at origin
		_label.position = Vector2.ZERO
		_label.size = size

		var offset_x: float = _shadow.get("offset_x", 0)
		var offset_y: float = _shadow.get("offset_y", 0)
		var blur: int = _shadow.get("blur", 0)

		# Position shadow labels with offset and spread for blur
		for shadow_label in _shadow_labels:
			var spread: float = shadow_label.get_meta("spread", 0.0)
			var layer: int = shadow_label.get_meta("layer", 0)

			# Spread shadows in a pattern for blur effect
			var angle: float = float(layer) * PI * 0.5
			var spread_x: float = cos(angle) * spread
			var spread_y: float = sin(angle) * spread

			shadow_label.position = Vector2(offset_x + spread_x, offset_y + spread_y)
			shadow_label.size = size

			# Sync text if changed
			if shadow_label.text != _label.text:
				shadow_label.text = _label.text


## Apply border properties to a StyleBoxFlat.
static func apply_border_to_stylebox(style_box: StyleBoxFlat, style: Dictionary) -> void:
	var width_top: int = 0
	var width_right: int = 0
	var width_bottom: int = 0
	var width_left: int = 0
	var color: Color = Color.WHITE

	# Handle shorthand border property
	if style.has("border"):
		var border = style["border"]
		if border is Dictionary:
			var w = border.get("width", 1)
			width_top = w
			width_right = w
			width_bottom = w
			width_left = w
			color = border.get("color", Color.WHITE)

	# border-width overrides shorthand
	if style.has("border-width"):
		var w = style["border-width"]
		width_top = w
		width_right = w
		width_bottom = w
		width_left = w

	# border-color overrides shorthand
	if style.has("border-color"):
		color = style["border-color"]

	# Individual side shorthands
	if style.has("border-top"):
		var border = style["border-top"]
		if border is Dictionary:
			width_top = border.get("width", 1)
			color = border.get("color", color)
	if style.has("border-right"):
		var border = style["border-right"]
		if border is Dictionary:
			width_right = border.get("width", 1)
			color = border.get("color", color)
	if style.has("border-bottom"):
		var border = style["border-bottom"]
		if border is Dictionary:
			width_bottom = border.get("width", 1)
			color = border.get("color", color)
	if style.has("border-left"):
		var border = style["border-left"]
		if border is Dictionary:
			width_left = border.get("width", 1)
			color = border.get("color", color)

	# Individual side widths
	if style.has("border-top-width"):
		width_top = style["border-top-width"]
	if style.has("border-right-width"):
		width_right = style["border-right-width"]
	if style.has("border-bottom-width"):
		width_bottom = style["border-bottom-width"]
	if style.has("border-left-width"):
		width_left = style["border-left-width"]

	# Individual side colors
	if style.has("border-top-color"):
		color = style["border-top-color"]
	if style.has("border-right-color"):
		color = style["border-right-color"]
	if style.has("border-bottom-color"):
		color = style["border-bottom-color"]
	if style.has("border-left-color"):
		color = style["border-left-color"]

	# Apply to StyleBoxFlat
	style_box.border_width_top = width_top
	style_box.border_width_right = width_right
	style_box.border_width_bottom = width_bottom
	style_box.border_width_left = width_left
	style_box.border_color = color

	# Border-radius
	if style.has("border-radius"):
		var radius: int = style["border-radius"]
		style_box.set_corner_radius_all(radius)

	# Individual corner radii
	if style.has("border-top-left-radius"):
		style_box.corner_radius_top_left = style["border-top-left-radius"]
	if style.has("border-top-right-radius"):
		style_box.corner_radius_top_right = style["border-top-right-radius"]
	if style.has("border-bottom-left-radius"):
		style_box.corner_radius_bottom_left = style["border-bottom-left-radius"]
	if style.has("border-bottom-right-radius"):
		style_box.corner_radius_bottom_right = style["border-bottom-right-radius"]

	# Box-shadow
	if style.has("box-shadow"):
		apply_shadow_to_stylebox(style_box, style["box-shadow"])


## Apply box-shadow properties to a StyleBoxFlat.
static func apply_shadow_to_stylebox(style_box: StyleBoxFlat, shadow: Dictionary) -> void:
	if shadow.get("none", false):
		return

	style_box.shadow_color = shadow.get("color", Color(0, 0, 0, 0.5))
	style_box.shadow_size = shadow.get("blur", 0) + shadow.get("spread", 0)
	style_box.shadow_offset = Vector2(shadow.get("offset_x", 0), shadow.get("offset_y", 0))


## Apply pseudo-class style properties to an existing StyleBoxFlat.
static func apply_pseudo_style_to_stylebox(style_box: StyleBoxFlat, pseudo_style: Dictionary) -> void:
	if pseudo_style.has("background-color"):
		style_box.bg_color = pseudo_style["background-color"]

	if pseudo_style.has("border-color"):
		style_box.border_color = pseudo_style["border-color"]
	elif pseudo_style.has("border"):
		var border = pseudo_style["border"]
		if border is Dictionary:
			style_box.border_color = border.get("color", style_box.border_color)

	if pseudo_style.has("box-shadow"):
		apply_shadow_to_stylebox(style_box, pseudo_style["box-shadow"])


## Parse CSS alignment value to Godot BoxContainer alignment.
## Note: space-between/around/evenly are handled separately via spacer controls.
static func parse_box_alignment(value: String) -> int:
	match value:
		"flex-start", "start":
			return BoxContainer.ALIGNMENT_BEGIN
		"center":
			return BoxContainer.ALIGNMENT_CENTER
		"flex-end", "end":
			return BoxContainer.ALIGNMENT_END
		"space-between", "space-around", "space-evenly":
			# These are handled by GmlContainerBuilder._apply_space_distribution()
			# Return BEGIN as a fallback (will be overridden by spacers)
			return BoxContainer.ALIGNMENT_BEGIN
		_:
			return BoxContainer.ALIGNMENT_BEGIN


## Apply cross-axis alignment to a child control.
static func apply_cross_axis_alignment(control: Control, align_items: String, is_row: bool, child_style: Dictionary = {}) -> void:
	# Skip if child has explicit cross-axis size
	if is_row:
		if child_style.has("height") or child_style.has("min-height"):
			return
	else:
		if child_style.has("width") or child_style.has("min-width"):
			return

	var flags: int
	match align_items:
		"flex-start", "start":
			flags = Control.SIZE_SHRINK_BEGIN
		"center":
			flags = Control.SIZE_SHRINK_CENTER
		"flex-end", "end":
			flags = Control.SIZE_SHRINK_END
		"stretch":
			flags = Control.SIZE_EXPAND_FILL
		_:
			return

	if is_row:
		control.size_flags_vertical = flags
	else:
		control.size_flags_horizontal = flags


## Apply gradient angle to GradientTexture2D.
static func apply_gradient_angle(texture: GradientTexture2D, angle: float) -> void:
	texture.fill = GradientTexture2D.FILL_LINEAR

	angle = fmod(angle, 360.0)
	if angle < 0:
		angle += 360.0

	var rad = deg_to_rad(angle - 90.0)
	var center = Vector2(0.5, 0.5)
	var direction = Vector2(cos(rad), sin(rad))

	texture.fill_from = center - direction * 0.5
	texture.fill_to = center + direction * 0.5


## Apply outline to a control.
## Returns a Control that wraps the original with an outline drawn around it.
static func apply_outline(control: Control, outline: Dictionary, offset: int = 0) -> Control:
	if outline.get("style", "solid") == "none" or outline.get("width", 0) == 0:
		control.set_meta("outline", outline)
		return control

	var container := OutlineContainer.new()
	container.setup(control, outline, offset)
	return container


## Custom container that draws an outline around its child control.
class OutlineContainer extends Control:
	var _child: Control
	var _outline: Dictionary
	var _offset: int

	func setup(child: Control, outline: Dictionary, offset: int) -> void:
		_child = child
		_outline = outline
		_offset = offset

		# Add the child
		add_child(child)

		# Match child sizing
		custom_minimum_size = child.custom_minimum_size
		size_flags_horizontal = child.size_flags_horizontal
		size_flags_vertical = child.size_flags_vertical

		# Connect to resize events
		resized.connect(_on_resized)
		child.resized.connect(_on_child_resized)

	func _ready() -> void:
		_update_layout()

	func _on_resized() -> void:
		_update_layout()
		queue_redraw()

	func _on_child_resized() -> void:
		custom_minimum_size = _child.get_combined_minimum_size()
		queue_redraw()

	func _update_layout() -> void:
		if _child:
			_child.position = Vector2.ZERO
			_child.size = size

	func _draw() -> void:
		if not _child:
			return

		var width: int = _outline.get("width", 1)
		var color: Color = _outline.get("color", Color.WHITE)
		var style: String = _outline.get("style", "solid")

		if width <= 0 or style == "none":
			return

		# Draw outline outside the control bounds (with offset)
		var outline_offset: float = _offset + width / 2.0
		var rect := Rect2(
			-outline_offset,
			-outline_offset,
			size.x + outline_offset * 2,
			size.y + outline_offset * 2
		)

		if style == "dashed":
			_draw_dashed_rect(rect, color, width)
		elif style == "dotted":
			_draw_dotted_rect(rect, color, width)
		else:  # solid
			draw_rect(rect, color, false, width)

	func _draw_dashed_rect(rect: Rect2, color: Color, width: int) -> void:
		var dash_length := width * 4.0
		var gap_length := width * 2.0

		# Top edge
		_draw_dashed_line(rect.position, rect.position + Vector2(rect.size.x, 0), color, width, dash_length, gap_length)
		# Right edge
		_draw_dashed_line(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, color, width, dash_length, gap_length)
		# Bottom edge
		_draw_dashed_line(rect.position + rect.size, rect.position + Vector2(0, rect.size.y), color, width, dash_length, gap_length)
		# Left edge
		_draw_dashed_line(rect.position + Vector2(0, rect.size.y), rect.position, color, width, dash_length, gap_length)

	func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: int, dash: float, gap: float) -> void:
		var direction := (to - from).normalized()
		var length := from.distance_to(to)
		var pos := 0.0

		while pos < length:
			var dash_end := minf(pos + dash, length)
			draw_line(from + direction * pos, from + direction * dash_end, color, width)
			pos = dash_end + gap

	func _draw_dotted_rect(rect: Rect2, color: Color, width: int) -> void:
		var dot_spacing := width * 2.0

		# Top edge
		_draw_dotted_line(rect.position, rect.position + Vector2(rect.size.x, 0), color, width, dot_spacing)
		# Right edge
		_draw_dotted_line(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, color, width, dot_spacing)
		# Bottom edge
		_draw_dotted_line(rect.position + rect.size, rect.position + Vector2(0, rect.size.y), color, width, dot_spacing)
		# Left edge
		_draw_dotted_line(rect.position + Vector2(0, rect.size.y), rect.position, color, width, dot_spacing)

	func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: int, spacing: float) -> void:
		var direction := (to - from).normalized()
		var length := from.distance_to(to)
		var pos := 0.0

		while pos < length:
			draw_circle(from + direction * pos, width / 2.0, color)
			pos += spacing
