extends GutTest

## Tests for GmlBindingApplier — evaluates AST + writes to controls.


func _state(values: Dictionary = {}) -> GmlState:
	var s := GmlState.new()
	for k in values:
		s.set(k, values[k])
	return s


# ─── eval() basics ───────────────────────────────────────────────

func test_eval_path_returns_state_value() -> void:
	var s := _state({"score": 42})
	var ast: Dictionary = GmlBindingExpr.parse("score")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), 42)


func test_eval_dotted_path_reads_flat_key() -> void:
	var s := _state({"player.health": 85})
	var ast: Dictionary = GmlBindingExpr.parse("player.health")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), 85)


func test_eval_path_falls_back_to_scope_first() -> void:
	# Loop scope shadows global state for the duration of v-for.
	var s := _state({"item": "global_value"})
	var ast: Dictionary = GmlBindingExpr.parse("item")
	var scope := {"item": "loop_value"}
	assert_eq(GmlBindingApplier.eval(ast, s, scope), "loop_value")


func test_eval_negation_inverts_truthy() -> void:
	var s := _state({"loading": false})
	var ast: Dictionary = GmlBindingExpr.parse("!loading")
	assert_true(GmlBindingApplier.eval(ast, s, {}))


func test_eval_string_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("'hello'")
	assert_eq(GmlBindingApplier.eval(ast, _state(), {}), "hello")


# ─── Text interpolation end-to-end ───────────────────────────────

func test_register_text_interpolation_initial_apply_writes_label() -> void:
	var s := _state({"name": "Ada"})
	var r := GmlBindingRegistry.new()
	var label := Label.new()
	label.text = "{{ name }}"
	add_child_autofree(label)
	var spans: Array = GmlBindingParser.find_interpolations("Hello, {{ name }}!")
	GmlBindingApplier.register_text_interpolation(label, spans, r, s)
	assert_eq(label.text, "Hello, Ada!")


func test_register_text_interpolation_updates_on_state_change() -> void:
	var s := _state({"name": "Ada"})
	var r := GmlBindingRegistry.new()
	var label := Label.new()
	add_child_autofree(label)
	var spans: Array = GmlBindingParser.find_interpolations("Hello, {{ name }}!")
	GmlBindingApplier.register_text_interpolation(label, spans, r, s)
	s.state_changed.connect(func(k, _n, _o): r.fire(k))
	s.set("name", "Bob")
	assert_eq(label.text, "Hello, Bob!")


# ─── Attribute binding ──────────────────────────────────────────

func test_register_attr_binding_disabled_writes_bool() -> void:
	var s := _state({"locked": true})
	var r := GmlBindingRegistry.new()
	var btn := Button.new()
	add_child_autofree(btn)
	var ast: Dictionary = GmlBindingExpr.parse("locked")
	GmlBindingApplier.register_attr_binding(btn, "disabled", ast, r, s)
	assert_true(btn.disabled)
	s.state_changed.connect(func(k, _n, _o): r.fire(k))
	s.set("locked", false)
	assert_false(btn.disabled)


func test_register_attr_binding_value_writes_text() -> void:
	var s := _state({"name": "Ada"})
	var r := GmlBindingRegistry.new()
	var line := LineEdit.new()
	add_child_autofree(line)
	var ast: Dictionary = GmlBindingExpr.parse("name")
	GmlBindingApplier.register_attr_binding(line, "value", ast, r, s)
	assert_eq(line.text, "Ada")


func test_register_attr_binding_unknown_target_is_noop() -> void:
	var s := _state({"x": 1})
	var r := GmlBindingRegistry.new()
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var ast: Dictionary = GmlBindingExpr.parse("x")
	GmlBindingApplier.register_attr_binding(ctrl, "unrecognized_attr", ast, r, s)
	# Pass criterion: didn't crash
	assert_true(true)


# ─── Object/array eval (Task 5) ──────────────────────────────────

func test_eval_object_returns_filtered_keys_by_truthy_values() -> void:
	var s := _state({"is_active": true, "is_dim": false})
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_active, dim: is_dim }")
	var result = GmlBindingApplier.eval(ast, s, {})
	# Object eval returns the keys whose values are truthy, as PackedStringArray
	assert_true(result is PackedStringArray)
	assert_eq(result.size(), 1)
	assert_eq(result[0], "active")


func test_eval_object_with_negation() -> void:
	var s := _state({"is_loading": false})
	var ast: Dictionary = GmlBindingExpr.parse("{ ready: !is_loading }")
	var result = GmlBindingApplier.eval(ast, s, {})
	assert_eq(result.size(), 1)
	assert_eq(result[0], "ready")


func test_eval_array_returns_concatenated_strings() -> void:
	var s := _state({"dyn": "highlighted"})
	var ast: Dictionary = GmlBindingExpr.parse("['static', dyn]")
	var result = GmlBindingApplier.eval(ast, s, {})
	assert_true(result is PackedStringArray)
	assert_eq(result.size(), 2)
	assert_eq(result[0], "static")
	assert_eq(result[1], "highlighted")


# ─── :class registration ─────────────────────────────────────────

func test_register_class_binding_writes_meta_classes() -> void:
	var s := _state({"is_on": true})
	var r := GmlBindingRegistry.new()
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_on }")
	GmlBindingApplier.register_class_binding(ctrl, ast, r, s)
	var classes: PackedStringArray = ctrl.get_meta("dynamic_classes", PackedStringArray())
	assert_eq(classes.size(), 1)
	assert_eq(classes[0], "active")

	s.state_changed.connect(func(k, _n, _o): r.fire(k))
	s.set("is_on", false)
	classes = ctrl.get_meta("dynamic_classes", PackedStringArray())
	assert_eq(classes.size(), 0)


# ─── Warning logger (Task 1) ──────────────────────────────────

func test_on_warning_callable_receives_message_when_set() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(msg): captured.append(msg)
	GmlBindingApplier._warn("test message")
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], "test message")
	GmlBindingApplier._on_warning = Callable()   # reset


func test_warn_falls_back_to_push_warning_when_unset() -> void:
	GmlBindingApplier._on_warning = Callable()
	# Just assert it doesn't crash; push_warning's effect isn't asserted.
	GmlBindingApplier._warn("hello")
	assert_true(true)


# ─── Indexing eval (Task 3) ────────────────────────────────

func test_eval_array_index_returns_element() -> void:
	var s := _state({"items": ["a", "b", "c"]})
	var ast: Dictionary = GmlBindingExpr.parse("items[1]")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), "b")


func test_eval_dict_index_returns_value() -> void:
	var s := _state({"map": {"k": "v"}})
	var ast: Dictionary = GmlBindingExpr.parse("map['k']")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), "v")


func test_eval_index_out_of_bounds_returns_null_no_warn() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var s := _state({"items": ["a"]})
	var ast: Dictionary = GmlBindingExpr.parse("items[5]")
	assert_null(GmlBindingApplier.eval(ast, s, {}))
	assert_eq(captured.size(), 0, "OOB index must NOT warn (transient v-for state)")
	GmlBindingApplier._on_warning = Callable()


# ─── Unary minus eval (Task 4) ─────────────────────────────

func test_eval_unary_minus_number() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("-5")
	assert_eq(GmlBindingApplier.eval(ast, _state(), {}), -5.0)


func test_eval_unary_minus_string_warns_returns_null() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var ast: Dictionary = GmlBindingExpr.parse("-name")
	assert_null(GmlBindingApplier.eval(ast, _state({"name": "Ada"}), {}))
	assert_gt(captured.size(), 0)
	GmlBindingApplier._on_warning = Callable()
