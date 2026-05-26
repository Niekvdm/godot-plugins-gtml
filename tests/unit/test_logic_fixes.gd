extends GutTest

## Verifies the v0.2 logic fixes in GmlStyles:
##   - letter-spacing / word-spacing / text-indent no longer mutate label.text
##   - font-weight: bold looks up a font variant from the fonts dict before
##     falling back to outline simulation


func _label_with_text(t: String) -> Label:
	var l := Label.new()
	l.text = t
	add_child_autofree(l)
	return l


func test_letter_spacing_does_not_mutate_text() -> void:
	var l := _label_with_text("hello world")
	GmlStyles.apply_text_styles(l, {"letter-spacing": 4}, {})
	assert_eq(l.text, "hello world")
	# Spacing value is still preserved as metadata for future renderers / read-back
	assert_eq(l.get_meta("letter_spacing", -1), 4)


func test_word_spacing_does_not_mutate_text() -> void:
	var l := _label_with_text("a b c")
	GmlStyles.apply_text_styles(l, {"word-spacing": 6}, {})
	assert_eq(l.text, "a b c")
	assert_eq(l.get_meta("word_spacing", -1), 6)


func test_text_indent_does_not_mutate_text() -> void:
	var l := _label_with_text("paragraph")
	GmlStyles.apply_text_styles(l, {"text-indent": 12}, {})
	assert_eq(l.text, "paragraph")
	assert_eq(l.get_meta("text_indent", -1), 12)


func test_text_transform_uppercase_still_mutates() -> void:
	# text-transform is the one case where mutating label.text is the
	# correct behavior — that's the whole point of the property.
	var l := _label_with_text("hello")
	GmlStyles.apply_text_styles(l, {"text-transform": "uppercase"}, {})
	assert_eq(l.text, "HELLO")


func test_font_weight_bold_uses_variant_from_dict() -> void:
	var regular := SystemFont.new()
	regular.font_names = PackedStringArray(["sans-serif"])
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["sans-serif"])
	bold.font_weight = 700

	var l := _label_with_text("bold text")
	var defaults := {"fonts": {"Roboto": regular, "Roboto-Bold": bold}}
	GmlStyles.apply_text_styles(l, {"font-family": "Roboto", "font-weight": 700}, defaults)

	# Bold variant should have been picked up; the override should be the bold font, not the regular one.
	var override = l.get_theme_font("font")
	assert_eq(override, bold, "expected bold variant from fonts dict to be applied")
	# And we should NOT have fallen back to the outline simulation hack
	assert_false(l.has_theme_constant_override("outline_size"), "should not simulate bold with outline when a real variant is available")


func test_font_weight_bold_falls_back_when_no_variant() -> void:
	var regular := SystemFont.new()
	regular.font_names = PackedStringArray(["sans-serif"])

	var l := _label_with_text("bold text")
	var defaults := {"fonts": {"Roboto": regular}}  # no -Bold variant
	GmlStyles.apply_text_styles(l, {"font-family": "Roboto", "font-weight": 700}, defaults)

	# With no variant available we still want SOME visual differentiation,
	# so the outline fallback should be in place.
	assert_true(l.has_theme_constant_override("outline_size"),
		"expected outline fallback when no bold variant exists in fonts dict")
