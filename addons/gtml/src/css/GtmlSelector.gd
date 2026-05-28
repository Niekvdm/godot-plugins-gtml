class_name GtmlSelector
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


## State pseudos affect runtime appearance (the renderer toggles them via
## input events) but do NOT participate in DOM matching. Anything else with a
## ":" prefix is treated as a structural pseudo and routed through the
## matcher's structural-pseudo path.
const STATE_PSEUDOS := ["hover", "active", "focus", "disabled", "checked"]


class Compound:
	## A single compound selector (one element's constraints).
	var tag: String = ""        # empty = universal/no tag constraint
	var id: String = ""
	var classes: PackedStringArray = PackedStringArray()
	var attrs: Array = []       # Array of {name, op, value}
	var pseudos: PackedStringArray = PackedStringArray()
	## Structural pseudos affect DOM matching. Each entry:
	##   {type: String, arg: Variant}
	## type ∈ {"first-child", "last-child", "only-child", "nth-child", "not"}.
	## - nth-child arg is a Dictionary {a: int, b: int} encoding an+b.
	## - not arg is a parsed Selector.
	var structural_pseudos: Array = []


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
			cls += c.structural_pseudos.size()
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

		# Whitespace -> descendant combinator (unless followed by an explicit combinator).
		if ch == " " or ch == "\t" or ch == "\n":
			i += 1
			while i < n and (s[i] == " " or s[i] == "\t" or s[i] == "\n"):
				i += 1
			if i >= n:
				break
			if s[i] == ">" or s[i] == "+" or s[i] == "~":
				_finalize_compound(sel, current, pending_combinator)
				current = Compound.new()
				pending_combinator = s[i]
				i += 1
				while i < n and (s[i] == " " or s[i] == "\t" or s[i] == "\n"):
					i += 1
				continue
			# pure descendant
			_finalize_compound(sel, current, pending_combinator)
			current = Compound.new()
			pending_combinator = " "
			continue

		if ch == ">" or ch == "+" or ch == "~":
			_finalize_compound(sel, current, pending_combinator)
			current = Compound.new()
			pending_combinator = ch
			i += 1
			# eat trailing whitespace after the combinator
			while i < n and (s[i] == " " or s[i] == "\t" or s[i] == "\n"):
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
			var pseudo_name: String = s.substr(i, p_end - i)
			i = p_end
			# Optional argument: :name(arg) — parse balanced parens, honoring
			# nested () and quoted "/' regions inside.
			var arg: String = ""
			var has_arg := false
			if i < n and s[i] == "(":
				has_arg = true
				var arg_end := _find_paren_close(s, i + 1)
				if arg_end < 0:
					push_warning("GtmlSelector: unterminated pseudo argument in '%s'" % s)
					break
				arg = s.substr(i + 1, arg_end - i - 1).strip_edges()
				i = arg_end + 1
			_route_pseudo(current, pseudo_name, arg, has_arg)
			continue

		if ch == "[":
			# Find the matching ] while ignoring closing brackets inside quoted
			# attribute values, e.g. [data-x="a]b"].
			var close := _find_attr_close(s, i + 1)
			if close < 0:
				push_warning("GtmlSelector: unterminated attribute selector in '%s'" % s)
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

	# The operator may be one of "=", "~=", "^=", "$=", "*=". The first three
	# substring matchers borrow the character immediately before the "=".
	var op: String = "="
	var name_end: int = eq
	if eq > 0:
		var prev: String = inner[eq - 1]
		if prev == "~" or prev == "^" or prev == "$" or prev == "*":
			op = prev + "="
			name_end = eq - 1

	var name: String = inner.substr(0, name_end).strip_edges()
	var value: String = inner.substr(eq + 1).strip_edges()
	if value.length() >= 2 and ((value.begins_with("\"") and value.ends_with("\""))
			or (value.begins_with("'") and value.ends_with("'"))):
		value = value.substr(1, value.length() - 2)
	return {"name": name, "op": op, "value": value}


## Find the matching `)` for a `(` at position ``from - 1``, respecting nested
## parens and quoted regions. Returns -1 if no terminator is found.
static func _find_paren_close(s: String, from: int) -> int:
	var i := from
	var n := s.length()
	var depth := 1
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
		elif ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return i
		i += 1
	return -1


