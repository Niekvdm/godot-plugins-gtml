class_name GmlBindingRegistry
extends RefCounted

## Per-view {key → Array[binding]} reverse index for reactive bindings.
##
## A binding is a Dictionary:
##   {
##     deps: Array[String]   # state keys this binding reads
##     apply: Callable       # invoked when any dep changes; takes no args
##     control_ref: WeakRef  # null OR weakref to the Control; pruned when dead
##   }
##
## Each binding registers once; the registry mirrors it into the reverse
## index for every dep. On fire(key), all bindings touching that key are
## invoked once. Bindings whose control_ref has been freed are pruned
## lazily in the same pass.

var _by_key: Dictionary = {}   # key → Array[binding]
var _all: Array = []           # bookkeeping for clear() and binding_count()


func register(binding: Dictionary) -> void:
	_all.append(binding)
	var deps: Array = binding.get("deps", [])
	for dep in deps:
		if not _by_key.has(dep):
			_by_key[dep] = []
		_by_key[dep].append(binding)


func fire(key: String) -> void:
	if not _by_key.has(key):
		return
	var bindings: Array = _by_key[key]
	var still_valid: Array = []
	for b in bindings:
		if _is_alive(b):
			b["apply"].call()
			still_valid.append(b)
	_by_key[key] = still_valid
	if still_valid.size() != bindings.size():
		_all = _all.filter(_is_alive)


## Fire many keys at once; each binding affected fires AT MOST ONCE even
## when it depends on multiple of the keys.
func fire_batch(keys_to_fire: Array) -> void:
	var seen: Dictionary = {}
	for k in keys_to_fire:
		if not _by_key.has(k):
			continue
		for b in _by_key[k]:
			# Use the apply Callable itself as a dedup key (Callables are hashable).
			var dedup_key = b["apply"]
			if seen.has(dedup_key):
				continue
			seen[dedup_key] = true
			if _is_alive(b):
				b["apply"].call()
	# Prune across all keys at the end
	for k in _by_key.keys():
		_by_key[k] = (_by_key[k] as Array).filter(_is_alive)
	_all = _all.filter(_is_alive)


func clear() -> void:
	_by_key.clear()
	_all.clear()


func binding_count() -> int:
	return _all.size()


static func _is_alive(binding: Dictionary) -> bool:
	var ref = binding.get("control_ref")
	if ref == null:
		return true
	if not (ref is WeakRef):
		return true
	return ref.get_ref() != null
