class_name GmlSelector
extends RefCounted

## Selector parser + matcher for the v0.2 GTML CSS engine.
##
## A selector is a chain of *compound selectors* joined by *combinators*.
## A compound selector is a set of simple-selector pieces that must all match
## the same element (e.g. ``div.foo#bar`` is one compound made of tag,
## class, and id pieces).
##
## Supported combinators: descendant (` `) and child (`>`). Sibling combinators
## are deferred to v0.3.
##
## Supported attribute selectors: ``[attr]`` and ``[attr=value]`` (with quoted
## or unquoted values). Substring matchers (``~=``, ``^=``, ``$=``, ``*=``)
## are deferred to v0.3.
##
## Specificity is the standard CSS tuple ``(id_count, class+attr+pseudo_count,
## tag_count)`` — exposed via ``Selector.specificity()`` so the resolver can
## sort declarations.


class Compound:
	## A single compound selector (one element's constraints).
	var tag: String = ""        # empty = universal/no tag constraint
	var id: String = ""
	var classes: PackedStringArray = PackedStringArray()
	var attrs: Array = []       # Array of {name, op, value}
	var pseudos: PackedStringArray = PackedStringArray()


class Selector:
	## A full selector chain (compound[0] combinator[0] compound[1] ...).
	var compounds: Array = []        # Array[Compound]
	var combinators: Array = []      # combinators[i] sits between compounds[i] and compounds[i+1]
	var source_index: int = 0        # position in source for tie-breaking

	func specificity() -> Vector3i:
		var ids := 0
		var cls := 0
		var tags := 0
		for c in compounds:
			if not c.id.is_empty():
				ids += 1
			cls += c.classes.size()
			cls += c.attrs.size()
			cls += c.pseudos.size()
			if not c.tag.is_empty():
				tags += 1
		return Vector3i(ids, cls, tags)


## Parse a single selector string (no commas) into a Selector.
static func parse(s: String) -> Selector:
	var sel := Selector.new()
	var i := 0
	var n := s.length()
	var current := Compound.new()
	var pending_combinator := ""

	while i < n:
		var ch := s[i]

		# Whitespace -> descendant combinator (unless adjacent to >)
		if ch == " " or ch == "\t" or ch == "\n":
			i += 1
			# look ahead for explicit combinator
			while i < n and (s[i] == " " or s[i] == "\t" or s[i] == "\n"):
				i += 1
			if i >= n:
				break
			if s[i] == ">":
				# child combinator
				_finalize_compound(sel, current, pending_combinator)
				current = Compound.new()
				pending_combinator = ">"
				i += 1
				# skip trailing whitespace
				while i < n and (s[i] == " " or s[i] == "\t" or s[i] == "\n"):
					i += 1
				continue
			# pure descendant
			_finalize_compound(sel, current, pending_combinator)
			current = Compound.new()
			pending_combinator = " "
			continue

		if ch == ">":
			_finalize_compound(sel, current, pending_combinator)
			current = Compound.new()
			pending_combinator = ">"
			i += 1
			continue

		if ch == "#":
			i += 1
			var id_end := _read_ident_end(s, i)
			current.id = s.substr(i, id_end - i)
			i = id_end
			continue

		if ch == ".":
			i += 1
			var cls_end := _read_ident_end(s, i)
			current.classes.append(s.substr(i, cls_end - i))
			i = cls_end
			continue

		if ch == ":":
			i += 1
			var p_end := _read_ident_end(s, i)
			current.pseudos.append(s.substr(i, p_end - i))
			i = p_end
			continue

		if ch == "[":
			# Find the matching ] while ignoring closing brackets inside quoted
			# attribute values, e.g. [data-x="a]b"].
			var close := _find_attr_close(s, i + 1)
			if close < 0:
				push_warning("GmlSelector: unterminated attribute selector in '%s'" % s)
				break
			var inner := s.substr(i + 1, close - i - 1)
			current.attrs.append(_parse_attr(inner))
			i = close + 1
			continue

		if ch == "*":
			# universal — leaves tag empty
			i += 1
			continue

		# identifier (tag name)
		if _is_ident_char(ch):
			var end := _read_ident_end(s, i)
			current.tag = s.substr(i, end - i).to_lower()
			i = end
			continue

		# unknown char — skip to avoid infinite loop
		i += 1

	_finalize_compound(sel, current, pending_combinator)
	return sel


static func _finalize_compound(sel: Selector, c: Compound, pending_combinator: String) -> void:
	# Skip empty compounds that show up when a combinator appears with no preceding/following content
	if c.tag.is_empty() and c.id.is_empty() and c.classes.is_empty() \
			and c.attrs.is_empty() and c.pseudos.is_empty():
		return
	if not sel.compounds.is_empty() and not pending_combinator.is_empty():
		sel.combinators.append(pending_combinator)
	sel.compounds.append(c)