## Dispatch a parsed pseudo into the appropriate compound bucket.
## Structural pseudos (first-child, nth-child, not, ...) go to structural_pseudos
## so the matcher checks them at match time. State pseudos (hover, focus, ...)
## go to pseudos so the resolver routes the rule into the right state bucket.
static func _route_pseudo(c: Compound, name: String, arg: String, has_arg: bool) -> void:
	match name:
		"first-child", "last-child", "only-child":
			c.structural_pseudos.append({"type": name, "arg": null})
		"nth-child":
			c.structural_pseudos.append({"type": "nth-child", "arg": _parse_nth(arg)})
		"not":
			# :not() takes a selector argument. We parse it as a full Selector
			# but at match time only consider its rightmost compound — combinator
			# arguments inside :not() are deferred past v0.3.
			c.structural_pseudos.append({"type": "not", "arg": parse(arg)})
		_:
			if has_arg:
				push_warning("GtmlSelector: unsupported pseudo with argument ':%s(%s)' — rule will not match anything" % [name, arg])
				# Push a never-matches sentinel so the rule is dropped at match time.
				c.structural_pseudos.append({"type": "_never", "arg": null})
			else:
				c.pseudos.append(name)


## Parse an nth-child argument into {a, b} encoding ``an + b``.
## Accepts integer ("3"), keywords ("odd" -> 2n+1, "even" -> 2n), and the
## an+b syntax ("2n+1", "3n-1", "-n+3"). Returns {a: 0, b: 0} on parse failure
## (never-matches because there is no element at position 0).
static func _parse_nth(raw: String) -> Dictionary:
	var s := raw.strip_edges().to_lower()
	if s == "odd":
		return {"a": 2, "b": 1}
	if s == "even":
		return {"a": 2, "b": 0}
	if s.is_valid_int():
		return {"a": 0, "b": s.to_int()}

	# an+b — locate the "n", split at it
	var n_pos := s.find("n")
	if n_pos < 0:
		return {"a": 0, "b": 0}
	var a_str := s.substr(0, n_pos).strip_edges()
	var b_str := s.substr(n_pos + 1).strip_edges()
	var a: int
	if a_str.is_empty() or a_str == "+":
		a = 1
	elif a_str == "-":
		a = -1
	elif a_str.is_valid_int():
		a = a_str.to_int()
	else:
		return {"a": 0, "b": 0}
	var b: int = 0
	if not b_str.is_empty():
		# b_str includes its sign, e.g. "+1" or "-3"
		if b_str.is_valid_int():
			b = b_str.to_int()
		else:
			# strip leading sign if needed
			var sign := 1
			if b_str.begins_with("+"):
				b_str = b_str.substr(1)
			elif b_str.begins_with("-"):
				sign = -1
				b_str = b_str.substr(1)
			if b_str.is_valid_int():
				b = sign * b_str.to_int()
	return {"a": a, "b": b}


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
##
## The walk goes right-to-left through compounds. Each combinator chooses how
## to advance the "current candidate" — descendant/child step up the chain,
## sibling combinators stay at the same depth and step through the parent's
## children. ``parent_idx`` always points at the chain entry that is the
## current candidate's parent, so structural pseudos and sibling lookups can
## both ask "what are my siblings?" cheaply.
static func matches(sel: Selector, ancestor_chain: Array) -> bool:
	if sel.compounds.is_empty() or ancestor_chain.is_empty():
		return false

	var current_node = ancestor_chain[ancestor_chain.size() - 1]
	var parent_idx: int = ancestor_chain.size() - 2

	var ci: int = sel.compounds.size() - 1
	if not _compound_matches(sel.compounds[ci], current_node, ancestor_chain, parent_idx):
		return false

	ci -= 1
	while ci >= 0:
		var combinator: String = sel.combinators[ci]
		var target: Compound = sel.compounds[ci]
		match combinator:
			">":
				if parent_idx < 0:
					return false
				current_node = ancestor_chain[parent_idx]
				parent_idx -= 1
				if not _compound_matches(target, current_node, ancestor_chain, parent_idx):
					return false
			" ":
				var matched := false
				while parent_idx >= 0:
					current_node = ancestor_chain[parent_idx]
					parent_idx -= 1
					if _compound_matches(target, current_node, ancestor_chain, parent_idx):
						matched = true
						break
				if not matched:
					return false
			"+":
				if parent_idx < 0:
					return false
				var parent = ancestor_chain[parent_idx]
				var prev = _prev_element_sibling(parent, current_node)
				if prev == null:
					return false
				current_node = prev
				if not _compound_matches(target, current_node, ancestor_chain, parent_idx):
					return false
			"~":
				if parent_idx < 0:
					return false
				var parent2 = ancestor_chain[parent_idx]
				var found := false
				var probe = current_node
				while true:
					var prev2 = _prev_element_sibling(parent2, probe)
					if prev2 == null:
						break
					if _compound_matches(target, prev2, ancestor_chain, parent_idx):
						current_node = prev2
						found = true
						break
					probe = prev2
				if not found:
					return false
			_:
				return false
		ci -= 1
	return true


