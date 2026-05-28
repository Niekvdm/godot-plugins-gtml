class_name GtmlCssEval
extends RefCounted

## Substitution + calc() evaluation for CSS values containing var() or calc().
##
## Operates on raw value strings; the result is a String that the property's
## normal type parser (GtmlCssParser.convert_value) then re-dispatches. This
## keeps the type system unchanged — tokens just thread an extra resolve step
## through it.


## Substitute every var(--name) or var(--name, fallback) in ``raw`` with
## either the scope's value or the fallback. Returns the substituted string.
## Unknown vars without fallback resolve to the empty string and emit a
## push_warning so authors notice. Cycle detection is built in — a var
## that references itself (directly or via a chain) breaks the chain on
## re-entry with a warning, matching CSS's "invalid → initial" semantics.
static func substitute_vars(raw: String, scope: Dictionary) -> String:
	return _substitute_vars_internal(raw, scope, {})


static func _substitute_vars_internal(raw: String, scope: Dictionary, visited: Dictionary) -> String:
	if raw.find("var(") < 0:
		return raw

	var out := ""
	var i := 0
	var n := raw.length()
	while i < n:
		if i + 4 <= n and raw.substr(i, 4) == "var(":
			var close := _find_paren_close(raw, i + 4)
			if close < 0:
				push_warning("GtmlCssEval: unterminated var() in '%s'" % raw)
				out += raw.substr(i)
				break
			var inner := raw.substr(i + 4, close - i - 4).strip_edges()
			out += _resolve_var(inner, scope, visited)
			i = close + 1
		else:
			out += raw[i]
			i += 1
	return out


static func _resolve_var(inner: String, scope: Dictionary, visited: Dictionary) -> String:
	# inner is "--name" or "--name, fallback"
	var comma := _top_level_comma(inner)
	var name: String
	var fallback: String = ""
	if comma < 0:
		name = inner.strip_edges()
	else:
		name = inner.substr(0, comma).strip_edges()
		fallback = inner.substr(comma + 1).strip_edges()

	if visited.has(name):
		push_warning("GtmlCssEval: CSS variable cycle detected at '%s'" % name)
		return ""

	if scope.has(name):
		var next_visited := visited.duplicate()
		next_visited[name] = true
		return _substitute_vars_internal(str(scope[name]), scope, next_visited)
	if not fallback.is_empty():
		return _substitute_vars_internal(fallback, scope, visited)
	push_warning("GtmlCssEval: unknown CSS variable '%s' (no fallback)" % name)
	return ""


## Evaluate every calc(...) in ``raw`` and replace it with the computed
## scalar (with unit if all operands share one). Operations supported:
## + - * /. No parentheses inside calc bodies — only the outer calc() itself.
## Unit rules:
##   - + and -: both sides must share the same unit (or both be unitless)
##   - * and /: at most one side may carry a unit
## Anything ambiguous is left as the raw substring so authors can spot it.
static func evaluate_calc(raw: String) -> String:
	if raw.find("calc(") < 0:
		return raw

	var out := ""
	var i := 0
	var n := raw.length()
	while i < n:
		if i + 5 <= n and raw.substr(i, 5) == "calc(":
			var close := _find_paren_close(raw, i + 5)
			if close < 0:
				push_warning("GtmlCssEval: unterminated calc() in '%s'" % raw)
				out += raw.substr(i)
				break
			var inner := raw.substr(i + 5, close - i - 5).strip_edges()
			out += _eval_expr(inner)
			i = close + 1
		else:
			out += raw[i]
			i += 1
	return out


## Resolve var() then evaluate calc(). Convenience for the resolver.
static func resolve(raw: String, scope: Dictionary) -> String:
	return evaluate_calc(substitute_vars(raw, scope))


# ─── Internals ────────────────────────────────────────────────────────


static func _find_paren_close(s: String, from: int) -> int:
	var depth := 1
	var i := from
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return i
		i += 1
	return -1


static func _top_level_comma(s: String) -> int:
	var depth := 0
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(0, depth - 1)
		elif ch == "," and depth == 0:
			return i
		i += 1
	return -1


