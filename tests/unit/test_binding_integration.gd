extends GutTest

## End-to-end tests: instantiate GtmlView, set state, verify DOM reacts.

const GtmlViewScript = preload("res://addons/gtml/src/GtmlView.gd")


func _build_view(html: String, css: String = "") -> GtmlView:
	var dir := "res://tests/snapshots/.actual/binding_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string(html)
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string(css)
	fc.close()

	var view: GtmlView = GtmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 200)
	add_child_autofree(view)
	return view


func _find_first_label(node: Node) -> Label:
	if node is Label:
		return node
	for c in node.get_children():
		var l = _find_first_label(c)
		if l != null:
			return l
	return null


func test_text_interpolation_updates_dom_on_set() -> void:
	var view := _build_view('<span>Hello, {{ name }}!</span>')
	view.state.set("name", "Ada")
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label)
	assert_eq(label.text, "Hello, Ada!")

	view.state.set("name", "Bob")
	await get_tree().process_frame
	assert_eq(label.text, "Hello, Bob!")


func test_interpolation_updates_when_label_is_wrapped() -> void:
	# text-shadow (also text-decoration / padding) wraps the Label in a
	# container, so the element's `control` is not a Label. Interpolation must
	# still bind to the inner Label, not silently render the literal {{ }}.
	var view := _build_view('<span class="g">{{ name }}</span>', '.g { text-shadow: 0px 0px 4px #00ff00; }')
	view.state.set("name", "Ada")
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label)
	assert_eq(label.text, "Ada", "interpolation must resolve even when the label is wrapped")


func _all_label_texts(node: Node, out: Array = []) -> Array:
	if node is Label:
		out.append(node.text)
	for c in node.get_children():
		_all_label_texts(c, out)
	return out


func test_text_shadow_copies_track_reactive_text() -> void:
	# A reactive label with text-shadow is wrapped with shadow-copy Labels.
	# Same-width updates ("AAA" -> "BBB") don't fire resize, so the copies must
	# be synced every frame — otherwise stale ghosts remain (counter ghosting).
	var view := _build_view('<span class="g">{{ n }}</span>', '.g { text-shadow: 0px 0px 4px #00ff00; }')
	view.state.set("n", "AAA")
	await get_tree().process_frame
	await get_tree().process_frame
	view.state.set("n", "BBB")
	await get_tree().process_frame
	await get_tree().process_frame
	var texts := _all_label_texts(view)
	assert_false(texts.has("AAA"), "no stale shadow copy should remain after a same-width update")
	assert_true(texts.has("BBB"), "all label layers show the new value")


