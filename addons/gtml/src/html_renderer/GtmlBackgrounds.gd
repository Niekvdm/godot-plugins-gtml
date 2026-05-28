class_name GtmlBackgrounds
extends RefCounted

## Static factory for gradient and image background panels. Each function
## returns a fresh PanelContainer that is meant to wrap the content control —
## callers should ``container.add_child(result)`` from outside.


## Create a background control for the given parsed background dict, or null
## if the type isn't recognized / required data is missing.
static func create(bg_data: Dictionary, style: Dictionary) -> Control:
	match bg_data.get("type", ""):
		"linear-gradient":
			return _linear(bg_data, style)
		"radial-gradient":
			return _radial(bg_data, style)
		"image":
			return _image(bg_data)
		_:
			return null


static func _linear(bg_data: Dictionary, style: Dictionary) -> Control:
	var colors: Array = bg_data.get("colors", [])
	var offsets: Array = bg_data.get("offsets", [])
	var angle: float = bg_data.get("angle", 180.0)
	if colors.size() < 2:
		push_warning("GtmlBackgrounds: linear-gradient needs at least 2 colors")
		return null

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	GtmlStyles.apply_gradient_angle(tex, angle)

	return _wrap_texture(tex, style)


static func _radial(bg_data: Dictionary, style: Dictionary) -> Control:
	var colors: Array = bg_data.get("colors", [])
	var offsets: Array = bg_data.get("offsets", [])
	if colors.size() < 2:
		push_warning("GtmlBackgrounds: radial-gradient needs at least 2 colors")
		return null

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	return _wrap_texture(tex, style)


static func _image(bg_data: Dictionary) -> Control:
	var url: String = bg_data.get("url", "")
	if url.is_empty():
		return null
	if not ResourceLoader.exists(url):
		push_warning("GtmlBackgrounds: image not found: %s" % url)
		return null

	var texture := load(url) as Texture2D
	if texture == null:
		push_warning("GtmlBackgrounds: failed to load image: %s" % url)
		return null

	return _wrap_texture(texture, {})


## Common scaffold: a PanelContainer with a TextureRect filling the rect.
## When the style has border-radius, clip_contents is enabled so the rounded
## corners actually hide the texture.
static func _wrap_texture(texture: Texture2D, style: Dictionary) -> Control:
	var container := PanelContainer.new()
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	container.add_child(rect)
	container.move_child(rect, 0)

	if style.has("border-radius") or style.has("border-top-left-radius"):
		container.clip_contents = true

	return container
