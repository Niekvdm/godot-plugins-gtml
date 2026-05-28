class_name GtmlBindingApplier
extends RefCounted

## Static logger injection point. Tests assign a Callable here to
## capture warnings; production leaves it unset and the helper falls
## back to push_warning.
static var _on_warning: Callable = Callable()


static func _warn(message: String) -> void:
	if _on_warning.is_valid():
		_on_warning.call(message)
	else:
		push_warning(message)


## Evaluates Expr ASTs against a state + scope, and writes resolved
## values into Controls via "register_*" helpers that build bindings and
## push them onto a GtmlBindingRegistry.
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
static func eval(expr: Dictionary, state: GtmlState, scope: Dictionary) -> Variant:
	match expr.get("type", ""):
		"path":
			return _eval_path(expr["parts"], state, scope)
		"neg":
			var inner = eval(expr["inner"], state, scope)
			return not _truthy(inner)
		"number":
			return expr["value"]
		"string":
			return expr["value"]
		"object":
			return _eval_object(expr["entries"], state, scope)
		"array":
			return _eval_array(expr["items"], state, scope)
		"call":
			# Resolve the call's args; the call name itself doesn't evaluate
			# (call invocation is the renderer's job for @event handlers).
			var resolved_args: Array = []
			for a in expr.get("args", []):
				resolved_args.append(eval(a, state, scope))
			return {"_call": true, "name": expr["name"], "args": resolved_args}
		"index":
			return _eval_index(expr["target"], expr["index"], state, scope)
		"unary":
			return _eval_unary(expr["op"], expr["inner"], state, scope)
		"binop":
			return _eval_binop(expr["op"], expr["left"], expr["right"], state, scope)
		"ternary":
			if _truthy(eval(expr["cond"], state, scope)):
				return eval(expr["then"], state, scope)
			return eval(expr["else_"], state, scope)
		_:
			return null


static func _eval_path(parts: PackedStringArray, state: GtmlState, scope: Dictionary) -> Variant:
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


