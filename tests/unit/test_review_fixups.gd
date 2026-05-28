extends GutTest

## Tests pinning the post-review fixups:
##   - HTML entity numeric overflow + surrogate rejection
##   - HTML entity edge cases: trailing &, empty &;
##   - Entities decoded in any attribute (not just href)
##   - Selector group splitter respects quotes/brackets/parens
##   - Selector parser warns on malformed input
##   - Resolver does NOT merge typo'd pseudo rules into base style
##   - Snapshot helper diff path returns "diff" status (not just bootstrap)

const GtmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GtmlHtmlParser.gd")
const GtmlCssParserScript = preload("res://addons/gtml/src/css/GtmlCssParser.gd")
const GtmlSelectorScript = preload("res://addons/gtml/src/css/GtmlSelector.gd")
const GtmlStyleResolverScript = preload("res://addons/gtml/src/css/GtmlStyleResolver.gd")
const SnapshotHelperScript = preload("res://tests/unit/snapshot_helper.gd")


func _parse_html(s: String):
	return GtmlHtmlParserScript.new().parse(s)


#region Entity edge cases


func test_entity_numeric_overflow_clamped() -> void:
	# A codepoint past 0x10FFFF must not crash or produce an invalid String.
	# Per the HTML spec invalid numeric refs become U+FFFD (replacement).
	var dom = _parse_html("<p>&#999999999;</p>")
	var text: String = dom.children[0].text if dom.children.size() > 0 else ""
	assert_false(text.contains("&#999999999;"), "overflow entity must not survive verbatim")
	assert_eq(text, "�", "overflow must be replaced with U+FFFD")


func test_entity_surrogate_rejected() -> void:
	# Lone surrogates are invalid HTML; they should be replaced with U+FFFD,
	# never passed through as the raw entity. We can't construct String.chr(0xD800)
	# to assert against (Godot returns U+FFFD for invalid surrogates), so we
	# instead assert: (a) the raw &#xD800; sequence did not survive, and
	# (b) the resulting text is exactly the replacement character.
	var dom = _parse_html("<p>&#xD800;</p>")
	var text: String = dom.children[0].text if dom.children.size() > 0 else ""
	assert_false(text.contains("&#xD800;"), "surrogate entity must not survive verbatim")
	assert_eq(text, "�", "surrogate must be replaced with U+FFFD")


func test_entity_ampersand_at_end_of_text() -> void:
	var dom = _parse_html("<p>foo&</p>")
	assert_eq(dom.children[0].text, "foo&")


func test_entity_empty_body_preserved() -> void:
	# &; is not a valid entity — should pass through verbatim.
	var dom = _parse_html("<p>a&;b</p>")
	assert_eq(dom.children[0].text, "a&;b")


func test_entity_in_event_handler_attribute() -> void:
	var dom = _parse_html('<button @click="run(&quot;x&quot;)">go</button>')
	assert_eq(dom.attrs.get("@click", ""), 'run("x")')


#endregion


#region Selector splitter quote/bracket handling


func test_selector_splitter_respects_brackets_with_commas() -> void:
	# parse_group must NOT split inside [data-x="a,b"]
	var sels: Array = GtmlSelectorScript.parse_group('a[data-x="a,b"], p')
	assert_eq(sels.size(), 2)
	# First selector should have one compound with the attribute matching the literal "a,b"
	var first = sels[0]
	assert_eq(first.compounds.size(), 1)
	assert_eq(first.compounds[0].attrs.size(), 1)
	assert_eq(first.compounds[0].attrs[0].value, "a,b")


func test_selector_splitter_respects_parens_with_commas() -> void:
	# parse_group must NOT split inside :not(.x, .y) — even though :not isn't
	# yet supported, the splitter has to cope so we don't blow up on v0.3 input.
	var sels: Array = GtmlSelectorScript.parse_group(':not(.x, .y), p')
	assert_eq(sels.size(), 2)


func test_attribute_value_with_closing_bracket_inside_quotes() -> void:
	# The attribute selector ] finder must respect quotes so [data-x="a]b"]
	# is not truncated to [data-x="a].
	var sel = GtmlSelectorScript.parse('a[data-x="a]b"]')
	assert_eq(sel.compounds.size(), 1)
	assert_eq(sel.compounds[0].attrs.size(), 1)
	assert_eq(sel.compounds[0].attrs[0].value, "a]b")


#endregion


#region Resolver: unknown pseudo handling


func _find_by_id(node, id: String):
	if node == null or node.is_text_node:
		return null
	if node.get_id() == id:
		return node
	for c in node.children:
		var r = _find_by_id(c, id)
		if r != null:
			return r
	return null


func test_unknown_pseudo_does_not_pollute_base_style() -> void:
	# Bug fix: a typo'd pseudo (`:hovr`) used to be merged into the base style,
	# which silently changed the un-hovered appearance. It should be dropped.
	var dom = GtmlHtmlParserScript.new().parse("<button id='target' class='btn'>x</button>")
	var rules := GtmlCssParserScript.new().parse(".btn { color: blue; } .btn:hovr { color: red; }")
	var styles: Dictionary = GtmlStyleResolverScript.new().resolve(dom, rules)
	var target = _find_by_id(dom, "target")
	var s: Dictionary = styles.get(target, {})
	# Base color must be blue; the typo rule must not have leaked.
	assert_eq(s.get("color"), Color.BLUE)


#endregion


#region Snapshot helper


func test_snapshot_helper_returns_diff_status_on_mismatch() -> void:
	var dir := "res://tests/snapshots/"
	var name := "_test_diff_probe"
	var path := dir + name + ".json"

	# Write a known snapshot directly so subsequent match_snapshot sees a diff.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\n  \"v\": 1\n}\n")
	f.close()

	var result: Dictionary = SnapshotHelperScript.match_snapshot(name, {"v": 2})
	assert_eq(result.get("status", ""), "diff")
	assert_true(result.has("expected"))
	assert_true(result.has("actual"))

	# Cleanup so a re-run doesn't accumulate test files.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


#endregion
