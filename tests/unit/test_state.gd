extends GutTest

## Tests for GtmlState — the per-view reactive store.

func test_set_then_get_returns_value() -> void:
	var s := GtmlState.new()
	s.set("score", 42)
	assert_eq(s.get("score"), 42)


func test_get_missing_key_returns_null() -> void:
	var s := GtmlState.new()
	assert_null(s.get("nope"))


func test_has_returns_true_when_set_false_when_not() -> void:
	var s := GtmlState.new()
	assert_false(s.has("x"))
	s.set("x", 1)
	assert_true(s.has("x"))


func test_set_emits_state_changed_with_old_and_new() -> void:
	var s := GtmlState.new()
	s.set("score", 10)
	var captured: Array = []
	s.state_changed.connect(func(k, n, o): captured.append([k, n, o]))
	s.set("score", 20)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], ["score", 20, 10])


func test_set_same_value_does_not_emit() -> void:
	var s := GtmlState.new()
	s.set("score", 10)
	var captured: Array = []
	s.state_changed.connect(func(k, n, o): captured.append(k))
	s.set("score", 10)
	assert_eq(captured.size(), 0, "setting unchanged value must not emit")


func test_first_set_emits_with_null_old() -> void:
	var s := GtmlState.new()
	var captured: Array = []
	s.state_changed.connect(func(k, n, o): captured.append([k, n, o]))
	s.set("new_key", "v")
	assert_eq(captured[0], ["new_key", "v", null])


func test_set_state_batched_emits_per_changed_key() -> void:
	var s := GtmlState.new()
	s.set("a", 1)
	var captured: Array = []
	s.state_changed.connect(func(k, _n, _o): captured.append(k))
	s.set_state({"a": 1, "b": 2, "c": 3})
	# 'a' unchanged so no emit; 'b' and 'c' fire
	assert_eq(captured.size(), 2)
	assert_true("b" in captured)
	assert_true("c" in captured)


func test_keys_returns_set_keys() -> void:
	var s := GtmlState.new()
	s.set("a", 1)
	s.set("player.health", 100)
	var keys: PackedStringArray = s.keys()
	assert_eq(keys.size(), 2)
	assert_true("a" in keys)
	assert_true("player.health" in keys)