func test_v_if_omits_subtree_when_falsy() -> void:
	# Empty initial state → v-if="show" reads null → falsy → element omitted.
	var view := _build_view('<div><span v-if="show">shown</span></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_null(label, "v-if=false should omit the span entirely")


func test_v_show_initially_hides_then_shows() -> void:
	var view := _build_view('<div><span v-show="visible">x</span></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label, "v-show keeps element in tree")
	assert_false(label.visible)
	view.state.set("visible", true)
	await get_tree().process_frame
	assert_true(label.visible)


# ─── v-for tests (Task 7) ──────────────────────────────────────

func test_v_for_renders_one_child_per_array_element() -> void:
	var view := _build_view('<ul><li v-for="item in items">{{ item.name }}</li></ul>')
	view.state.set("items", [{"name": "Sword"}, {"name": "Potion"}])
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array = []
	_collect_label_texts(view, texts)
	assert_true("Sword" in texts, "Sword not found in %s" % str(texts))
	assert_true("Potion" in texts, "Potion not found in %s" % str(texts))


func test_v_for_rebuilds_on_array_change() -> void:
	var view := _build_view('<ul><li v-for="item in items">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b"])
	await get_tree().process_frame
	await get_tree().process_frame
	var texts1: Array = []
	_collect_label_texts(view, texts1)
	assert_true("a" in texts1 and "b" in texts1)

	view.state.set("items", ["x", "y", "z"])
	await get_tree().process_frame
	var texts2: Array = []
	_collect_label_texts(view, texts2)
	assert_true("x" in texts2 and "y" in texts2 and "z" in texts2)
	assert_false("a" in texts2, "old item 'a' should be torn down")


func test_v_for_indexed_form_exposes_index() -> void:
	var view := _build_view('<ul><li v-for="item, i in items">{{ i }}: {{ item }}</li></ul>')
	view.state.set("items", ["alpha", "beta"])
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array = []
	_collect_label_texts(view, texts)
	assert_true("0: alpha" in texts)
	assert_true("1: beta" in texts)


func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_label_texts(c, out)


# ─── v-model + @event(args) (Task 8) ───────────────────────────

func test_v_model_text_input_state_to_control() -> void:
	var view := _build_view('<input v-model="email">')
	view.state.set("email", "ada@example.com")
	await get_tree().process_frame
	await get_tree().process_frame
	var line := _find_first_line_edit(view)
	assert_not_null(line)
	assert_eq(line.text, "ada@example.com")


func test_v_model_text_input_control_to_state() -> void:
	var view := _build_view('<input v-model="search">')
	view.state.set("search", "")
	await get_tree().process_frame
	await get_tree().process_frame
	var line := _find_first_line_edit(view)
	line.text = "sword"
	line.text_changed.emit("sword")
	assert_eq(view.state.get("search"), "sword")


func test_v_model_checkbox_two_way() -> void:
	var view := _build_view('<input type="checkbox" v-model="opt">')
	view.state.set("opt", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var cb := _find_first_check_box(view)
	assert_not_null(cb)
	assert_true(cb.button_pressed)

	cb.button_pressed = false
	cb.toggled.emit(false)
	assert_false(view.state.get("opt"))


func test_event_handler_with_args_fires_item_clicked() -> void:
	var view := _build_view('<ul><li v-for="item, i in items" @click="select(item, i)">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b", "c"])
	await get_tree().process_frame
	await get_tree().process_frame

	var captured: Array = []
	view.item_clicked.connect(func(handler, args):
		captured.append([handler, args])
	)
	var li_controls: Array = []
	_collect_v_for_clones(view, li_controls)
	assert_eq(li_controls.size(), 3)
	for ctl in li_controls:
		if ctl.has_meta("v_on_click"):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			ctl.gui_input.emit(click)
			break

	assert_gt(captured.size(), 0, "item_clicked should have fired")
	assert_eq(captured[0][0], "select", "handler name should be 'select'")
	assert_eq(captured[0][1].size(), 2, "args should be [item, index]")


func _find_first_line_edit(node: Node) -> LineEdit:
	if node is LineEdit:
		return node
	for c in node.get_children():
		var le = _find_first_line_edit(c)
		if le != null:
			return le
	return null


func _find_first_check_box(node: Node) -> CheckBox:
	if node is CheckBox:
		return node
	for c in node.get_children():
		var cb = _find_first_check_box(c)
		if cb != null:
			return cb
	return null


func _collect_v_for_clones(node: Node, out: Array) -> void:
	if node is Control and (node as Control).has_meta("v_on_click"):
		out.append(node)
	for c in node.get_children():
		_collect_v_for_clones(c, out)


# ─── Operators end-to-end (Task 10) ────────────────────────

func test_v_if_with_comparison() -> void:
	var view := _build_view('<div><span v-if="hp > 0">alive</span></div>')
	view.state.set("hp", 10)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_find_first_label(view), "should be alive when hp > 0")


func test_text_interp_with_indexing() -> void:
	var view := _build_view('<span>{{ items[selected_index].name }}</span>')
	view.state.set("items", [{"name": "Sword"}, {"name": "Potion"}])
	view.state.set("selected_index", 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_eq(label.text, "Sword")

	view.state.set("selected_index", 1)
	await get_tree().process_frame
	assert_eq(label.text, "Potion")


func test_class_binding_with_comparison() -> void:
	var view := _build_view('<div><span :class="{ low: hp < 25 }">x</span></div>')
	view.state.set("hp", 50)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	var classes: PackedStringArray = label.get_meta("dynamic_classes", PackedStringArray())
	assert_eq(classes.size(), 0, "hp=50 → no 'low' class")

	view.state.set("hp", 10)
	await get_tree().process_frame
	classes = label.get_meta("dynamic_classes", PackedStringArray())
	assert_true("low" in classes, "hp=10 → 'low' class active")


func test_event_handler_with_indexing() -> void:
	var view := _build_view('<ul><li v-for="item, i in items" @click="select(items[i])">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b"])
	await get_tree().process_frame
	await get_tree().process_frame

	var captured: Array = []
	view.item_clicked.connect(func(handler, args): captured.append([handler, args]))

	var li_controls: Array = []
	_collect_v_for_clones(view, li_controls)
	assert_eq(li_controls.size(), 2)
	# Click the first one; index arg should resolve to items[0] = "a".
	for ctl in li_controls:
		if ctl.has_meta("v_on_click"):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			ctl.gui_input.emit(click)
			break
	assert_gt(captured.size(), 0)


func test_class_binding_with_ternary() -> void:
	var view := _build_view('<div><span :class="[\'badge\', is_rare ? \'rare\' : \'common\']">x</span></div>')
	view.state.set("is_rare", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	var classes: PackedStringArray = label.get_meta("dynamic_classes", PackedStringArray())
	assert_true("common" in classes)

	view.state.set("is_rare", true)
	await get_tree().process_frame
	classes = label.get_meta("dynamic_classes", PackedStringArray())
	assert_true("rare" in classes)


# ─── v-for :key reconciliation (v0.8.1) ────────────────────

func test_vfor_key_preserves_control_identity_on_reorder() -> void:
	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "b", "name": "Beta"},
		{"id": "c", "name": "Charlie"},
	])
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture references to all built Labels by their initial text.
	var labels_before: Dictionary = {}
	var collected: Array = []
	_collect_label_nodes(view, collected)
	for l in collected:
		labels_before[(l as Label).text] = l

	# Reorder.
	view.state.set("items", [
		{"id": "c", "name": "Charlie"},
		{"id": "a", "name": "Alpha"},
		{"id": "b", "name": "Beta"},
	])
	await get_tree().process_frame

	# Verify the SAME Label objects survive — identity preservation.
	var labels_after: Dictionary = {}
	collected.clear()
	_collect_label_nodes(view, collected)
	for l in collected:
		labels_after[(l as Label).text] = l

	assert_eq(labels_after.get("Alpha"), labels_before.get("Alpha"), "Alpha Label must be the same object")
	assert_eq(labels_after.get("Beta"),  labels_before.get("Beta"),  "Beta Label must be the same object")
	assert_eq(labels_after.get("Charlie"), labels_before.get("Charlie"), "Charlie Label must be the same object")


func test_vfor_key_remove_frees_only_that_clones_bindings() -> void:
	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "b", "name": "Beta"},
	])
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture Alpha's Label.
	var alpha_label: Label = null
	var collected: Array = []
	_collect_label_nodes(view, collected)
	for l in collected:
		if (l as Label).text == "Alpha":
			alpha_label = l
			break
	assert_not_null(alpha_label)

	# Remove Beta.
	view.state.set("items", [{"id": "a", "name": "Alpha"}])
	await get_tree().process_frame

	# Alpha label must still exist + be the same object.
	collected.clear()
	_collect_label_nodes(view, collected)
	var alpha_still: Label = null
	for l in collected:
		if (l as Label).text == "Alpha":
			alpha_still = l
			break
	assert_eq(alpha_still, alpha_label, "Alpha Label survives Beta's removal")


func test_vfor_indexed_form_updates_index_on_reorder() -> void:
	var view := _build_view('<ul><li v-for="item, i in items" :key="item.id">{{ i }}: {{ item.name }}</li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "b", "name": "Beta"},
	])
	await get_tree().process_frame
	await get_tree().process_frame

	view.state.set("items", [
		{"id": "b", "name": "Beta"},
		{"id": "a", "name": "Alpha"},
	])
	await get_tree().process_frame

	var texts: Array = []
	_collect_label_texts(view, texts)
	# After reorder: i=0 paired with Beta, i=1 paired with Alpha.
	assert_true("0: Beta" in texts, "expected '0: Beta' in %s" % str(texts))
	assert_true("1: Alpha" in texts, "expected '1: Alpha' in %s" % str(texts))