static func _compound_matches(compound: Compound, node, chain: Array, parent_idx: int) -> bool:
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
	# Structural pseudos affect matching. State pseudos do not — those only
	# contribute to specificity and to the resolver's state bucketing.
	for sp in compound.structural_pseudos:
		if not _structural_matches(sp, node, chain, parent_idx):
			return false
	return true


## Test a structural pseudo (:first-child, :nth-child(...), :not(...), ...)
## against ``node``. ``chain[parent_idx]`` is the node's parent (or invalid
## when parent_idx < 0, meaning node is the root — first-child et al. all
## fail because there are no siblings to compare against).
static func _structural_matches(sp: Dictionary, node, chain: Array, parent_idx: int) -> bool:
	var t: String = sp.get("type", "")
	if t == "_never":
		return false
	if t == "not":
		# Run the inner selector against an augmented chain ending at this node.
		var inner = sp.get("arg")
		if inner == null:
			return false
		var sub_chain: Array = chain.slice(0, parent_idx + 1)
		sub_chain.append(node)
		return not matches(inner, sub_chain)

	# Remaining structural pseudos all need a parent for sibling indexing.
	if parent_idx < 0:
		return false
	var parent = chain[parent_idx]
	var element_siblings: Array = _element_children(parent)
	var idx: int = element_siblings.find(node)
	if idx < 0:
		return false  # defensive: node is detached from its claimed parent

	match t:
		"first-child":
			return idx == 0
		"last-child":
			return idx == element_siblings.size() - 1
		"only-child":
			return element_siblings.size() == 1
		"nth-child":
			var nth: Dictionary = sp.get("arg", {"a": 0, "b": 0})
			return _nth_matches(idx + 1, nth.get("a", 0), nth.get("b", 0))
		_:
			return false


## Return the element children of ``node`` (text nodes filtered out).
static func _element_children(node) -> Array:
	var out: Array = []
	for c in node.children:
		if c != null and not c.is_text_node:
			out.append(c)
	return out


## The element sibling immediately before ``current`` in ``parent``'s element
## children, or null if ``current`` is the first / not found.
static func _prev_element_sibling(parent, current):
	var children := _element_children(parent)
	var idx := children.find(current)
	if idx <= 0:
		return null
	return children[idx - 1]


## True when the 1-based ``position`` satisfies ``an + b`` for some non-negative
## integer n. ``a == 0`` reduces to ``position == b``. Uses integer arithmetic
## so very large positions don't lose precision.
static func _nth_matches(position: int, a: int, b: int) -> bool:
	if a == 0:
		return position == b
	var diff: int = position - b
	# n must be a non-negative integer satisfying a*n == diff
	if a > 0:
		return diff >= 0 and (diff % a) == 0
	# a < 0 — solutions exist when diff <= 0 and diff % a == 0
	return diff <= 0 and (diff % a) == 0


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
		"~=":
			# Whitespace-separated word list contains `want` as a whole word.
			if want.is_empty():
				return false
			return want in got.split(" ", false)
		"^=":
			return not want.is_empty() and got.begins_with(want)
		"$=":
			return not want.is_empty() and got.ends_with(want)
		"*=":
			return not want.is_empty() and got.contains(want)
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
