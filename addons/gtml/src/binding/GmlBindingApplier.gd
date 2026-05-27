class_name GmlBindingApplier
extends RefCounted

## Evaluates Expr ASTs against a state + scope, and writes resolved
## values into Controls via "register_*" helpers that build bindings and
## push them onto a GmlBindingRegistry.
##
## Task 4 covers: eval() for path/neg/string types,
## register_text_interpolation, register_attr_binding for the simple set
## (:disabled, :value, :src, :href).
##
## Object/array literals + call exprs (Task 5), v-if/v-show (Task 6),
## v-for (Task 7), v-model + @event(args) (Task 8) come later but share
## this same eval() core.


## Evaluate an expression AST against state + a loop-scope frame.
## Scope takes precedence over state for the same key — this is what
## makes {{ item.name }} read from the loop variable, not the global.
static func eval(expr: Dictionary, state: GmlState, scope: Dictionary) -> Variant:
	match expr.get("type", ""):
		"path":
			return _eval_path(expr["parts"], state, scope)
		"neg":
			var inner = eval(expr["inner"], state, scope)
			return not _truthy(inner)
		"string":
			return expr["value"]
		"object", "array", "call":
			# Implemented in Task 5/8
			return null
		_:
			return null


static func _eval_path(parts: PackedStringArray, state: GmlState, scope: Dictionary) -> Variant:
	if parts.is_empty():
		return null
	# 1) Scope: try the full dotted path joined as-is, then walk if the head matches
	var joined: String = ".".join(parts)
	if scope.has(joined):
		return scope[joined]
	if scope.has(parts[0]):
		var v = scope[parts[0]]
		for i in range(1, parts.size()):
			if v is Dictionary and v.has(parts[i]):
				v = v[parts[i]]
			else:
				return null
		return v
	# 2) State: try the full dotted key (canonical), then the partial-then-walk fallback
	if state.has(joined):
		return state.get(joined)
	if state.has(parts[0]):
		var v2 = state.get(parts[0])
		for i in range(1, parts.size()):
			if v2 is Dictionary and v2.has(parts[i]):
				v2 = v2[parts[i]]
			else:
				return null
		return v2
	return null


## "Truthy" follows GDScript's bool(): non-zero numbers, non-empty strings,
## non-null objects, true, non-empty containers.
static func _truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return not (v as String).is_empty()
	if v is Array:
		return not (v as Array).is_empty()
	if v is Dictionary:
		return not (v as Dictionary).is_empty()
	return true


# ─── Text interpolation registration ────────────────────────────

## Given a Label whose intended text is the result of joining literal +
## interpolated spans, register a binding so the label.text refreshes
## whenever any dep changes.
static func register_text_interpolation(label: Label, spans: Array, registry: GmlBindingRegistry, state: GmlState) -> void:
	var deps: Array = _collect_text_deps(spans)
	var ref: WeakRef = weakref(label)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		(ctl as Label).text = _render_spans(spans, state, {})
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	})
	apply.call()


static func _collect_text_deps(spans: Array) -> Array:
	var out: Array = []
	for span in spans:
		if span.get("type") == "interp":
			_collect_expr_deps(span["expr"], out)
	return out


static func _collect_expr_deps(expr: Dictionary, out: Array) -> void:
	match expr.get("type", ""):
		"path":
			var key: String = ".".join(expr["parts"])
			if not (key in out):
				out.append(key)
		"neg":
			_collect_expr_deps(expr["inner"], out)
		"object":
			for entry in expr.get("entries", []):
				_collect_expr_deps(entry["value"], out)
		"array":
			for item in expr.get("items", []):
				_collect_expr_deps(item, out)
		"call":
			for arg in expr.get("args", []):
				_collect_expr_deps(arg, out)
		# string / error → no deps


static func _render_spans(spans: Array, state: GmlState, scope: Dictionary) -> String:
	var out: String = ""
	for span in spans:
		match span.get("type"):
			"literal":
				out += span["value"]
			"interp":
				out += str(eval(span["expr"], state, scope))
	return out


# ─── Attribute binding registration ─────────────────────────────

## Wire a single :attr="expr" binding on the control. Initial apply runs
## synchronously; subsequent state changes re-apply via the registry.
static func register_attr_binding(control: Control, target: String, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState) -> void:
	var ref: WeakRef = weakref(control)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		_apply_attr(ctl, target, eval(expr, state, {}))
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	})
	apply.call()


## Write a resolved value into the appropriate property/method on the
## control for the given attribute target. Unknown targets are silently
## ignored (logged via push_warning so authors notice typos in :foo).
static func _apply_attr(control: Control, target: String, value: Variant) -> void:
	match target:
		"disabled":
			if "disabled" in control:
				control.disabled = bool(value)
		"value":
			if control is LineEdit:
				(control as LineEdit).text = str(value)
			elif control is TextEdit:
				(control as TextEdit).text = str(value)
		"src":
			if control is TextureRect and value is String:
				if ResourceLoader.exists(value):
					(control as TextureRect).texture = load(value) as Texture2D
		"href":
			control.set_meta("href", str(value))
		_:
			push_warning("GmlBindingApplier: unknown :attr target '%s'" % target)