## Object literal evaluation returns the KEYS whose evaluated VALUES are
## truthy. Used by :class for the { active: is_active } toggle syntax.
static func _eval_object(entries: Array, state: GtmlState, scope: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e in entries:
		if _truthy(eval(e["value"], state, scope)):
			out.append(e["key"])
	return out


## Array literal evaluation returns each element coerced to String.
## Path elements pull from state; string literals pass through.
static func _eval_array(items: Array, state: GtmlState, scope: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for item in items:
		var v = eval(item, state, scope)
		if v != null:
			out.append(str(v))
	return out


## Resolve target[index]. Array+int gives element-or-null;
## Dict+anything gives keyed lookup. OOB / missing key returns null
## without warning — v-for clones routinely read stale indices during
## reconciliation, warning each one would flood the log.
static func _eval_index(target: Dictionary, index: Dictionary, state: GtmlState, scope: Dictionary) -> Variant:
	var t = eval(target, state, scope)
	var i = eval(index, state, scope)
	if t == null:
		return null
	if t is Array:
		if not (i is int or i is float):
			return null
		var idx: int = int(i)
		if idx < 0 or idx >= (t as Array).size():
			return null
		return t[idx]
	if t is Dictionary:
		if (t as Dictionary).has(i):
			return t[i]
		return null
	return null


## Evaluate unary operators: ! (logical not) and - (numeric negation).
static func _eval_unary(op: String, inner_expr: Dictionary, state: GtmlState, scope: Dictionary) -> Variant:
	var v = eval(inner_expr, state, scope)
	match op:
		"!":
			return not _truthy(v)
		"-":
			if v is int or v is float:
				return -v
			_warn("unary '-' requires a number, got %s" % typeof(v))
			return null
		_:
			_warn("unknown unary op '%s'" % op)
			return null


## Evaluate binary operators. Strict GDScript-style: type mismatches
## return null + warn. == and != allow cross-type comparison (the
## "x == null" pattern) without warning — see spec §3.
static func _eval_binop(op: String, left: Dictionary, right: Dictionary, state: GtmlState, scope: Dictionary) -> Variant:
	# Short-circuit ops evaluate right lazily.
	if op == "&&":
		var lv = eval(left, state, scope)
		if not _truthy(lv):
			return lv
		return eval(right, state, scope)
	if op == "||":
		var lv2 = eval(left, state, scope)
		if _truthy(lv2):
			return lv2
		return eval(right, state, scope)

	var l = eval(left, state, scope)
	var r = eval(right, state, scope)

	match op:
		"+":
			if (l is int or l is float) and (r is int or r is float):
				return l + r
			if l is String and r is String:
				return (l as String) + (r as String)
			_warn("'+' type mismatch: %s + %s" % [typeof(l), typeof(r)])
			return null
		"-":
			if (l is int or l is float) and (r is int or r is float):
				return l - r
			_warn("'-' requires numbers")
			return null
		"*":
			if (l is int or l is float) and (r is int or r is float):
				return l * r
			_warn("'*' requires numbers")
			return null
		"/":
			if not ((l is int or l is float) and (r is int or r is float)):
				_warn("'/' requires numbers")
				return null
			if float(r) == 0.0:
				_warn("division by zero")
				return null
			# Always return a float so binding division doesn't silently
			# truncate when both operands happen to be GDScript ints (state
			# values are often ints, number literals are always floats).
			# Authors who want int truncation can use `%` or floor in GDScript.
			return float(l) / float(r)
		"%":
			if not ((l is int or l is float) and (r is int or r is float)):
				_warn("'%' requires numbers")
				return null
			if int(r) == 0:
				_warn("modulo by zero")
				return null
			return posmod(int(l), int(r))
		">":
			return _compare_ordered(l, r, ">")
		"<":
			return _compare_ordered(l, r, "<")
		">=":
			return _compare_ordered(l, r, ">=")
		"<=":
			return _compare_ordered(l, r, "<=")
		"==":
			return _values_equal(l, r)
		"!=":
			return not _values_equal(l, r)
		_:
			_warn("unknown binary op '%s'" % op)
			return null


static func _compare_ordered(l: Variant, r: Variant, op: String) -> Variant:
	var both_num: bool = (l is int or l is float) and (r is int or r is float)
	var both_str: bool = l is String and r is String
	if not (both_num or both_str):
		_warn("'%s' requires same-type comparable operands" % op)
		return null
	match op:
		">": return l > r
		"<": return l < r
		">=": return l >= r
		"<=": return l <= r
	return null


static func _values_equal(a: Variant, b: Variant) -> bool:
	# Mirrors GtmlState's equality semantics. Cross-type comparison is
	# permitted without warning — the common 'x == null' pattern.
	if typeof(a) != typeof(b):
		return a == b
	return a == b


# ─── Text interpolation registration ────────────────────────────

## Given a Label whose intended text is the result of joining literal +
## interpolated spans, register a binding so the label.text refreshes
## whenever any dep changes. Scope (from v-for) is captured at register
## time so loop variables resolve against the right element.
static func register_text_interpolation(label: Label, spans: Array, registry: GtmlBindingRegistry, state: GtmlState, scope: Dictionary = {}, tag: String = "") -> void:
	var deps: Array = _collect_text_deps(spans)
	var ref: WeakRef = weakref(label)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		(ctl as Label).text = _render_spans(spans, state, scope)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	}, tag)
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
		"binop":
			_collect_expr_deps(expr["left"], out)
			_collect_expr_deps(expr["right"], out)
		"unary":
			_collect_expr_deps(expr["inner"], out)
		"ternary":
			_collect_expr_deps(expr["cond"], out)
			_collect_expr_deps(expr["then"], out)
			_collect_expr_deps(expr["else_"], out)
		"index":
			_collect_expr_deps(expr["target"], out)
			_collect_expr_deps(expr["index"], out)
		# "number" → no deps (intentionally fall through to default)
		# string / error → no deps


static func _render_spans(spans: Array, state: GtmlState, scope: Dictionary) -> String:
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
static func register_attr_binding(control: Control, target: String, expr: Dictionary, registry: GtmlBindingRegistry, state: GtmlState, scope: Dictionary = {}, tag: String = "") -> void:
	var ref: WeakRef = weakref(control)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		_apply_attr(ctl, target, eval(expr, state, scope))
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	}, tag)
	apply.call()


## Wire :class="..." to a Control. The result is stored on the control's
## "dynamic_classes" meta as a PackedStringArray. The view's renderer (and
## any downstream code) can read this meta to know which dynamic classes
## are currently active on this element.
##
## Note: v0.7 does NOT re-resolve CSS rules when dynamic classes change.
## Dynamic class addition affects only the meta; the Control's existing
## stylebox is not updated. Static styling (declared on classes present
## at build time) still works. Document the limitation in docs/guide/bindings.md.
static func register_class_binding(control: Control, expr: Dictionary, registry: GtmlBindingRegistry, state: GtmlState, scope: Dictionary = {}, tag: String = "", on_change: Callable = Callable()) -> void:
	var ref: WeakRef = weakref(control)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		var resolved = eval(expr, state, scope)
		var classes: PackedStringArray = PackedStringArray()
		if resolved is PackedStringArray:
			classes = resolved
		elif resolved is Array:
			for x in resolved:
				classes.append(str(x))
		elif resolved is String:
			# bare string path: treat as space-separated class list
			for x in (resolved as String).split(" ", false):
				classes.append(x)
		ctl.set_meta("dynamic_classes", classes)
		if on_change.is_valid():
			on_change.call(classes)
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	}, tag)
	apply.call()