static func _parse_attr(inner: String) -> Dictionary:
	var eq := inner.find("=")
	if eq < 0:
		return {"name": inner.strip_edges(), "op": "", "value": ""}
	var name := inner.substr(0, eq).strip_edges()
	var value := inner.substr(eq + 1).strip_edges()
	# Strip surrounding quotes
	if value.length() >= 2 and ((value.begins_with("\"") and value.ends_with("\""))
			or (value.begins_with("'") and value.ends_with("'"))):
		value = value.substr(1, value.length() - 2)
	return {"name": name, "op": "=", "value": value}


## Find the closing ``]`` of an attribute selector starting at ``from``,
## skipping over content inside double- or single-quoted strings.
## Returns -1 if no terminating bracket is found.
static func _find_attr_close(s: String, from: int) -> int:
	var i := from
	var n := s.length()
	var in_quote := ""
	while i < n:
		var ch := s[i]
		if in_quote != "":
			if ch == "\\" and i + 1 < n:
				i += 2
				continue
			if ch == in_quote:
				in_quote = ""
			i += 1
			continue
		if ch == "\"" or ch == "'":
			in_quote = ch
			i += 1
			continue
		if ch == "]":
			return i
		i += 1
	return -1


static func _is_ident_char(ch: String) -> bool:
	return ch.is_valid_identifier() or ch.is_valid_int() or ch == "-" or ch == "_"


static func _read_ident_end(s: String, start: int) -> int:
	var i := start
	var n := s.length()
	while i < n and _is_ident_char(s[i]):
		i += 1
	return i


## Test whether a Selector matches a DOM node given an explicit ancestor chain
## (root-first; the node itself is the last element of the chain).
static func matches(sel: Selector, ancestor_chain: Array) -> bool:
	if sel.compounds.is_empty() or ancestor_chain.is_empty():
		return false

	# The rightmost compound must match the candidate node itself.
	var node = ancestor_chain[ancestor_chain.size() - 1]
	var ci := sel.compounds.size() - 1
	if not _compound_matches(sel.compounds[ci], node):
		return false

	# Walk leftward through compounds, consuming the ancestor chain.
	var ai := ancestor_chain.size() - 2
	ci -= 1
	while ci >= 0:
		var combinator: String = sel.combinators[ci]
		var target = sel.compounds[ci]
		match combinator:
			">":
				if ai < 0:
					return false
				if not _compound_matches(target, ancestor_chain[ai]):
					return false
				ai -= 1
			" ":
				# Walk back until a match is found
				var matched := false
				while ai >= 0:
					if _compound_matches(target, ancestor_chain[ai]):
						matched = true
						ai -= 1
						break
					ai -= 1
				if not matched:
					return false
			_:
				return false
		ci -= 1
	return true


static func _compound_matches(compound: Compound, node) -> bool:
	if node == null or node.is_text_node:
		return false
	if not compound.tag.is_empty() and node.tag != compound.tag:
		return false
	if not compound.id.is_empty() and node.get_id() != compound.id:
		return false
	if not compound.classes.is_empty():
		var node_classes = node.get_classes()
		for cls in compound.classes:
			if not (cls in node_classes):
				return false
	for attr in compound.attrs:
		if not _attr_matches(attr, node):
			return false
	# Pseudo-class matching is NOT done here — that's the renderer's job (state-based).
	# Pseudo-classes only contribute to specificity at resolve time.
	return true


static func _attr_matches(attr: Dictionary, node) -> bool:
	var name: String = attr.get("name", "")
	var op: String = attr.get("op", "")
	var want: String = attr.get("value", "")
	if not node.has_attr(name):
		return false
	if op == "":
		return true
	var got: String = node.get_attr(name, "")
	match op:
		"=":
			return got == want
		_:
			return false


## Parse a selector group (comma-separated selectors) and return one Selector per piece.
static func parse_group(s: String) -> Array:
	var out: Array = []
	# Split on commas that are not inside [] or ()
	var pieces := _split_top_level(s, ",")
	for piece in pieces:
		var trimmed: String = piece.strip_edges()
		if trimmed.is_empty():
			continue
		out.append(parse(trimmed))
	return out


static func _split_top_level(s: String, sep: String) -> Array:
	var out: Array = []
	var depth_sq := 0
	var depth_p := 0
	var start := 0
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch == "[":
			depth_sq += 1
		elif ch == "]":
			depth_sq = maxi(0, depth_sq - 1)
		elif ch == "(":
			depth_p += 1
		elif ch == ")":
			depth_p = maxi(0, depth_p - 1)
		elif ch == sep and depth_sq == 0 and depth_p == 0:
			out.append(s.substr(start, i - start))
			start = i + 1
		i += 1
	out.append(s.substr(start, n - start))
	return out