func test_vfor_default_index_key_still_reconciles() -> void:
	# No :key attribute — default to index. Reordering still produces
	# the correct final DOM (texts), but identity preservation is by
	# POSITION, not by item — items at same index reuse the Control.
	var view := _build_view('<ul><li v-for="item in items">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b", "c"])
	await get_tree().process_frame
	await get_tree().process_frame

	view.state.set("items", ["x", "y", "z"])
	await get_tree().process_frame

	var texts: Array = []
	_collect_label_texts(view, texts)
	assert_true("x" in texts and "y" in texts and "z" in texts, "expected x,y,z in %s" % str(texts))
	assert_false("a" in texts, "old items should be replaced")


func test_vfor_key_insert_in_middle_only_inserts_one() -> void:
	# Verify the reconciler does the right thing — insert "b" between
	# "a" and "c" reuses both endpoints.
	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "c", "name": "Charlie"},
	])
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture Alpha + Charlie's Labels.
	var labels_before: Dictionary = {}
	var collected: Array = []
	_collect_label_nodes(view, collected)
	for l in collected:
		labels_before[(l as Label).text] = l

	# Insert Beta in the middle.
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "b", "name": "Beta"},
		{"id": "c", "name": "Charlie"},
	])
	await get_tree().process_frame

	collected.clear()
	_collect_label_nodes(view, collected)
	var labels_after: Dictionary = {}
	for l in collected:
		labels_after[(l as Label).text] = l

	# Alpha + Charlie are the SAME objects.
	assert_eq(labels_after.get("Alpha"), labels_before.get("Alpha"))
	assert_eq(labels_after.get("Charlie"), labels_before.get("Charlie"))
	# Beta is new (no entry in labels_before, but exists now).
	assert_true(labels_after.has("Beta"))


