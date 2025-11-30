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

	# Font family - look up in fonts dictionary
	if style.has("font-family"):
		var font_name: String = style["font-family"]
		var fonts_dict: Dictionary = defaults.get("fonts", {})
		if fonts_dict.has(font_name):
			var font = fonts_dict[font_name]
			if font is Font:
				label.add_theme_font_override("font", font)

	# Font weight - simulate bold using outline
	if style.has("font-weight"):
		var weight: int = style["font-weight"]
		label.set_meta("font_weight", weight)
		if weight >= 600:
			var outline_size: int
			if weight >= 900:
				outline_size = 3
			elif weight >= 800:
				outline_size = 2
			else:
				outline_size = 1
			label.add_theme_constant_override("outline_size", outline_size)
			label.add_theme_color_override("font_outline_color", label.get_theme_color("font_color"))

	# Letter spacing - simulate using Unicode space characters
	if style.has("letter-spacing"):
		var spacing: float = style["letter-spacing"]
		if spacing > 0.0:
			var original_text: String = label.text
			if not original_text.is_empty():
				var spaced_text := ""
				var space_char := ""
				if spacing >= 4.0:
					space_char = " "
				elif spacing >= 2.0:
					space_char = "\u2002"  # En space
				elif spacing >= 1.0:
					space_char = "\u2009"  # Thin space
				else:
					space_char = "\u200A"  # Hair space

				for i in range(original_text.length()):
					spaced_text += original_text[i]
					if i < original_text.length() - 1:
						var num_spaces := maxi(1, int(spacing / 2.0))
						for _j in range(num_spaces):
							spaced_text += space_char
				label.text = spaced_text
		label.set_meta("letter_spacing", spacing)

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

	# Word spacing - simulate using Unicode spaces between words
	if style.has("word-spacing"):
		apply_word_spacing(label, style["word-spacing"])

	# Text indent - store for container to handle via padding
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


## Apply word-spacing to a label by inserting extra spaces between words.
static func apply_word_spacing(label: Label, spacing: int) -> void:
	if spacing <= 0:
		return

	var text := label.text
	if text.is_empty():
		return

	# Determine space character based on spacing size
	var space_char := ""
	if spacing >= 8:
		space_char = "  "  # Double space
	elif spacing >= 4:
		space_char = " "  # Regular space
	elif spacing >= 2:
		space_char = "\u2002"  # En space
	else:
		space_char = "\u2009"  # Thin space

	# Calculate how many extra space chars to add
	var num_extra := maxi(1, spacing / 4)

	var words := text.split(" ")
	var extra_spacing := ""
	for _i in range(num_extra):
		extra_spacing += space_char

	label.text = (extra_spacing + " ").join(words)
	label.set_meta("word_spacing", spacing)


## Apply text-decoration to a label using custom draw.
## Returns a Control that wraps the label with decoration drawing.
static func apply_text_decoration(label: Label, decoration: Dictionary, color: Color) -> Control:
	var has_decoration := decoration.get("underline", false) or decoration.get("line_through", false) or decoration.get("overline", false)

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

		# Connect to label resize to update decorations
		label.resized.connect(_on_label_resized)
		label.item_rect_changed.connect(queue_redraw)

	func _on_label_resized() -> void:
		custom_minimum_size = _label.get_combined_minimum_size()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			if _label:
				_label.position = Vector2.ZERO
				_label.size = size

	func _draw() -> void:
		if not _label:
			return

		var font := _label.get_theme_font("font")
		var font_size := _label.get_theme_font_size("font_size")
		var line_height := font.get_height(font_size)
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
			# These are handled by GmlContainerElements._apply_space_distribution()
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
