class_name GmlBindingExpr
extends RefCounted

## Mini-expression parser for binding directives.
##
## Grammar:
##   Expr     := Path | NegPath | ObjectLit | ArrayLit | CallExpr | StringLit
##   Path     := Ident ('.' Ident)*
##   NegPath  := '!' Path
##   ObjectLit:= '{' (Ident ':' Expr (',' Ident ':' Expr)*)? '}'
##   ArrayLit := '[' (Expr (',' Expr)*)? ']'
##   CallExpr := Ident '(' (Expr (',' Expr)*)? ')'
##   StringLit:= "'…'" | '"…"'
##   Ident    := [a-zA-Z_][\w-]*
##
## No arithmetic, comparison, string concat, or ternary. Authors who need
## computed values do them in GDScript and state.set() them in.
##
## Return shape:
##   {type: "path",   parts: PackedStringArray}
##   {type: "neg",    inner: Dictionary}
##   {type: "object", entries: [{key: String, value: Dictionary}, ...]}
##   {type: "array",  items: [Dictionary, ...]}
##   {type: "call",   name: String, args: [Dictionary, ...]}
##   {type: "string", value: String}
##   {type: "error",  message: String}


static func parse(source: String) -> Dictionary:
	var parser := _Parser.new(source)
	var expr: Dictionary = parser.parse_expr()
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

	func parse_expr() -> Dictionary:
		_skip_ws()
		if _pos >= _source.length():
			_errors.append("empty expression")
			return {}
		var ch: String = _source[_pos]

		if ch == "'" or ch == "\"":
			return _parse_string()
		if ch == "{":
			return _parse_object()
		if ch == "[":
			return _parse_array()
		if ch == "!":
			_pos += 1
			_skip_ws()
			var inner: Dictionary = _parse_path()
			return {"type": "neg", "inner": inner}
		# Ident → Path | CallExpr (peek for '(')
		var ident: String = _parse_ident()
		if ident.is_empty():
			_errors.append("expected identifier at pos %d" % _pos)
			return {}
		_skip_ws()
		if _pos < _source.length() and _source[_pos] == "(":
			return _parse_call_after_ident(ident)
		return _parse_path_after_ident(ident)

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
		_pos += 1   # closing quote
		return {"type": "string", "value": value}

	func _parse_object() -> Dictionary:
		_pos += 1   # opening {
		var entries: Array = []
		_skip_ws()
		if _pos < _source.length() and _source[_pos] == "}":
			_pos += 1
			return {"type": "object", "entries": entries}
		while _pos < _source.length():
			_skip_ws()
			var key: String = _parse_ident()
			if key.is_empty():
				_errors.append("expected key at pos %d" % _pos)
				return {}
			_skip_ws()
			if _pos >= _source.length() or _source[_pos] != ":":
				_errors.append("expected ':' after key at pos %d" % _pos)
				return {}
			_pos += 1
			var value: Dictionary = parse_expr()
			entries.append({"key": key, "value": value})
			_skip_ws()
			if _pos < _source.length() and _source[_pos] == ",":
				_pos += 1
				continue
			if _pos < _source.length() and _source[_pos] == "}":
				_pos += 1
				return {"type": "object", "entries": entries}
			_errors.append("expected ',' or '}' at pos %d" % _pos)
			return {}
		_errors.append("unterminated object")
		return {}

	func _parse_array() -> Dictionary:
		_pos += 1   # opening [
		var items: Array = []
		_skip_ws()
		if _pos < _source.length() and _source[_pos] == "]":
			_pos += 1
			return {"type": "array", "items": items}
		while _pos < _source.length():
			var item: Dictionary = parse_expr()
			items.append(item)
			_skip_ws()
			if _pos < _source.length() and _source[_pos] == ",":
				_pos += 1
				continue
			if _pos < _source.length() and _source[_pos] == "]":
				_pos += 1
				return {"type": "array", "items": items}
			_errors.append("expected ',' or ']' at pos %d" % _pos)
			return {}
		_errors.append("unterminated array")
		return {}

	func _parse_path() -> Dictionary:
		var ident: String = _parse_ident()
		if ident.is_empty():
			_errors.append("expected identifier at pos %d" % _pos)
			return {}
		return _parse_path_after_ident(ident)

	func _parse_path_after_ident(first: String) -> Dictionary:
		var parts: PackedStringArray = PackedStringArray([first])
		while _pos < _source.length() and _source[_pos] == ".":
			_pos += 1
			var next: String = _parse_ident()
			if next.is_empty():
				_errors.append("expected identifier after '.' at pos %d" % _pos)
				return {}
			parts.append(next)
		return {"type": "path", "parts": parts}

	func _parse_call_after_ident(name: String) -> Dictionary:
		_pos += 1   # opening (
		var args: Array = []
		_skip_ws()
		if _pos < _source.length() and _source[_pos] == ")":
			_pos += 1
			return {"type": "call", "name": name, "args": args}
		while _pos < _source.length():
			var arg: Dictionary = parse_expr()
			args.append(arg)
			_skip_ws()
			if _pos < _source.length() and _source[_pos] == ",":
				_pos += 1
				continue
			if _pos < _source.length() and _source[_pos] == ")":
				_pos += 1
				return {"type": "call", "name": name, "args": args}
			_errors.append("expected ',' or ')' in call at pos %d" % _pos)
			return {}
		_errors.append("unterminated call")
		return {}

	func _parse_ident() -> String:
		var start: int = _pos
		while _pos < _source.length():
			var ch: String = _source[_pos]
			if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch.is_valid_int():
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
