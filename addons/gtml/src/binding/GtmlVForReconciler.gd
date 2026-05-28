class_name GtmlVForReconciler
extends RefCounted

## LIS-based v-for key diff. Pure-data — no Godot scene access.
##
## diff(old_keys, new_keys) returns an Array of Dictionary ops:
##   {op: "remove", key: String, from_index: int}
##   {op: "insert", key: String, to_index: int}
##   {op: "move",   key: String, from_index: int, to_index: int}
##
## Reuse-without-move is implicit (omitted). The caller iterates ops
## in the order returned and applies them to the rendered children:
## removes first (descending from_index so positions stay valid),
## then inserts + moves in ascending to_index order.
##
## Duplicate keys in new_keys → _warn + return [] (caller treats as
## "abort, no render change").


static func diff(old_keys: PackedStringArray, new_keys: PackedStringArray) -> Array:
	var old_n: int = old_keys.size()
	var new_n: int = new_keys.size()

	# Fast path: identical arrays.
	if old_n == new_n:
		var all_match: bool = true
		for i in old_n:
			if old_keys[i] != new_keys[i]:
				all_match = false
				break
		if all_match:
			return []

	# Pure remove path.
	if new_n == 0:
		var removes: Array = []
		# Emit removes in descending index order so the caller can
		# remove_child by from_index without recomputing positions.
		for i in range(old_n - 1, -1, -1):
			removes.append({"op": "remove", "key": old_keys[i], "from_index": i})
		return removes

	# Pure insert path.
	if old_n == 0:
		var inserts: Array = []
		for i in new_n:
			inserts.append({"op": "insert", "key": new_keys[i], "to_index": i})
		return inserts

	# Build new_key → new_index map and detect duplicates.
	var new_index_by_key: Dictionary = {}
	for i in new_n:
		var k: String = new_keys[i]
		if new_index_by_key.has(k):
			GtmlBindingApplier._warn("v-for duplicate key: %s" % k)
			return []
		new_index_by_key[k] = i

	# Common prefix.
	var prefix_end: int = 0
	while prefix_end < old_n and prefix_end < new_n and old_keys[prefix_end] == new_keys[prefix_end]:
		prefix_end += 1

	# Common suffix.
	var suffix_old: int = old_n - 1
	var suffix_new: int = new_n - 1
	while suffix_old >= prefix_end and suffix_new >= prefix_end and old_keys[suffix_old] == new_keys[suffix_new]:
		suffix_old -= 1
		suffix_new -= 1

	# Now the middle is old_keys[prefix_end..suffix_old] vs new_keys[prefix_end..suffix_new].
	var old_middle_start: int = prefix_end
	var old_middle_end: int = suffix_old   # inclusive
	var new_middle_start: int = prefix_end
	var new_middle_end: int = suffix_new   # inclusive

	# Build old_key → old_index map for the middle.
	var old_index_by_key: Dictionary = {}
	for i in range(old_middle_start, old_middle_end + 1):
		old_index_by_key[old_keys[i]] = i

	var ops_removes: Array = []
	var ops_moves_inserts: Array = []

	# Mark old middle keys not present in new → remove.
	# Build old_index_for_new[new_pos] = old_index OR -1 (insert).
	var new_middle_len: int = new_middle_end - new_middle_start + 1
	var old_index_for_new: PackedInt32Array = PackedInt32Array()
	for _i in new_middle_len:
		old_index_for_new.append(-1)

	for new_pos in range(new_middle_start, new_middle_end + 1):
		var k: String = new_keys[new_pos]
		if old_index_by_key.has(k):
			old_index_for_new[new_pos - new_middle_start] = old_index_by_key[k]

	# Walk old middle keys; if not present in new_index_by_key, remove.
	var keep_old: Dictionary = {}
	for new_pos in range(new_middle_start, new_middle_end + 1):
		var oi: int = old_index_for_new[new_pos - new_middle_start]
		if oi >= 0:
			keep_old[oi] = true
	# Emit removes for old middle keys not retained, in descending order.
	for old_pos in range(old_middle_end, old_middle_start - 1, -1):
		if not keep_old.has(old_pos):
			ops_removes.append({"op": "remove", "key": old_keys[old_pos], "from_index": old_pos})

	# LIS over old_index_for_new (treating -1 entries as breaks).
	# Compute set of new_middle positions that are in the LIS — they stay
	# without a move op.
	var in_lis: Dictionary = _lis_positions(old_index_for_new)

	# Walk new middle and emit insert/move ops in ascending to_index.
	for new_pos in range(new_middle_start, new_middle_end + 1):
		var rel: int = new_pos - new_middle_start
		var oi: int = old_index_for_new[rel]
		if oi < 0:
			ops_moves_inserts.append({"op": "insert", "key": new_keys[new_pos], "to_index": new_pos})
		elif not in_lis.has(rel):
			ops_moves_inserts.append({"op": "move", "key": new_keys[new_pos], "from_index": oi, "to_index": new_pos})

	# Combine: removes first (already in descending from_index order),
	# then moves+inserts in ascending to_index order (already in that
	# order by construction).
	var out: Array = []
	for r in ops_removes:
		out.append(r)
	for mi in ops_moves_inserts:
		out.append(mi)
	return out


## Return Dictionary whose keys are positions (in the input array's index
## space) that belong to the longest increasing subsequence of non-negative
## values. Negative values are treated as breaks (excluded from LIS).
static func _lis_positions(arr: PackedInt32Array) -> Dictionary:
	var n: int = arr.size()
	# parent[i] = predecessor position in LIS chain for element at position i
	var parent: PackedInt32Array = PackedInt32Array()
	# tails[k] = position of the smallest possible tail value for an LIS of length k+1
	var tails: PackedInt32Array = PackedInt32Array()
	for _i in n:
		parent.append(-1)

	for i in n:
		var v: int = arr[i]
		if v < 0:
			continue
		# Binary-search tails for the leftmost slot where arr[tails[k]] >= v.
		var lo: int = 0
		var hi: int = tails.size()
		while lo < hi:
			var mid: int = (lo + hi) / 2
			if arr[tails[mid]] < v:
				lo = mid + 1
			else:
				hi = mid
		if lo == tails.size():
			tails.append(i)
		else:
			tails[lo] = i
		if lo > 0:
			parent[i] = tails[lo - 1]

	var out: Dictionary = {}
	if tails.is_empty():
		return out
	var cur: int = tails[tails.size() - 1]
	while cur >= 0:
		out[cur] = true
		cur = parent[cur]
	return out