func test_vfor_key_duplicate_warns_and_aborts() -> void:
	var captured: Array = []
	GtmlBindingApplier._on_warning = func(m): captured.append(m)

	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "b", "name": "Beta"},
	])
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture initial state.
	var texts_before: Array = []
	_collect_label_texts(view, texts_before)

	# Set to duplicate keys.
	view.state.set("items", [
		{"id": "a", "name": "Alpha"},
		{"id": "a", "name": "Apple"},   # duplicate id
	])
	await get_tree().process_frame

	var dup_warns: Array = captured.filter(func(m): return "duplicate" in m)
	assert_gt(dup_warns.size(), 0, "expected duplicate-key warning")

	# DOM must be UNCHANGED (reconcile aborted).
	var texts_after: Array = []
	_collect_label_texts(view, texts_after)
	assert_true("Alpha" in texts_after)
	assert_true("Beta" in texts_after, "Beta must still render — reconcile aborted")

	GtmlBindingApplier._on_warning = Callable()


func test_vfor_key_null_falls_back_to_index_not_blank() -> void:
	# When :key evaluates to null for every item (missing field), the
	# list must NOT collapse to blank via duplicate-empty-key detection.
	# Null keys fall back to the index.
	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	view.state.set("items", [
		{"name": "Alpha"},   # no id field → :key resolves null
		{"name": "Beta"},
	])
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array = []
	_collect_label_texts(view, texts)
	assert_true("Alpha" in texts, "null-key list must still render (index fallback); got %s" % str(texts))
	assert_true("Beta" in texts)


# Helper: collect Label NODES (not just their text).
# Excludes list-marker Labels — markers are direct children of an HBoxContainer
# (the list-item row) while content Labels live inside a VBoxContainer child.
# Using the parent-type check is more stable than text-content filtering since
# list-style-type symbols vary (•, ○, 1., etc.).
func _collect_label_nodes(node: Node, out: Array) -> void:
	if node is Label and not (node.get_parent() is HBoxContainer):
		out.append(node)
	for c in node.get_children():
		_collect_label_nodes(c, out)


# ─── v0.8.2: css_rules retention ───────────────────────────

func test_view_retains_css_rules_after_build() -> void:
	var view := _build_view('<div class="box">x</div>', '.box { color: #ff0000; }')
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(view._css_rules.size(), 0, "view must retain parsed css_rules for runtime re-resolution")


# ─── v0.8.2: dynamic :class CSS re-resolution ──────────────

func _find_first_span_label(view: GtmlView) -> Label:
	var out: Array = []
	_collect_label_nodes(view, out)
	return out[0] if out.size() > 0 else null


