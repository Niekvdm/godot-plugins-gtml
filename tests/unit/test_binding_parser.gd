extends GutTest

## Tests for GmlBindingParser — scans for {{ }} interpolations and classifies
## attribute names.

# ─── Text interpolation ──────────────────────────────────────────

func test_find_interpolations_none() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("plain text")
	assert_eq(spans.size(), 1)
	assert_eq(spans[0]["type"], "literal")
	assert_eq(spans[0]["value"], "plain text")


func test_find_interpolations_single() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("Hello, {{ name }}!")
	assert_eq(spans.size(), 3)
	assert_eq(spans[0]["type"], "literal")
	assert_eq(spans[0]["value"], "Hello, ")
	assert_eq(spans[1]["type"], "interp")
	assert_eq(spans[1]["expr"]["type"], "path")
	assert_eq(spans[1]["expr"]["parts"], PackedStringArray(["name"]))
	assert_eq(spans[2]["type"], "literal")
	assert_eq(spans[2]["value"], "!")


func test_find_interpolations_at_start_and_end() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("{{ a }} and {{ b }}")
	assert_eq(spans.size(), 3)
	assert_eq(spans[0]["type"], "interp")
	assert_eq(spans[1]["type"], "literal")
	assert_eq(spans[1]["value"], " and ")
	assert_eq(spans[2]["type"], "interp")


func test_find_interpolations_dotted_path() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("HP: {{ player.health }}/100")
	assert_eq(spans.size(), 3)
	assert_eq(spans[1]["expr"]["parts"], PackedStringArray(["player", "health"]))


# ─── Attribute classification ────────────────────────────────────

func test_classify_attribute_v_bind_colon_shorthand() -> void:
	var cls: Dictionary = GmlBindingParser.classify_attribute(":disabled")
	assert_eq(cls["kind"], "v-bind")
	assert_eq(cls["target"], "disabled")


func test_classify_attribute_v_on_at_shorthand() -> void:
	var cls: Dictionary = GmlBindingParser.classify_attribute("@click")
	assert_eq(cls["kind"], "v-on")
	assert_eq(cls["target"], "click")


func test_classify_attribute_v_directives() -> void:
	for tag in ["v-if", "v-show", "v-for", "v-model"]:
		var cls: Dictionary = GmlBindingParser.classify_attribute(tag)
		assert_eq(cls["kind"], tag, "expected kind=%s for attr %s" % [tag, tag])


func test_classify_attribute_passthrough() -> void:
	var cls: Dictionary = GmlBindingParser.classify_attribute("class")
	assert_eq(cls["kind"], "passthrough")
	assert_eq(cls["target"], "class")
