class_name GmlBindingExpr
extends RefCounted

## Mini-expression parser for binding directives. v0.8 — layered
## recursive descent with the precedence cascade:
##   Ternary > LogicalOr > LogicalAnd > Equality > Comparison
##   > Additive > Multiplicative > Unary > Postfix > Primary
##
## See docs/superpowers/specs/2026-05-27-expression-operators-design.md
##
## v0.7 AST shapes (path, neg, call, object, array, string) are preserved
## for inputs that match v0.7 grammar exactly. New AST nodes: number,
## binop, unary, ternary, index.


static func parse(source: String) -> Dictionary:
	var parser := _Parser.new(source)
	var expr: Dictionary = parser._parse_ternary()
	if not parser._errors.is_empty():
		return {"type": "error", "message": parser._errors[0]}
	parser._skip_ws()
	if parser._pos < parser._source.length():
		return {"type": "error", "message": "trailing characters at pos %d" % parser._pos}
	return expr


class _Parser:
	var _source: String
	var _pos: int = 0
	var _errors: Array = []

	func _init(source: String) -> void:
		_source = source

	# ─── Precedence cascade ───────────────────────────────────

	func _parse_ternary() -> Dictionary:
		var cond: Dictionary = _parse_logical_or()
		_skip_ws()
		if _peek() == "?":
			_pos += 1
			var then_branch: Dictionary = _parse_ternary()
			_skip_ws()
			if _peek() != ":":
				_errors.append("expected ':' in ternary at pos %d" % _pos)
				return {}
			_pos += 1
			var else_branch: Dictionary = _parse_ternary()
			return {"type": "ternary", "cond": cond, "then": then_branch, "else_": else_branch}
		return cond

	func _parse_logical_or() -> Dictionary:
		# Task 8 fills this in; for now passthrough.
		return _parse_logical_and()

	func _parse_logical_and() -> Dictionary:
		# Task 8 fills this in; for now passthrough.
		return _parse_equality()

	func _parse_equality() -> Dictionary:
		# Task 7 fills this in; for now passthrough.
		return _parse_comparison()

	func _parse_comparison() -> Dictionary:
		# Task 6 fills this in; for now passthrough.
		return _parse_additive()

	func _parse_additive() -> Dictionary:
		var left: Dictionary = _parse_multiplicative()
		while true:
			_skip_ws()
			var op: String = _peek()
			if op != "+" and op != "-":
				break
			_pos += 1
			var right: Dictionary = _parse_multiplicative()
			left = {"type": "binop", "op": op, "left": left, "right": right}
		return left

	func _parse_multiplicative() -> Dictionary:
		var left: Dictionary = _parse_unary()
		while true:
			_skip_ws()
			var op: String = _peek()
			if op != "*" and op != "/" and op != "%":
				break
			_pos += 1
			var right: Dictionary = _parse_unary()
			left = {"type": "binop", "op": op, "left": left, "right": right}
		return left

	func _parse_unary() -> Dictionary:
		_skip_ws()
		var ch: String = _peek()
		if ch == "!":
			_pos += 1
			_skip_ws()
			var inner: Dictionary = _parse_unary()
			# Back-compat: emit "neg" when inner is exactly a path (v0.7 test fixtures).
			if inner.get("type", "") == "path":
				return {"type": "neg", "inner": inner}
			return {"type": "unary", "op": "!", "inner": inner}
		if ch == "-":
			_pos += 1
			_skip_ws()
			var inner_m: Dictionary = _parse_unary()
			return {"type": "unary", "op": "-", "inner": inner_m}
		return _parse_postfix()

	func _parse_postfix() -> Dictionary:
		var expr: Dictionary = _parse_primary()
		# Path/index/call postfixes layered here:
		while true:
			_skip_ws()
			var ch: String = _peek()
			if ch == ".":
				_pos += 1
				var ident: String = _parse_ident()
				if ident.is_empty():
					_errors.append("expected identifier after '.' at pos %d" % _pos)
					return {}
				# Fold contiguous .ident chains into a single path node so
				# v0.7 fixtures see {type:"path", parts:[a,b,c]} not nested
				# {index:..} for dotted reads.
				if expr.get("type", "") == "path":
					expr["parts"].append(ident)
				else:
					# Wrap non-path target in an index-with-string-key shape.
					expr = {"type": "index", "target": expr, "index": {"type": "string", "value": ident}}
			elif ch == "(":
				# Call form — only valid when expr is exactly a top-level Ident path.
				if expr.get("type", "") == "path" and expr["parts"].size() == 1:
					var name_str: String = expr["parts"][0]
					expr = _parse_call_args(name_str)
				else:
					_errors.append("'(' after non-identifier at pos %d" % _pos)
					return {}
			elif ch == "[":
				_pos += 1
				var index_expr: Dictionary = _parse_ternary()
				_skip_ws()
				if _peek() != "]":
					_errors.append("expected ']' at pos %d" % _pos)
					return {}
				_pos += 1
				expr = {"type": "index", "target": expr, "index": index_expr}
			else:
				break
		return expr

	func _parse_call_args(name_str: String) -> Dictionary:
		_pos += 1   # opening (
		var args: Array = []
		_skip_ws()
		if _peek() == ")":
			_pos += 1
			return {"type": "call", "name": name_str, "args": args}
		while _pos < _source.length():
			args.append(_parse_ternary())
			_skip_ws()
			if _peek() == ",":
				_pos += 1
				continue
			if _peek() == ")":
				_pos += 1
				return {"type": "call", "name": name_str, "args": args}
			_errors.append("expected ',' or ')' in call at pos %d" % _pos)
			return {}
		_errors.append("unterminated call")
		return {}

	func _parse_primary() -> Dictionary:
		_skip_ws()
		if _pos >= _source.length():
			_errors.append("empty expression")
			return {}
		var ch: String = _source[_pos]

		if ch == "(":
			_pos += 1
			var inner: Dictionary = _parse_ternary()
			_skip_ws()
			if _peek() != ")":
				_errors.append("expected ')' at pos %d" % _pos)
				return {}
			_pos += 1
			return inner
		if ch == "'" or ch == "\"":
			return _parse_string()
		if ch == "{":
			return _parse_object()
		if ch == "[":
			return _parse_array()
		if ch.is_valid_int() or ch == ".":
			return _parse_number()
		# Identifier → path[1]
		var ident: String = _parse_ident()
		if ident.is_empty():
			_errors.append("expected identifier at pos %d" % _pos)
			return {}
		return {"type": "path", "parts": PackedStringArray([ident])}

	# ─── Literals ─────────────────────────────────────────────

	func _parse_number() -> Dictionary:
		var start: int = _pos
		while _pos < _source.length() and _source[_pos].is_valid_int():
			_pos += 1
		if _pos < _source.length() and _source[_pos] == ".":
			_pos += 1
			while _pos < _source.length() and _source[_pos].is_valid_int():
				_pos += 1
		var text: String = _source.substr(start, _pos - start)
		# Reject bare '.' and other digit-less inputs that slipped through
		# the _parse_primary dispatch (which routes both '0'-'9' and '.' here).
		if text == "" or text == ".":
			_errors.append("expected digits in number at pos %d" % start)
			return {}
		return {"type": "number", "value": text.to_float()}

	func _parse_string() -> Dictionary:
		var quote: String = _source[_pos]
		_pos += 1
		var start: int = _pos
		while _pos < _source.length() and _source[_pos] != quote:
			_pos += 1
		if _pos >= _source.length():
			_errors.append("unterminated string starting at pos %d" % (start - 1))
			return {}
		var value: String = _source.substr(start, _pos - start)
		_pos += 1
		return {"type": "string", "value": value}

	func _parse_object() -> Dictionary:
		_pos += 1
		var entries: Array = []
		_skip_ws()
		if _peek() == "}":
			_pos += 1
			return {"type": "object", "entries": entries}
		while _pos < _source.length():
			_skip_ws()
			var key: String = _parse_ident()
			if key.is_empty():
				_errors.append("expected key at pos %d" % _pos)
				return {}
			_skip_ws()
			if _peek() != ":":
				_errors.append("expected ':' after key at pos %d" % _pos)
				return {}
			_pos += 1
			entries.append({"key": key, "value": _parse_ternary()})
			_skip_ws()
			if _peek() == ",":
				_pos += 1
				continue
			if _peek() == "}":
				_pos += 1
				return {"type": "object", "entries": entries}
			_errors.append("expected ',' or '}' at pos %d" % _pos)
			return {}
		_errors.append("unterminated object")
		return {}

	func _parse_array() -> Dictionary:
		_pos += 1
		var items: Array = []
		_skip_ws()
		if _peek() == "]":
			_pos += 1
			return {"type": "array", "items": items}
		while _pos < _source.length():
			items.append(_parse_ternary())
			_skip_ws()
			if _peek() == ",":
				_pos += 1
				continue
			if _peek() == "]":
				_pos += 1
				return {"type": "array", "items": items}
			_errors.append("expected ',' or ']' at pos %d" % _pos)
			return {}
		_errors.append("unterminated array")
		return {}

	# ─── Lexer helpers ────────────────────────────────────────

	func _parse_ident() -> String:
		# v0.8: NO hyphens. Identifiers are [a-zA-Z_][a-zA-Z0-9_]*.
		var start: int = _pos
		if _pos >= _source.length():
			return ""
		var ch: String = _source[_pos]
		if not (ch.is_valid_identifier() and not ch.is_valid_int()):
			return ""
		_pos += 1
		while _pos < _source.length():
			var c: String = _source[_pos]
			if c.is_valid_identifier() or c.is_valid_int() or c == "_":
				_pos += 1
			else:
				break
		return _source.substr(start, _pos - start)

	func _skip_ws() -> void:
		while _pos < _source.length():
			var ch: String = _source[_pos]
			if ch == " " or ch == "\t" or ch == "\n":
				_pos += 1
			else:
				break

	func _peek() -> String:
		if _pos >= _source.length():
			return ""
		return _source[_pos]