func test_dynamic_class_reresolves_font_color() -> void:
	var view := _build_view(
		'<div><span :class="{ rare: is_rare }" class="name">Item</span></div>',
		'.name { color: #ffffff; } .rare { color: #b59aff; }'
	)
	view.state.set("is_rare", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)
	assert_not_null(label)

	view.state.set("is_rare", true)
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.b, 1.0, 0.06, "rare class should turn font purple-ish")

	view.state.set("is_rare", false)
	await get_tree().process_frame
	var c2: Color = label.get_theme_color("font_color")
	assert_almost_eq(c2.r, 1.0, 0.06)
	assert_almost_eq(c2.b, 1.0, 0.06)


func test_dynamic_class_reresolves_background_on_panel() -> void:
	var view := _build_view(
		'<div :class="{ active: on }" class="card">x</div>',
		'.card { background-color: #222222; } .active { background-color: #ffcc00; }'
	)
	view.state.set("on", false)
	await get_tree().process_frame
	await get_tree().process_frame

	view.state.set("on", true)
	await get_tree().process_frame
	var found := false
	var stack: Array = [view]
	while not stack.is_empty():
		var nd = stack.pop_back()
		if nd is PanelContainer and nd.has_theme_stylebox("panel"):
			var box = nd.get_theme_stylebox("panel")
			if box is StyleBoxFlat and box.bg_color.r > 0.8 and box.bg_color.g > 0.6 and box.bg_color.b < 0.3:
				found = true
				break
		for ch in nd.get_children():
			stack.append(ch)
	assert_true(found, "active class should set goldish panel background")


func test_dynamic_class_low_hp_turns_red() -> void:
	var view := _build_view(
		'<div><span :class="{ low: hp < 25 }" class="hp">HP</span></div>',
		'.hp { color: #ffffff; } .low { color: #ff0000; }'
	)
	view.state.set("hp", 100)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)

	view.state.set("hp", 10)
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 1.0, 0.06)
	assert_almost_eq(c.g, 0.0, 0.06, "low hp should turn red")


func test_dynamic_class_array_syntax_swaps_rarity() -> void:
	var view := _build_view(
		'<div><span :class="[\'badge\', rarity]" class="b">x</span></div>',
		'.common { color: #888888; } .epic { color: #cc44ff; }'
	)
	view.state.set("rarity", "common")
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)

	view.state.set("rarity", "epic")
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.b, 1.0, 0.1, "epic rarity should turn purple-ish")


func test_dynamic_class_in_vfor_clone_reresolves() -> void:
	var view := _build_view(
		'<ul><li v-for="item in items" :key="item.id" :class="{ sel: item.active }" class="row">{{ item.name }}</li></ul>',
		'.row { color: #ffffff; } .sel { color: #00ff00; }'
	)
	view.state.set("items", [
		{"id": "a", "name": "A", "active": false},
		{"id": "b", "name": "B", "active": true},
	])
	await get_tree().process_frame
	await get_tree().process_frame
	var labels: Array = []
	_collect_label_nodes(view, labels)
	var any_green := false
	for l in labels:
		var c: Color = (l as Label).get_theme_color("font_color")
		if c.g > 0.8 and c.r < 0.2:
			any_green = true
			break
	assert_true(any_green, "v-for clone with :class sel should re-resolve green")


func test_dynamic_class_descendant_from_ancestor_NOT_reresolved() -> void:
	# Documented limitation (spec §6.1): toggling a class on the CARD does
	# NOT re-resolve a child styled by `.card.selected .name`.
	var view := _build_view(
		'<div :class="{ selected: on }" class="card"><span class="name">child</span></div>',
		'.name { color: #ffffff; } .card.selected .name { color: #ff0000; }'
	)
	view.state.set("on", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)

	view.state.set("on", true)
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 1.0, 0.06)
	assert_almost_eq(c.g, 1.0, 0.06, "child must NOT turn red — documented limitation")


# ─── v0.8.3: focus stamping (Task 2) ───────────────────────────────

func test_clickable_span_gets_focus_mode_all() -> void:
	var view := _build_view('<div><span @click="x">click me</span></div>')
	view.state.set("x", null)
	await get_tree().process_frame
	await get_tree().process_frame
	var found := false
	var stack: Array = [view]
	while not stack.is_empty():
		var nd = stack.pop_back()
		if nd is Control and (nd as Control).get_meta("_gtml_focusable", false):
			if (nd as Control).focus_mode == Control.FOCUS_ALL:
				found = true
				break
		for ch in nd.get_children():
			stack.append(ch)
	assert_true(found, "a @click element should be focusable with FOCUS_ALL")