## Tokenize then evaluate a flat arithmetic expression with + - * /.
## Returns the result formatted as "<number><unit>" or just "<number>".
static func _eval_expr(expr: String) -> String:
	var tokens := _tokenize(expr)
	if tokens.is_empty():
		return expr
	# Pass 1: combine * and /
	var pass1: Array = [tokens[0]]
	var i := 1
	while i < tokens.size():
		var op = tokens[i]
		var rhs = tokens[i + 1] if i + 1 < tokens.size() else null
		if rhs == null:
			break
		if op == "*" or op == "/":
			var lhs = pass1[pass1.size() - 1]
			pass1[pass1.size() - 1] = _combine(lhs, rhs, op)
		else:
			pass1.append(op)
			pass1.append(rhs)
		i += 2
	# Pass 2: combine + and - left-to-right
	var acc = pass1[0]
	var j := 1
	while j < pass1.size():
		var op = pass1[j]
		var rhs = pass1[j + 1] if j + 1 < pass1.size() else null
		if rhs == null:
			break
		acc = _combine(acc, rhs, op)
		j += 2
	return _format_operand(acc)


## A token is either a String operator or a Dictionary {value: float, unit: String}.
static func _tokenize(expr: String) -> Array:
	var out: Array = []
	var i := 0
	var n := expr.length()
	while i < n:
		var ch := expr[i]
		if ch == " " or ch == "\t" or ch == "\n":
			i += 1
			continue
		if ch == "+" or ch == "-" or ch == "*" or ch == "/":
			# Allow leading negative numbers when the previous token is an op (or none).
			var is_unary := (ch == "-" or ch == "+") and (out.is_empty() or out[out.size() - 1] is String)
			if is_unary:
				var start := i
				i += 1
				while i < n and (expr[i].is_valid_int() or expr[i] == "."):
					i += 1
				var num_str := expr.substr(start, i - start)
				var unit := ""
				while i < n and expr[i].is_valid_identifier():
					unit += expr[i]
					i += 1
				if i < n and expr[i] == "%":
					unit = "%"
					i += 1
				out.append({"value": num_str.to_float(), "unit": unit})
				continue
			out.append(ch)
			i += 1
			continue
		if ch.is_valid_int() or ch == ".":
			var start := i
			while i < n and (expr[i].is_valid_int() or expr[i] == "."):
				i += 1
			var num_str := expr.substr(start, i - start)
			var unit := ""
			while i < n and expr[i].is_valid_identifier():
				unit += expr[i]
				i += 1
			if i < n and expr[i] == "%":
				unit = "%"
				i += 1
			out.append({"value": num_str.to_float(), "unit": unit})
			continue
		# Unknown — bail by absorbing rest as a unit on the previous operand
		i += 1
	return out


static func _combine(a, b, op: String):
	if not (a is Dictionary) or not (b is Dictionary):
		return a  # malformed — punt
	var au: String = a.get("unit", "")
	var bu: String = b.get("unit", "")
	var av: float = a.get("value", 0.0)
	var bv: float = b.get("value", 0.0)
	var unit := ""
	var value := 0.0
	match op:
		"+":
			if au != bu and not (au.is_empty() or bu.is_empty()):
				push_warning("GtmlCssEval: cannot add %s and %s" % [au, bu])
				return a
			unit = au if not au.is_empty() else bu
			value = av + bv
		"-":
			if au != bu and not (au.is_empty() or bu.is_empty()):
				push_warning("GtmlCssEval: cannot subtract %s and %s" % [bu, au])
				return a
			unit = au if not au.is_empty() else bu
			value = av - bv
		"*":
			if not au.is_empty() and not bu.is_empty():
				push_warning("GtmlCssEval: cannot multiply two unit-bearing values (%s * %s)" % [au, bu])
				return a
			unit = au if not au.is_empty() else bu
			value = av * bv
		"/":
			if not bu.is_empty():
				push_warning("GtmlCssEval: cannot divide by a unit-bearing value (%s)" % bu)
				return a
			if bv == 0.0:
				push_warning("GtmlCssEval: division by zero in calc()")
				return a
			unit = au
			value = av / bv
		_:
			return a
	return {"value": value, "unit": unit}


static func _format_operand(op) -> String:
	if not (op is Dictionary):
		return str(op)
	var value: float = op.get("value", 0.0)
	var unit: String = op.get("unit", "")
	# Render integers without a decimal so downstream type parsers stay clean.
	if value == floor(value) and not is_inf(value):
		return "%d%s" % [int(value), unit]
	return "%s%s" % [str(value), unit]
