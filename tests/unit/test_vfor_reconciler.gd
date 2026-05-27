extends GutTest

## Pure-data tests for GmlVForReconciler.diff(old_keys, new_keys).
## No Godot scene tree access.

func _keys(arr: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k in arr:
		out.append(str(k))
	return out


# ─── No-op / fast paths ────────────────────────────────────

func test_diff_identical_arrays_emits_no_ops() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c"]), _keys(["a", "b", "c"]))
	assert_eq(ops.size(), 0)


func test_diff_both_empty_emits_no_ops() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys([]), _keys([]))
	assert_eq(ops.size(), 0)


# ─── Pure append / prepend / remove ───────────────────────

func test_diff_all_append() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b"]), _keys(["a", "b", "c", "d"]))
	assert_eq(ops.size(), 2)
	assert_eq(ops[0]["op"], "insert")
	assert_eq(ops[0]["key"], "c")
	assert_eq(ops[0]["to_index"], 2)
	assert_eq(ops[1]["op"], "insert")
	assert_eq(ops[1]["key"], "d")
	assert_eq(ops[1]["to_index"], 3)


func test_diff_all_prepend() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["c", "d"]), _keys(["a", "b", "c", "d"]))
	# Both inserts at indices 0 and 1.
	var insert_ops: Array = ops.filter(func(o): return o["op"] == "insert")
	assert_eq(insert_ops.size(), 2)
	var keys_inserted: Array = insert_ops.map(func(o): return o["key"])
	assert_true("a" in keys_inserted)
	assert_true("b" in keys_inserted)


func test_diff_all_remove() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c"]), _keys([]))
	assert_eq(ops.size(), 3)
	for o in ops:
		assert_eq(o["op"], "remove")


func test_diff_middle_remove() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c", "d"]), _keys(["a", "c", "d"]))
	assert_eq(ops.size(), 1)
	assert_eq(ops[0]["op"], "remove")
	assert_eq(ops[0]["key"], "b")


# ─── Moves ────────────────────────────────────────────────

func test_diff_single_move() -> void:
	# [a,b,c] → [c,a,b]: c moves to 0. LIS keeps {a, b} in place.
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c"]), _keys(["c", "a", "b"]))
	var move_ops: Array = ops.filter(func(o): return o["op"] == "move")
	assert_eq(move_ops.size(), 1)
	assert_eq(move_ops[0]["key"], "c")
	assert_eq(move_ops[0]["to_index"], 0)


func test_diff_reverse() -> void:
	# [a,b,c,d] → [d,c,b,a]. LIS finds a singleton chain; 3 moves.
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c", "d"]), _keys(["d", "c", "b", "a"]))
	var move_ops: Array = ops.filter(func(o): return o["op"] == "move")
	# At minimum 3 of 4 items must move (one stays as LIS pivot).
	assert_gte(move_ops.size(), 3)
	assert_lte(move_ops.size(), 4)


# ─── Replace ──────────────────────────────────────────────

func test_diff_replace_one() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c"]), _keys(["a", "x", "c"]))
	assert_eq(ops.size(), 2)
	var ops_by_type: Dictionary = {}
	for o in ops:
		ops_by_type[o["op"]] = ops_by_type.get(o["op"], 0) + 1
	assert_eq(ops_by_type.get("remove", 0), 1)
	assert_eq(ops_by_type.get("insert", 0), 1)


# ─── Common prefix / suffix optimization ─────────────────

func test_diff_common_prefix_middle_change() -> void:
	# [a,b,c,d] → [a,b,x,d]: prefix [a,b] stays, c→x in middle, d as suffix
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c", "d"]), _keys(["a", "b", "x", "d"]))
	# Should be 1 remove + 1 insert; the prefix a,b and suffix d emit nothing.
	assert_eq(ops.size(), 2)


func test_diff_common_suffix() -> void:
	# [a,b,c,d] → [x,b,c,d]: suffix b,c,d stays; remove a + insert x
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b", "c", "d"]), _keys(["x", "b", "c", "d"]))
	assert_eq(ops.size(), 2)


# ─── Boundary ─────────────────────────────────────────────

func test_diff_empty_to_populated() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys([]), _keys(["a", "b"]))
	assert_eq(ops.size(), 2)
	for o in ops:
		assert_eq(o["op"], "insert")


func test_diff_populated_to_empty() -> void:
	var ops: Array = GmlVForReconciler.diff(_keys(["a", "b"]), _keys([]))
	assert_eq(ops.size(), 2)
	for o in ops:
		assert_eq(o["op"], "remove")


# ─── Duplicate keys ───────────────────────────────────────

func test_diff_duplicate_keys_in_new_returns_empty_and_warns() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var ops: Array = GmlVForReconciler.diff(_keys(["a"]), _keys(["a", "b", "b"]))
	assert_eq(ops.size(), 0, "duplicate keys must produce no ops")
	assert_gt(captured.size(), 0, "duplicate keys must warn")
	GmlBindingApplier._on_warning = Callable()


# ─── LIS optimality ──────────────────────────────────────

func test_diff_lis_keeps_increasing_subsequence_in_place() -> void:
	# [1,2,3,4,5] → [3,1,2,4,5]: keys {1,2,4,5} form an increasing subseq of
	# old positions if we keep them at their new positions. Key 3 moves.
	# Optimal: move 3 to position 0; others stay.
	var ops: Array = GmlVForReconciler.diff(_keys(["1", "2", "3", "4", "5"]), _keys(["3", "1", "2", "4", "5"]))
	var move_ops: Array = ops.filter(func(o): return o["op"] == "move")
	assert_eq(move_ops.size(), 1, "expected exactly one move; got %s" % str(ops))
	assert_eq(move_ops[0]["key"], "3")
