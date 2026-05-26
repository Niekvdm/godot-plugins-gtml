extends GutTest

## v0.3: letter-spacing and word-spacing render via FontVariation.spacing
## (no more label.text mutation, no more "stored as meta only" punt).
## text-indent still has no native Label support and remains metadata only.


func _label_with_text(t: String) -> Label:
	var l := Label.new()
	l.text = t
	add_child_autofree(l)
	return l


func test_letter_spacing_wraps_font_in_variation() -> void:
	var l := _label_with_text("hello")
	GmlStyles.apply_text_styles(l, {"letter-spacing": 4}, {})

	# Label text must not be mutated.
	assert_eq(l.text, "hello")
	# A FontVariation must be installed as the font override.
	var fv = l.get_theme_font("font")
	assert_true(fv is FontVariation, "expected FontVariation, got %s" % typeof(fv))
	assert_eq((fv as FontVariation).spacing_glyph, 4)


func test_word_spacing_wraps_font_in_variation() -> void:
	var l := _label_with_text("a b c")
	GmlStyles.apply_text_styles(l, {"word-spacing": 6}, {})
	assert_eq(l.text, "a b c")
	var fv = l.get_theme_font("font")
	assert_true(fv is FontVariation)
	assert_eq((fv as FontVariation).spacing_space, 6)


func test_letter_and_word_spacing_share_one_font_variation() -> void:
	var l := _label_with_text("a b")
	GmlStyles.apply_text_styles(l, {"letter-spacing": 2, "word-spacing": 6}, {})
	var fv = l.get_theme_font("font") as FontVariation
	assert_not_null(fv)
	assert_eq(fv.spacing_glyph, 2)
	assert_eq(fv.spacing_space, 6)


func test_spacing_layers_over_font_family() -> void:
	# When the user supplies a font-family, the FontVariation wraps it so the
	# user's font choice is preserved (not replaced).
	var custom := SystemFont.new()
	custom.font_names = PackedStringArray(["sans-serif"])
	var l := _label_with_text("hi")
	GmlStyles.apply_text_styles(l, {"font-family": "Custom", "letter-spacing": 3},
		{"fonts": {"Custom": custom}})
	var fv = l.get_theme_font("font") as FontVariation
	assert_not_null(fv)
	assert_eq(fv.spacing_glyph, 3)
	assert_eq(fv.base_font, custom, "FontVariation must wrap the user-supplied font")


func test_text_indent_still_metadata_only() -> void:
	# Documented limitation: text-indent has no Label-level native support in
	# Godot 4, so we keep it as metadata so consumers can post-process if needed.
	var l := _label_with_text("paragraph")
	GmlStyles.apply_text_styles(l, {"text-indent": 12}, {})
	assert_eq(l.text, "paragraph")
	assert_eq(l.get_meta("text_indent", -1), 12)