# ─── v0.8.3: focus traversal end-to-end (Task 5) ───────────

func test_focus_two_buttons_chain() -> void:
	var view := _build_view('<div><button @click="a">A</button><button @click="b">B</button></div>')
	view.state.set("a", null)
	view.state.set("b", null)
	await get_tree().process_frame
	await get_tree().process_frame
	var focusables: Array = []
	_collect_focusables(view, focusables)
	assert_gte(focusables.size(), 2, "two buttons focusable; got %d" % focusables.size())
	var a: Control = focusables[0]
	var b: Control = focusables[1]
	assert_eq(a.get_node(a.focus_next), b, "button A.focus_next → B")


func test_focus_anchor_is_focusable() -> void:
	var view := _build_view('<div><a href="x">link</a></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var focusables: Array = []
	_collect_focusables(view, focusables)
	assert_gt(focusables.size(), 0, "anchor should be focusable")


func test_autofocus_grabs_focus() -> void:
	var view := _build_view('<div><input v-model="q" autofocus></div>')
	view.state.set("q", "")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var focused = get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "autofocus should grab a control")
	assert_true(focused.get_meta("_gtml_focusable", false), "focused control is the autofocus target")


func test_focus_trap_wraps() -> void:
	var view := _build_view('<div focus-trap><button @click="a">A</button><button @click="b">B</button></div>')
	view.state.set("a", null)
	view.state.set("b", null)
	await get_tree().process_frame
	await get_tree().process_frame
	var focusables: Array = []
	_collect_focusables(view, focusables)
	assert_eq(focusables.size(), 2)
	var a: Control = focusables[0]
	var b: Control = focusables[1]
	assert_eq(b.get_node(b.focus_next), a, "trap: B wraps to A")
	assert_eq(a.get_node(a.focus_previous), b, "trap: A wraps to B")


func test_tabindex_minus_one_skips_tab_chain() -> void:
	var view := _build_view('<div><button @click="a">A</button><button @click="b" tabindex="-1">B</button><button @click="c">C</button></div>')
	view.state.set("a", null)
	view.state.set("b", null)
	view.state.set("c", null)
	await get_tree().process_frame
	await get_tree().process_frame
	var focusables: Array = []
	_collect_focusables(view, focusables)
	var a: Control = null
	var c: Control = null
	for f in focusables:
		var t := _button_text(f)
		if t == "A":
			a = f
		elif t == "C":
			c = f
	assert_not_null(a)
	assert_not_null(c)
	assert_eq(a.get_node(a.focus_next), c, "A skips tabindex=-1 B → C")


func test_vfor_append_keeps_focus_and_chains_new_clone() -> void:
	var view := _build_view('<ul><li v-for="item in items" :key="item.id"><input :value="item.name"></li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "A"},
		{"id": "b", "name": "B"},
	])
	await get_tree().process_frame
	await get_tree().process_frame
	var inputs: Array = []
	_collect_line_edits(view, inputs)
	assert_eq(inputs.size(), 2)
	inputs[0].grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), inputs[0])
	view.state.set("items", [
		{"id": "a", "name": "A"},
		{"id": "b", "name": "B"},
		{"id": "c", "name": "C"},
	])
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), inputs[0], "focus preserved across append")
	var inputs2: Array = []
	_collect_line_edits(view, inputs2)
	assert_eq(inputs2.size(), 3, "third input clone added")


# Helper: collect controls carrying _gtml_focusable, in document order.
func _collect_focusables(node: Node, out: Array) -> void:
	if node is Control and (node as Control).get_meta("_gtml_focusable", false):
		out.append(node)
	for c in node.get_children():
		_collect_focusables(c, out)


func _collect_line_edits(node: Node, out: Array) -> void:
	if node is LineEdit:
		out.append(node)
	for c in node.get_children():
		_collect_line_edits(c, out)


func _button_text(c: Control) -> String:
	if c is Button:
		return (c as Button).text
	return ""
