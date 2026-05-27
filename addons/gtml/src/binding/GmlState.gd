class_name GmlState
extends RefCounted

## Per-view reactive key→value store.
##
## Storage is flat with dotted keys ("player.health") rather than nested
## dicts so subscription lookup in the registry is O(1) on the exact key
## the view declared a binding against.
##
## Uses Godot's _set/_get virtuals so callers can write either:
##   state.set("score", 42)      # routes Object.set → _set virtual
##   state["score"] = 42         # subscript routes through _set
##   state.score = 42            # property syntax routes through _set
## Reads work the same three ways.
##
## Equality check prevents emitting state_changed for no-op writes.

signal state_changed(key: String, new_value: Variant, old_value: Variant)

var _values: Dictionary = {}


## Virtual: routes any unknown property assignment into _values.
## Returns true to tell Godot we handled it.
func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	# Don't intercept private internals
	if key.begins_with("_"):
		return false
	var has_old: bool = _values.has(key)
	var old_value = _values.get(key)
	if has_old and _values_equal(old_value, value):
		return true
	_values[key] = value
	state_changed.emit(key, value, old_value)
	return true


## Virtual: routes unknown property reads from _values.
func _get(property: StringName) -> Variant:
	var key: String = str(property)
	if key.begins_with("_"):
		return null
	if _values.has(key):
		return _values[key]
	return null


func has(key: String) -> bool:
	return _values.has(key)


## Set multiple keys; emits state_changed per CHANGED key (unchanged
## values are silently skipped, same as a single set() call).
func set_state(values: Dictionary) -> void:
	for k in values:
		self.set(k, values[k])


func keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k in _values.keys():
		out.append(str(k))
	return out


static func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b
