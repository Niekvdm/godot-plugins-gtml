class_name GtmlSearchEngine
extends RefCounted

## Find / replace ops on a buffer. Stateless; pure ops on strings.
## Matches are {line: int, col: int, length: int}.

static func find_all(text: String, query: String, case_sensitive: bool, use_regex: bool) -> Array:
	if query.is_empty() or text.is_empty():
		return []
	if use_regex:
		return _find_regex(text, query, case_sensitive)
	return _find_literal(text, query, case_sensitive)


static func replace_all(text: String, query: String, replacement: String, case_sensitive: bool, use_regex: bool) -> Dictionary:
	if query.is_empty():
		return {"new_text": text, "count": 0}
	if use_regex:
		return _replace_regex(text, query, replacement, case_sensitive)
	return _replace_literal(text, query, replacement, case_sensitive)


static func replace_one(text: String, match_info: Dictionary, replacement: String) -> String:
	var line: int = match_info["line"]
	var col: int = match_info["col"]
	var length: int = match_info["length"]
	var off := 0
	for i in line:
		off = text.find("\n", off) + 1
		if off <= 0:
			return text   # malformed line index
	off += col
	return text.substr(0, off) + replacement + text.substr(off + length)


# ─── Literal ──────────────────────────────────────────────────────

static func _find_literal(text: String, query: String, case_sensitive: bool) -> Array:
	var hay := text if case_sensitive else text.to_lower()
	var needle := query if case_sensitive else query.to_lower()
	var matches: Array = []
	var pos := 0
	while pos < hay.length():
		var idx := hay.find(needle, pos)
		if idx < 0:
			break
		var lc := _line_col_for(text, idx)
		matches.append({"line": lc["line"], "col": lc["col"], "length": query.length()})
		pos = idx + query.length()
	return matches


static func _replace_literal(text: String, query: String, replacement: String, case_sensitive: bool) -> Dictionary:
	if case_sensitive:
		var count := text.count(query)
		return {"new_text": text.replace(query, replacement), "count": count}
	# Case-insensitive: Godot builtins do the work.
	var ci_count := text.countn(query)
	return {"new_text": text.replacen(query, replacement), "count": ci_count}


# ─── Regex ────────────────────────────────────────────────────────

static func _compile_regex(pattern: String, case_sensitive: bool) -> RegEx:
	var re := RegEx.new()
	# Godot RegEx is case-sensitive by default. For insensitive, prefix with (?i).
	var effective := pattern if case_sensitive else "(?i)" + pattern
	if re.compile(effective) != OK:
		return null
	return re


static func _find_regex(text: String, query: String, case_sensitive: bool) -> Array:
	var re := _compile_regex(query, case_sensitive)
	if re == null:
		return []
	var matches: Array = []
	for m in re.search_all(text):
		var start := m.get_start()
		var lc := _line_col_for(text, start)
		matches.append({"line": lc["line"], "col": lc["col"], "length": m.get_end() - start})
	return matches


static func _replace_regex(text: String, query: String, replacement: String, case_sensitive: bool) -> Dictionary:
	var re := _compile_regex(query, case_sensitive)
	if re == null:
		return {"new_text": text, "count": 0}
	# Two passes: search_all to count matches, sub to build the result.
	# RegEx.sub returns the new string but no count; the doubled scan is
	# the simplest correct way to provide both.
	var count := re.search_all(text).size()
	var new_text := re.sub(text, replacement, true)
	return {"new_text": new_text, "count": count}


# ─── Position math ────────────────────────────────────────────────

static func _line_col_for(text: String, idx: int) -> Dictionary:
	var line := 0
	var col := 0
	var limit := mini(idx, text.length())
	for i in range(limit):
		if text[i] == "\n":
			line += 1
			col = 0
		else:
			col += 1
	return {"line": line, "col": col}
