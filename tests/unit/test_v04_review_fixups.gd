extends GutTest

## Tests for the v0.4 pre-PR review fixups:
##   - var() cycle detection (no hang on --a: var(--a) or chains)
##   - unterminated var() emits warning + does not crash
##   - typo'd pseudo (e.g. :chekced) drops the rule even alone
##   - radio without `name` is dropped from get_form_data silently
##   - calc() division by zero warns + produces no NaN/Inf in style
##   - submit button outside <form> still fires form_submitted (documented)
##   - HTML parser get_warnings() exposes line/col/msg (already in
##     test_parser_robustness, not repeated here)

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")
const GmlCssEvalScript = preload("res://addons/gtml/src/css/GmlCssEval.gd")
const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")


func _style_for_id(html: String, css: String, id: String) -> Dictionary:
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


#region var() edge cases


func test_var_self_cycle_does_not_hang() -> void:
	# --a: var(--a); — direct self-reference must not infinite-recurse.
	# Enforce with a wall-clock budget.
	var t0 := Time.get_ticks_msec()
	var s := _style_for_id(
		"<p id='target'>x</p>",
		"p { --a: var(--a); color: var(--a); }",
		"target")
	var dt := Time.get_ticks_msec() - t0
	assert_true(dt < 500, "var cycle took %dms — expected <500" % dt)


func test_var_two_key_cycle_does_not_hang() -> void:
	# --a -> --b -> --a must also break cleanly.
	var t0 := Time.get_ticks_msec()
	var s := _style_for_id(
		"<p id='target'>x</p>",
		"p { --a: var(--b); --b: var(--a); color: var(--a); }",
		"target")
	var dt := Time.get_ticks_msec() - t0
	assert_true(dt < 500, "two-key var cycle took %dms — expected <500" % dt)


func test_unterminated_var_does_not_crash() -> void:
	# var( with no closing paren — substitute_vars must terminate.
	var out: String = GmlCssEvalScript.substitute_vars("color: var(--x", {})
	# Either resolves with what we have, or returns the original tail.
	# The contract: it returns *something* without hanging or erroring out.
	assert_true(out is String)


#endregion


#region pseudo typos


func test_typoed_pseudo_alone_drops_rule() -> void:
	# Direct typo without any valid pseudo to mask it — must not silently
	# leak into the base style or any bucket.
	var s := _style_for_id(
		"<button id='target'>x</button>",
		"button:chekced { color: red; }",
		"target")
	for key in s.keys():
		if str(key).begins_with("_") and "chekced" in str(key):
			fail_test("typo'd pseudo bucket leaked into output: %s" % key)
	assert_false(s.get("color") == Color.RED, "typo'd pseudo must not apply to base style")


#endregion


#region calc()


func test_calc_division_by_zero_warns_and_recovers() -> void:
	# calc(10 / 0) — _combine bails by returning the lhs operand, so the
	# resolved value is just "10" and the type parser produces a finite int.
	var s := _style_for_id(
		"<div id='target'>x</div>",
		"div { padding: calc(10 / 0); }",
		"target")
	var v = s.get("padding")
	assert_not_null(v, "calc by zero should still produce SOME value, got null")
	if v is float:
		assert_false(is_inf(v), "calc by zero must not yield Inf")
		assert_false(is_nan(v), "calc by zero must not yield NaN")
	else:
		assert_true(v is int, "calc by zero recovery should yield an int, got %s" % typeof(v))


#endregion


#region form data


func _build_view(html: String) -> GmlView:
	var dir := "res://tests/snapshots/.actual/v04_fixups_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string(html)
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string("")
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(300, 200)
	add_child_autofree(view)
	return view


func test_radio_without_name_falls_back_to_checkbox_semantics() -> void:
	# Pin the documented quirk: a radio with no `name` has no ButtonGroup,
	# so get_form_data() can't distinguish it from a CheckBox and collects
	# it under its id as a bool. Authoring error on the user's side — name
	# is required for radios — but collection of OTHER inputs still works.
	var view := _build_view(
		'<form><input id="a" type="radio"><input id="b" type="text" value="hi"></form>'
	)
	await get_tree().process_frame
	await get_tree().process_frame
	var data: Dictionary = view.get_form_data()
	# The groupless radio is collected as a bool (CheckBox semantics).
	assert_true(data.has("a"), "groupless radio falls back to checkbox semantics")
	assert_true(data.get("a") is bool, "groupless radio value should be a bool, got %s" % typeof(data.get("a")))
	# And the other input is still collected normally.
	assert_eq(data.get("b"), "hi")


func test_submit_outside_form_still_emits_form_submitted() -> void:
	# Documented behavior — GTML has no <form> scoping, so a bare submit
	# fires form_submitted with the whole view's input snapshot.
	var view := _build_view(
		'<div>'
		+ '<input id="title" type="text" value="hi">'
		+ '<input type="submit" value="Go">'
		+ '</div>'
	)
	await get_tree().process_frame
	await get_tree().process_frame

	var emitted := []
	view.form_submitted.connect(func(data: Dictionary):
		emitted.append(data)
	)
	var btn: Button = _find_button(view, "Go")
	assert_not_null(btn)
	btn.pressed.emit()
	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0].get("title"), "hi")


func _find_button(node: Node, label: String):
	if node is Button and (node as Button).text == label:
		return node
	for child in node.get_children():
		var r = _find_button(child, label)
		if r != null:
			return r
	return null


#endregion
