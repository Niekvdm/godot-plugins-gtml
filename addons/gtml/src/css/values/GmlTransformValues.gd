class_name GmlTransformValues
extends RefCounted

## Parser for CSS ``transform`` values.
##
## Supported functions: translate(x[, y]) — px only, scale(s|sx, sy), rotate(deg).
## Multiple functions in one value compose left-to-right; later writes overwrite
## earlier ones for the same axis, matching the rule that the rightmost
## transform in a chain wins per CSS ordering.
##
## Returns a Dictionary with default keys so consumers don't have to check:
##   {translate: Vector2.ZERO, scale: Vector2.ONE, rotate: 0.0}


static func parse_transform(raw: String) -> Dictionary:
	var out: Dictionary = {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}
	var s := raw.strip_edges()

	# Walk function calls: name(args) name(args) ...
	var i := 0
	var n := s.length()
	while i < n:
		while i < n and (s[i] == " " or s[i] == "\t"):
			i += 1
		if i >= n:
			break
		var fn_start := i
		while i < n and s[i] != "(" and s[i] != " ":
			i += 1
		var fn_name: String = s.substr(fn_start, i - fn_start).to_lower()
		if i >= n or s[i] != "(":
			push_warning("GmlTransformValues: expected '(' after '%s' in '%s'" % [fn_name, raw])
			break
		var args_start := i + 1
		var close := s.find(")", args_start)
		if close < 0:
			push_warning("GmlTransformValues: unterminated function '%s(' in '%s'" % [fn_name, raw])
			break
		var args := s.substr(args_start, close - args_start)
		_apply_function(out, fn_name, args)
		i = close + 1
	return out


static func _apply_function(out: Dictionary, name: String, args_raw: String) -> void:
	var args := []
	for part in args_raw.split(",", false):
		args.append(part.strip_edges())
	match name:
		"translate":
			var x: float = _strip_unit_to_float(args[0]) if args.size() > 0 else 0.0
			var y: float = _strip_unit_to_float(args[1]) if args.size() > 1 else 0.0
			out["translate"] = Vector2(x, y)
		"translatex":
			out["translate"] = Vector2(_strip_unit_to_float(args[0]) if args.size() > 0 else 0.0, out["translate"].y)
		"translatey":
			out["translate"] = Vector2(out["translate"].x, _strip_unit_to_float(args[0]) if args.size() > 0 else 0.0)
		"scale":
			var sx: float = _strip_unit_to_float(args[0]) if args.size() > 0 else 1.0
			var sy: float = _strip_unit_to_float(args[1]) if args.size() > 1 else sx
			out["scale"] = Vector2(sx, sy)
		"scalex":
			out["scale"] = Vector2(_strip_unit_to_float(args[0]) if args.size() > 0 else 1.0, out["scale"].y)
		"scaley":
			out["scale"] = Vector2(out["scale"].x, _strip_unit_to_float(args[0]) if args.size() > 0 else 1.0)
		"rotate":
			# Accept "45deg", "0.5rad", or bare number (treat as degrees).
			var raw: String = args[0] if args.size() > 0 else "0"
			out["rotate"] = _parse_angle_to_radians(raw)
		_:
			push_warning("GmlTransformValues: unsupported transform function '%s'" % name)


## Parse a numeric argument, ignoring any trailing px / unit suffix.
static func _strip_unit_to_float(s: String) -> float:
	var trimmed := s.strip_edges()
	var i := 0
	var n := trimmed.length()
	# Allow a leading sign and digits + decimal point.
	while i < n:
		var ch := trimmed[i]
		if (i == 0 and (ch == "-" or ch == "+")) or ch.is_valid_int() or ch == ".":
			i += 1
		else:
			break
	return trimmed.substr(0, i).to_float()


static func _parse_angle_to_radians(s: String) -> float:
	var trimmed := s.strip_edges().to_lower()
	if trimmed.ends_with("rad"):
		return trimmed.substr(0, trimmed.length() - 3).strip_edges().to_float()
	if trimmed.ends_with("turn"):
		return trimmed.substr(0, trimmed.length() - 4).strip_edges().to_float() * TAU
	# Default + "deg" — degrees
	var num: String = trimmed
	if num.ends_with("deg"):
		num = num.substr(0, num.length() - 3).strip_edges()
	return deg_to_rad(num.to_float())
