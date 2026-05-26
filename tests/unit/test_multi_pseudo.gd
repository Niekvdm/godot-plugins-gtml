extends GutTest

## v0.3: multi-pseudo combined states.
##
## A selector like ``a:hover:focus`` should resolve into a bucket that the
## renderer applies only when ALL of {hover, focus} are simultaneously active.
## Single-pseudo styles still work and stack — the more-specific combined
## state wins when its full pseudo set is active.

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")


func _resolved_style(html: String, css: String, id: String) -> Dictionary:
	var dom = GmlHtmlParserScript.new().parse(html)
	var rules := GmlCssParserScript.new().parse(css)
	var styles: Dictionary = GmlStyleResolverScript.new().resolve(dom, rules)
	var node = _find_by_id(dom, id)
	if node == null:
		return {}
	return styles.get(node, {})


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


func test_single_pseudo_still_emits_legacy_flat_key() -> void:
	# Backward compat: existing transition code reads style["_hover"].
	var s := _resolved_style(
		"<button id='target'>x</button>",
		"button:hover { color: red; }",
		"target")
	assert_true(s.has("_hover"), "single :hover must still emit the _hover bucket")
	assert_eq(s["_hover"].get("color"), Color.RED)


func test_multi_pseudo_emits_combined_bucket() -> void:
	var s := _resolved_style(
		"<button id='target'>x</button>",
		"button:hover:focus { color: red; }",
		"target")
	# Sorted state-pseudo bucket key is "focus+hover" (alphabetical).
	assert_true(s.has("_focus+hover"),
		"multi :hover:focus must emit a combined-state bucket, got keys: %s" % str(s.keys()))
	assert_eq(s["_focus+hover"].get("color"), Color.RED)


func test_multi_pseudo_bucket_key_is_sorted_regardless_of_source_order() -> void:
	# focus:hover and hover:focus should land in the same bucket.
	var s := _resolved_style(
		"<button id='target'>x</button>",
		"button:focus:hover { color: red; }",
		"target")
	assert_true(s.has("_focus+hover"))


func test_single_and_multi_coexist() -> void:
	var s := _resolved_style(
		"<button id='target'>x</button>",
		"button:hover { color: blue; } button:hover:focus { color: red; }",
		"target")
	assert_eq(s.get("_hover", {}).get("color"), Color.BLUE)
	assert_eq(s.get("_focus+hover", {}).get("color"), Color.RED)


func test_combined_bucket_wins_when_all_pseudos_active() -> void:
	# Direct test of TransitionSetup's target-style computation: when both
	# hover and focus are active, the focus+hover bucket must layer over the
	# single _hover bucket (and over base).
	var style := {
		"color": Color.GREEN,
		"_hover": {"color": Color.BLUE},
		"_focus+hover": {"color": Color.RED},
	}
	var base := GtmlTransitionSetupTestProxy.strip_state_keys(style)
	var buckets := GtmlTransitionSetupTestProxy.collect_state_buckets(style)

	var only_hover: Dictionary = GtmlTransitionSetupTestProxy.compute_target(base, buckets, {"hover": true, "focus": false})
	assert_eq(only_hover.get("color"), Color.BLUE, "hover-only should apply _hover bucket")

	var both: Dictionary = GtmlTransitionSetupTestProxy.compute_target(base, buckets, {"hover": true, "focus": true})
	assert_eq(both.get("color"), Color.RED, "hover+focus should apply combined bucket")

	var none: Dictionary = GtmlTransitionSetupTestProxy.compute_target(base, buckets, {"hover": false, "focus": false})
	assert_eq(none.get("color"), Color.GREEN, "no states should leave base color")


func test_active_and_disabled_buckets_resolve_but_never_fire_on_non_buttons() -> void:
	# Document the intentional limitation: the generic GmlTransitionSetup only
	# tracks hover + focus signals on plain controls. _active / _disabled
	# buckets parse and land on the style, but the runtime won't toggle them
	# unless the element type drives those signals (buttons do; inputs/anchors
	# don't yet). This test pins the resolver behavior so a future contributor
	# can see the buckets exist and only the wiring is missing.
	var s := _resolved_style(
		"<a id='target' href='#'>x</a>",
		"a:active { color: red; } a:disabled { color: gray; }",
		"target")
	assert_true(s.has("_active"), "active bucket must still resolve so future wiring picks it up")
	assert_true(s.has("_disabled"), "disabled bucket must still resolve so future wiring picks it up")


func test_unknown_pseudo_in_multi_drops_rule() -> void:
	# :hover:hovr — one valid + one typo. The whole rule should be dropped
	# rather than silently routed into the _hover bucket (which would
	# overwrite the un-typo'd :hover style).
	var s := _resolved_style(
		"<button id='target'>x</button>",
		"button:hover { color: blue; } button:hover:hovr { color: red; }",
		"target")
	# _hover bucket must NOT have been polluted by the typo'd rule
	assert_eq(s.get("_hover", {}).get("color"), Color.BLUE)
	# And no combined bucket should have been emitted for the bad rule
	for k in s.keys():
		if str(k).begins_with("_") and "hovr" in str(k):
			fail_test("typo pseudo leaked into bucket %s" % k)