## Wire v-show. Initial visibility set from expr; subsequent state
## changes flip control.visible. Does NOT remove the control from the
## tree (that's v-if's job at the renderer level).
static func register_v_show(control: Control, expr: Dictionary, registry: GtmlBindingRegistry, state: GtmlState, scope: Dictionary = {}, tag: String = "") -> void:
	var ref: WeakRef = weakref(control)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		ctl.visible = _truthy(eval(expr, state, scope))
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	}, tag)
	apply.call()


## Static helper used by the renderer's v-if check at build time.
## Returns whether the v-if expression is currently truthy.
static func eval_v_if(expr_source: String, state: GtmlState, scope: Dictionary = {}) -> bool:
	var ast: Dictionary = GtmlBindingExpr.parse(expr_source)
	return _truthy(eval(ast, state, scope))


## Parse a v-for expression source into its components.
## Supports both forms:
##   "item in items"
##   "item, index in items"
## Returns {loop_var, index_var (may be ''), array_key} or null on parse failure.
static func parse_v_for(source: String) -> Variant:
	var parts := source.split(" in ", false, 1)
	if parts.size() != 2:
		return null
	var left := (parts[0] as String).strip_edges()
	var array_key := (parts[1] as String).strip_edges()
	if left.is_empty() or array_key.is_empty():
		return null
	var loop_var: String = left
	var index_var: String = ""
	if "," in left:
		var lparts := left.split(",", false)
		if lparts.size() == 2:
			loop_var = (lparts[0] as String).strip_edges()
			index_var = (lparts[1] as String).strip_edges()
	return {"loop_var": loop_var, "index_var": index_var, "array_key": array_key}


## Wire v-model two-way binding on an input control. The state-key is the
## v-model's source; the appropriate property on the control is bound.
## Supports LineEdit, TextEdit, CheckBox, HSlider, OptionButton.
##
## Reentry guard: state→control writes compare-then-write so the
## control's *_changed signal doesn't fire back into state.
static func register_v_model(control: Control, key: String, registry: GtmlBindingRegistry, state: GtmlState, _scope: Dictionary = {}, tag: String = "") -> void:
	var ref: WeakRef = weakref(control)
	var apply_state_to_control := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		var v = state.get(key)
		if ctl is LineEdit:
			var le := ctl as LineEdit
			if le.text != str(v):
				le.text = str(v)
		elif ctl is TextEdit:
			var te := ctl as TextEdit
			if te.text != str(v):
				te.text = str(v)
		elif ctl is CheckBox:
			var cb := ctl as CheckBox
			if cb.button_pressed != bool(v):
				cb.button_pressed = bool(v)
		elif ctl is HSlider:
			var sl := ctl as HSlider
			if sl.value != float(v):
				sl.value = float(v)
		elif ctl is OptionButton:
			var ob := ctl as OptionButton
			for i in ob.item_count:
				if ob.get_item_text(i) == str(v):
					if ob.selected != i:
						ob.select(i)
					break
	registry.register({
		"deps": [key],
		"apply": apply_state_to_control,
		"control_ref": ref,
	}, tag)
	apply_state_to_control.call()

	# Control → state (event-driven)
	if control is LineEdit:
		(control as LineEdit).text_changed.connect(func(t): state.set(key, t))
	elif control is TextEdit:
		(control as TextEdit).text_changed.connect(func(): state.set(key, (control as TextEdit).text))
	elif control is CheckBox:
		(control as CheckBox).toggled.connect(func(pressed): state.set(key, pressed))
	elif control is HSlider:
		(control as HSlider).value_changed.connect(func(v): state.set(key, v))
	elif control is OptionButton:
		(control as OptionButton).item_selected.connect(func(idx):
			state.set(key, (control as OptionButton).get_item_text(idx))
		)


## Wire @event with args. Captures the parsed call AST + current scope
## on the control and connects gui_input → view.item_clicked(handler, args).
## Re-evaluates args at click time so latest state is used.
static func register_event_with_args(control: Control, event: String, call_expr: Dictionary, state: GtmlState, scope: Dictionary, view, tag: String = "") -> void:
	if event != "click":
		_warn("GtmlBindingApplier: @event(args) currently supports only 'click', got '%s'" % event)
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.set_meta("v_on_click", true)
	var view_ref: WeakRef = weakref(view)
	control.gui_input.connect(func(event_obj: InputEvent):
		if not (event_obj is InputEventMouseButton):
			return
		var mb := event_obj as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var v = view_ref.get_ref()
		if v == null:
			return
		var resolved_args: Array = []
		for a in call_expr.get("args", []):
			resolved_args.append(eval(a, state, scope))
		v.item_clicked.emit(call_expr["name"], resolved_args)
	)


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
			_warn("GtmlBindingApplier: unknown :attr target '%s'" % target)
