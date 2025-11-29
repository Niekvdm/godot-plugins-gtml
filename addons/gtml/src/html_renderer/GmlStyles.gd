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


## Apply text styles (alignment, weight, font-family, letter-spacing) to a label.
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
