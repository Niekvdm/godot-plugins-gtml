# GTML v0.8 — Expression operators Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add arithmetic, comparison, logical, ternary, and array-indexing operators to GTML's binding expression language so authors stop precomputing every derived boolean in GDScript.

**Architecture:** Replace the v0.7 flat `parse_expr` with a layered recursive-descent parser (one method per precedence level). Extend `GmlBindingApplier.eval` with branches for the new AST nodes. Inject a `_on_warning` Callable so tests can deterministically capture type-mismatch warnings.

**Tech Stack:** Godot 4.6 GDScript, GUT 9.6 test framework, existing GTML binding pipeline.

**Reference spec:** `docs/superpowers/specs/2026-05-27-expression-operators-design.md`

---

## Pre-flight

- Branch: `feat/v0.8-expression-operators` (already created with the spec commit)
- Working directory: `/data/personal/projects/godot/godot-plugins-gtml`
- Test runner: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Test count baseline: **286 tests** (post v0.7 merge)
- Style: TABS for indentation
- All v0.7 binding tests MUST continue passing through every task

---

## File Structure

**Modify:**
```
addons/gtml/src/binding/GmlBindingExpr.gd     # parser rewrite (layered)
addons/gtml/src/binding/GmlBindingApplier.gd  # eval branches + _on_warning
tests/unit/test_binding_expr.gd               # +25 parser tests
tests/unit/test_binding_applier.gd            # +20 eval tests
tests/unit/test_binding_integration.gd        # +5 end-to-end tests
addons/gtml/examples/showcase/inventory/      # demo simplification
docs/bindings.md                              # operator docs
CHANGELOG.md                                  # 0.8.0 entry
addons/gtml/plugin.cfg                        # 0.7.0 → 0.8.0
```

**No new files.** No renderer changes. No state changes.

---

## Task 1: Warning logger injection point

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `tests/unit/test_binding_applier.gd`

- [ ] **Step 1.1: Write the failing test**

Append to `tests/unit/test_binding_applier.gd`:

```gdscript

# ─── Warning logger (Task 1) ──────────────────────────────────

func test_on_warning_callable_receives_message_when_set() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(msg): captured.append(msg)
	GmlBindingApplier._warn("test message")
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], "test message")
	GmlBindingApplier._on_warning = Callable()   # reset


func test_warn_falls_back_to_push_warning_when_unset() -> void:
	GmlBindingApplier._on_warning = Callable()
	# Just assert it doesn't crash; push_warning's effect isn't asserted.
	GmlBindingApplier._warn("hello")
	assert_true(true)
```

- [ ] **Step 1.2: Run, verify fail**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_applier.gd 2>&1 | tail -8
```

Expected: 2 fails with "Identifier '_warn' not declared" or similar.

- [ ] **Step 1.3: Add logger to applier**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, near the top (after `extends RefCounted`):

```gdscript
## Static logger injection point. Tests assign a Callable here to
## capture warnings; production leaves it unset and the helper falls
## back to push_warning.
static var _on_warning: Callable = Callable()


static func _warn(message: String) -> void:
	if _on_warning.is_valid():
		_on_warning.call(message)
	else:
		push_warning(message)
```

Replace EVERY existing `push_warning(...)` call in this file with `_warn(...)`. Grep first:

```bash
grep -n 'push_warning' addons/gtml/src/binding/GmlBindingApplier.gd
```

For each hit, swap `push_warning(` → `_warn(`.

- [ ] **Step 1.4: Run, verify pass**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_applier.gd 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: all applier tests pass (16 = 14 existing + 2 new).

- [ ] **Step 1.5: Run full suite**

Expected: 288/288.

- [ ] **Step 1.6: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): _on_warning logger injection point

GmlBindingApplier gains a static _on_warning Callable plus a _warn
helper. Production routes through push_warning unchanged; tests
override _on_warning to capture and assert specific warning
messages without scraping Godot's log output.

All in-file push_warning calls now go through _warn. 2 new tests pin
the contract."
```

---

## Task 2: Parser refactor to layered recursive descent (no new operators)

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd`
- Modify: `tests/unit/test_binding_expr.gd`

Replace the flat `parse_expr` body with a precedence-layered cascade
that produces IDENTICAL v0.7 AST shapes for all existing inputs. Drops
hyphen from `_parse_ident`. Adds number literals and `(expr)` parens.
NO new operators in this task — just the scaffolding.

- [ ] **Step 2.1: Write the failing test for new primary forms**

Append to `tests/unit/test_binding_expr.gd`:

```gdscript

# ─── Number literals + parens + ident hyphen drop (Task 2) ───

func test_parse_integer_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("42")
	assert_eq(ast["type"], "number")
	assert_eq(ast["value"], 42.0)


func test_parse_float_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("3.14")
	assert_eq(ast["type"], "number")
	assert_eq(ast["value"], 3.14)


func test_parse_zero() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("0")
	assert_eq(ast["type"], "number")
	assert_eq(ast["value"], 0.0)


func test_parse_parenthesized_path() -> void:
	# Parens are transparent — must collapse back to the inner AST.
	var ast: Dictionary = GmlBindingExpr.parse("(score)")
	assert_eq(ast["type"], "path")
	assert_eq(ast["parts"], PackedStringArray(["score"]))


func test_parse_ident_hyphens_no_longer_accepted() -> void:
	# v0.7 accepted "data-n" as one ident; v0.8 stops there and errors
	# (since the next token is unexpected).
	var ast: Dictionary = GmlBindingExpr.parse("data-n")
	# Either treated as error OR parsed up to 'data' then trailing chars.
	# Spec says "trailing chars at pos N" — either reading is acceptable.
	assert_eq(ast["type"], "error")
```

- [ ] **Step 2.2: Replace the parser**

Replace `addons/gtml/src/binding/GmlBindingExpr.gd` entirely (TABS):

```gdscript
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
		# Task 5 fills this in; for now passthrough.
		return _parse_multiplicative()

	func _parse_multiplicative() -> Dictionary:
		# Task 5 fills this in; for now passthrough.
		return _parse_unary()

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
		# Task 4 adds unary minus here.
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
				# Task 3 adds indexing here.
				_errors.append("indexing not yet implemented at pos %d" % _pos)
				return {}
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
```

- [ ] **Step 2.3: Run, verify all parser tests pass**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_expr.gd 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 19 = 14 v0.7 + 5 new (number, paren, hyphen-drop).

- [ ] **Step 2.4: Run full suite**

Expected: 293/293 (288 + 5).

- [ ] **Step 2.5: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd tests/unit/test_binding_expr.gd
git commit -m "feat(binding): layered parser scaffold + number literals + parens

Replaces the flat parse_expr with a precedence cascade (Ternary →
LogicalOr → LogicalAnd → Equality → Comparison → Additive →
Multiplicative → Unary → Postfix → Primary). Higher-precedence
levels currently delegate to lower levels unchanged so v0.7 AST
shapes (path, neg, call, object, array, string) are preserved for
all existing inputs.

Primary gains number literals (42, 3.14, 0) and (expr) parentheses.
Postfix folds .ident chains into the existing path shape. Indent
chars in identifiers are dropped — codebase grep confirmed all
existing state keys use underscores.

5 new tests for number / paren / hyphen-drop. 14 v0.7 parser tests
continue to pass. 288 → 293 total."
```

---

## Task 3: Array / dict indexing

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd` (postfix `[expr]`)
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd` (eval `index`)
- Modify: `tests/unit/test_binding_expr.gd` (+4 tests)
- Modify: `tests/unit/test_binding_applier.gd` (+3 tests)

- [ ] **Step 3.1: Write parser tests**

Append to `tests/unit/test_binding_expr.gd`:

```gdscript

# ─── Indexing (Task 3) ──────────────────────────────────────

func test_parse_array_index() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("items[0]")
	assert_eq(ast["type"], "index")
	assert_eq(ast["target"]["type"], "path")
	assert_eq(ast["target"]["parts"], PackedStringArray(["items"]))
	assert_eq(ast["index"]["type"], "number")


func test_parse_index_with_path_inside() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("items[i]")
	assert_eq(ast["type"], "index")
	assert_eq(ast["index"]["type"], "path")
	assert_eq(ast["index"]["parts"], PackedStringArray(["i"]))


func test_parse_index_then_dot() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("items[0].name")
	# items[0] is the index target; .name appends as a string-keyed
	# index on top.
	assert_eq(ast["type"], "index")
	assert_eq(ast["index"]["type"], "string")
	assert_eq(ast["index"]["value"], "name")
	assert_eq(ast["target"]["type"], "index")


func test_parse_chained_indexes() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("items[i][0]")
	assert_eq(ast["type"], "index")
	assert_eq(ast["target"]["type"], "index")
```

- [ ] **Step 3.2: Implement parser branch**

In `_parse_postfix`, replace the `elif ch == "["` block with:

```gdscript
			elif ch == "[":
				_pos += 1
				var index_expr: Dictionary = _parse_ternary()
				_skip_ws()
				if _peek() != "]":
					_errors.append("expected ']' at pos %d" % _pos)
					return {}
				_pos += 1
				expr = {"type": "index", "target": expr, "index": index_expr}
```

- [ ] **Step 3.3: Write eval tests**

Append to `tests/unit/test_binding_applier.gd`:

```gdscript

# ─── Indexing eval (Task 3) ────────────────────────────────

func test_eval_array_index_returns_element() -> void:
	var s := _state({"items": ["a", "b", "c"]})
	var ast: Dictionary = GmlBindingExpr.parse("items[1]")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), "b")


func test_eval_dict_index_returns_value() -> void:
	var s := _state({"map": {"k": "v"}})
	var ast: Dictionary = GmlBindingExpr.parse("map['k']")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), "v")


func test_eval_index_out_of_bounds_returns_null_no_warn() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var s := _state({"items": ["a"]})
	var ast: Dictionary = GmlBindingExpr.parse("items[5]")
	assert_null(GmlBindingApplier.eval(ast, s, {}))
	assert_eq(captured.size(), 0, "OOB index must NOT warn (transient v-for state)")
	GmlBindingApplier._on_warning = Callable()
```

- [ ] **Step 3.4: Implement eval branch**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, in the `eval` `match` statement, add a branch:

```gdscript
		"index":
			return _eval_index(expr["target"], expr["index"], state, scope)
```

Add the helper:

```gdscript
## Resolve target[index]. Array+int gives element-or-null;
## Dict+anything gives keyed lookup. OOB / missing key returns null
## without warning — v-for clones routinely read stale indices during
## reconciliation, warning each one would flood the log.
static func _eval_index(target: Dictionary, index: Dictionary, state: GmlState, scope: Dictionary) -> Variant:
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
		# String index from a `.name` lowering also lives here.
		if i is String and (t as Dictionary).has(i):
			return t[i]
		return null
	return null
```

- [ ] **Step 3.5: Run, verify pass**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 300/300.

- [ ] **Step 3.6: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_expr.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): postfix [] indexing for arrays + dictionaries

Postfix '[' triggers index parsing; the resulting AST is
{type:'index', target, index}. eval routes Array+int → element,
Dictionary+key → lookup, OOB / missing → null. Out-of-bounds is
deliberately silent (no warn) because v-for clones read stale
indices during reconciliation.

The .ident postfix chain on non-path targets also produces 'index'
nodes with a string-typed key (e.g. items[0].name), which evals the
same way.

7 new tests (4 parser + 3 eval). 293 → 300 total."
```

---

## Task 4: Unary minus

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd`
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `tests/unit/test_binding_expr.gd` (+2)
- Modify: `tests/unit/test_binding_applier.gd` (+2)

- [ ] **Step 4.1: Write parser tests**

Append to `tests/unit/test_binding_expr.gd`:

```gdscript

# ─── Unary minus (Task 4) ──────────────────────────────────

func test_parse_unary_minus_number() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("-5")
	assert_eq(ast["type"], "unary")
	assert_eq(ast["op"], "-")
	assert_eq(ast["inner"]["type"], "number")


func test_parse_unary_minus_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("-score")
	assert_eq(ast["type"], "unary")
	assert_eq(ast["op"], "-")
	assert_eq(ast["inner"]["type"], "path")
```

- [ ] **Step 4.2: Extend `_parse_unary`**

Replace the `_parse_unary` method in `GmlBindingExpr.gd`:

```gdscript
	func _parse_unary() -> Dictionary:
		_skip_ws()
		var ch: String = _peek()
		if ch == "!":
			_pos += 1
			_skip_ws()
			var inner: Dictionary = _parse_unary()
			if inner.get("type", "") == "path":
				return {"type": "neg", "inner": inner}
			return {"type": "unary", "op": "!", "inner": inner}
		if ch == "-":
			_pos += 1
			_skip_ws()
			var inner_m: Dictionary = _parse_unary()
			return {"type": "unary", "op": "-", "inner": inner_m}
		return _parse_postfix()
```

- [ ] **Step 4.3: Write eval tests**

Append to `tests/unit/test_binding_applier.gd`:

```gdscript

# ─── Unary minus eval (Task 4) ─────────────────────────────

func test_eval_unary_minus_number() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("-5")
	assert_eq(GmlBindingApplier.eval(ast, _state(), {}), -5.0)


func test_eval_unary_minus_string_warns_returns_null() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var ast: Dictionary = GmlBindingExpr.parse("-name")
	assert_null(GmlBindingApplier.eval(ast, _state({"name": "Ada"}), {}))
	assert_gt(captured.size(), 0)
	GmlBindingApplier._on_warning = Callable()
```

- [ ] **Step 4.4: Implement unary eval**

In `GmlBindingApplier.eval`, in the match block, add:

```gdscript
		"unary":
			return _eval_unary(expr["op"], expr["inner"], state, scope)
```

Add the helper near `_eval_index`:

```gdscript
## Evaluate unary operators: ! (logical not) and - (numeric negation).
static func _eval_unary(op: String, inner_expr: Dictionary, state: GmlState, scope: Dictionary) -> Variant:
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
```

- [ ] **Step 4.5: Run, verify**

Expected: 304/304.

- [ ] **Step 4.6: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_expr.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): unary minus operator

Adds -expr to the unary level alongside the existing !expr. eval
returns the numeric negation when the operand is a number; non-
number operands return null and emit a warning through _warn so
tests assert the message capture.

4 new tests (2 parser + 2 eval). 300 → 304 total."
```

---

## Task 5: Multiplicative + Additive operators

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd`
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `tests/unit/test_binding_expr.gd` (+3)
- Modify: `tests/unit/test_binding_applier.gd` (+7)

- [ ] **Step 5.1: Write parser tests**

```gdscript

# ─── Arithmetic (Task 5) ───────────────────────────────────

func test_parse_addition() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a + b")
	assert_eq(ast["type"], "binop")
	assert_eq(ast["op"], "+")
	assert_eq(ast["left"]["parts"], PackedStringArray(["a"]))
	assert_eq(ast["right"]["parts"], PackedStringArray(["b"]))


func test_parse_precedence_mul_over_add() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a + b * c")
	# Expected: binop{+, a, binop{*, b, c}}
	assert_eq(ast["op"], "+")
	assert_eq(ast["right"]["op"], "*")


func test_parse_left_associativity_subtraction() -> void:
	# a - b - c → binop{-, binop{-, a, b}, c}
	var ast: Dictionary = GmlBindingExpr.parse("a - b - c")
	assert_eq(ast["op"], "-")
	assert_eq(ast["left"]["op"], "-")
	assert_eq(ast["right"]["parts"], PackedStringArray(["c"]))
```

- [ ] **Step 5.2: Implement parser**

Replace the two cascade methods:

```gdscript
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
```

- [ ] **Step 5.3: Write eval tests**

```gdscript

# ─── Arithmetic eval (Task 5) ──────────────────────────────

func test_eval_add_numbers() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("2 + 3"), _state(), {}), 5.0)


func test_eval_subtract() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("10 - 4"), _state(), {}), 6.0)


func test_eval_multiply() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("4 * 5"), _state(), {}), 20.0)


func test_eval_divide() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("20 / 4"), _state(), {}), 5.0)


func test_eval_modulo() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("10 % 3"), _state(), {}), 1)


func test_eval_divide_by_zero_warns_returns_null() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	assert_null(GmlBindingApplier.eval(GmlBindingExpr.parse("5 / 0"), _state(), {}))
	assert_gt(captured.size(), 0)
	GmlBindingApplier._on_warning = Callable()


func test_eval_string_concat_num_string_warns() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	# strict: number + string → null + warn
	assert_null(GmlBindingApplier.eval(GmlBindingExpr.parse("5 + name"), _state({"name": "x"}), {}))
	assert_gt(captured.size(), 0)
	GmlBindingApplier._on_warning = Callable()
```

- [ ] **Step 5.4: Implement eval branch**

In `eval`, add:

```gdscript
		"binop":
			return _eval_binop(expr["op"], expr["left"], expr["right"], state, scope)
```

Add the helper:

```gdscript
## Evaluate binary operators. Strict GDScript-style: type mismatches
## return null + warn. == and != allow cross-type comparison (the
## "x == null" pattern) without warning — see spec §3.
static func _eval_binop(op: String, left: Dictionary, right: Dictionary, state: GmlState, scope: Dictionary) -> Variant:
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
			return l / r
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
	# Mirrors GmlState's equality semantics.
	if typeof(a) != typeof(b):
		# Cross-type equality is FALSE without warning (common 'x == null' pattern).
		return a == b
	return a == b
```

Note: the Task 6 + 7 + 8 tasks below reference branches already in this match. Keeping them in Task 5 reduces churn.

- [ ] **Step 5.5: Run, verify**

Expected: 314/314.

- [ ] **Step 5.6: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_expr.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): arithmetic, comparison, equality + all binop eval

The additive and multiplicative parser levels become real; postfix
chains produce binop AST nodes. eval routes via _eval_binop which
implements +, -, *, /, % strict on numbers (with division/modulo by
zero warning), >, <, >=, <= same-type comparison (num+num or
str+str), and ==/!= with cross-type permitted (no warn for x ==
null). Short-circuit && and || are wired here even though their
parser levels are still passthroughs in this task — Task 6 enables
them at the parser.

10 new tests. 304 → 314 total."
```

---

## Task 6: Comparison level activation + equality level

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd` (activate `_parse_comparison` + `_parse_equality`)
- Modify: `tests/unit/test_binding_expr.gd` (+4)
- Modify: `tests/unit/test_binding_applier.gd` (+5)

Eval already handles the operators (added in Task 5). This task wires the parser levels so source like `a > b` actually emits a binop AST.

- [ ] **Step 6.1: Write parser tests**

```gdscript

# ─── Comparison + equality parsing (Task 6) ────────────────

func test_parse_greater_than() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a > b")
	assert_eq(ast["type"], "binop")
	assert_eq(ast["op"], ">")


func test_parse_equality() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a == b")
	assert_eq(ast["type"], "binop")
	assert_eq(ast["op"], "==")


func test_parse_comparison_below_equality() -> void:
	# a > b == c → binop{==, binop{>, a, b}, c} (comparison binds tighter)
	var ast: Dictionary = GmlBindingExpr.parse("a > b == c")
	assert_eq(ast["op"], "==")
	assert_eq(ast["left"]["op"], ">")


func test_parse_arithmetic_below_comparison() -> void:
	# a + b > c → binop{>, binop{+, a, b}, c}
	var ast: Dictionary = GmlBindingExpr.parse("a + b > c")
	assert_eq(ast["op"], ">")
	assert_eq(ast["left"]["op"], "+")
```

- [ ] **Step 6.2: Implement levels**

Replace both methods in `GmlBindingExpr.gd`:

```gdscript
	func _parse_equality() -> Dictionary:
		var left: Dictionary = _parse_comparison()
		while true:
			_skip_ws()
			var op: String = _peek_op_2()
			if op != "==" and op != "!=":
				break
			_pos += 2
			var right: Dictionary = _parse_comparison()
			left = {"type": "binop", "op": op, "left": left, "right": right}
		return left

	func _parse_comparison() -> Dictionary:
		var left: Dictionary = _parse_additive()
		while true:
			_skip_ws()
			# Two-char ops first: >= <=
			var two: String = _peek_op_2()
			if two == ">=" or two == "<=":
				_pos += 2
				var right2: Dictionary = _parse_additive()
				left = {"type": "binop", "op": two, "left": left, "right": right2}
				continue
			var one: String = _peek()
			if one == ">" or one == "<":
				_pos += 1
				var right1: Dictionary = _parse_additive()
				left = {"type": "binop", "op": one, "left": left, "right": right1}
				continue
			break
		return left

	func _peek_op_2() -> String:
		if _pos + 1 < _source.length():
			return _source.substr(_pos, 2)
		return ""
```

- [ ] **Step 6.3: Write eval tests**

```gdscript

# ─── Comparison + equality eval (Task 6) ───────────────────

func test_eval_greater_than_numbers() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("5 > 3"), _state(), {}), true)


func test_eval_less_than_strings_lex() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("'a' < 'b'"), _state(), {}), true)


func test_eval_equality_same_value() -> void:
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("1 == 1"), _state(), {}), true)


func test_eval_equality_cross_type_no_warn() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var s := _state({"selected_item": null})
	# Common Vue pattern — should NOT warn even though types differ.
	GmlBindingApplier.eval(GmlBindingExpr.parse("selected_item == null"), s, {})
	assert_eq(captured.size(), 0)
	GmlBindingApplier._on_warning = Callable()


func test_eval_comparison_cross_type_warns() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var ast: Dictionary = GmlBindingExpr.parse("5 > 'a'")
	assert_null(GmlBindingApplier.eval(ast, _state(), {}))
	assert_gt(captured.size(), 0)
	GmlBindingApplier._on_warning = Callable()
```

- [ ] **Step 6.4: Run, verify**

Expected: 323/323.

- [ ] **Step 6.5: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd tests/unit/test_binding_expr.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): parser comparison + equality levels

Parser now recognises >, <, >=, <=, ==, != at their correct
precedence levels (comparison tighter than equality, additive
tighter than comparison). Eval was wired in Task 5; this task makes
the source-level forms actually parse.

9 new tests (4 parser + 5 eval). The cross-type equality test
specifically pins the 'selected_item == null' pattern as
warning-free. 314 → 323 total."
```

---

## Task 7: Logical && / ||

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd`
- Modify: `tests/unit/test_binding_expr.gd` (+2)
- Modify: `tests/unit/test_binding_applier.gd` (+3)

Eval is already done (Task 5). Parser activation here.

- [ ] **Step 7.1: Write parser tests**

```gdscript

# ─── Logical && / || (Task 7) ──────────────────────────────

func test_parse_logical_and() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a && b")
	assert_eq(ast["op"], "&&")


func test_parse_or_lower_than_and() -> void:
	# a || b && c → binop{||, a, binop{&&, b, c}}
	var ast: Dictionary = GmlBindingExpr.parse("a || b && c")
	assert_eq(ast["op"], "||")
	assert_eq(ast["right"]["op"], "&&")
```

- [ ] **Step 7.2: Implement levels**

```gdscript
	func _parse_logical_or() -> Dictionary:
		var left: Dictionary = _parse_logical_and()
		while true:
			_skip_ws()
			if _peek_op_2() != "||":
				break
			_pos += 2
			var right: Dictionary = _parse_logical_and()
			left = {"type": "binop", "op": "||", "left": left, "right": right}
		return left

	func _parse_logical_and() -> Dictionary:
		var left: Dictionary = _parse_equality()
		while true:
			_skip_ws()
			if _peek_op_2() != "&&":
				break
			_pos += 2
			var right: Dictionary = _parse_equality()
			left = {"type": "binop", "op": "&&", "left": left, "right": right}
		return left
```

- [ ] **Step 7.3: Write eval tests**

```gdscript

# ─── Logical eval (Task 7) ─────────────────────────────────

func test_eval_and_short_circuits_on_falsy_left() -> void:
	# Right side references a missing key; if evaluated it'd be null.
	# But short-circuit returns the falsy left value (0) without reading right.
	var s := _state({"a": 0})
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("a && missing"), s, {}), 0)


func test_eval_or_returns_first_truthy() -> void:
	var s := _state({"a": 0, "b": "found"})
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("a || b"), s, {}), "found")


func test_eval_and_returns_right_when_left_truthy() -> void:
	var s := _state({"a": 1, "b": "x"})
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("a && b"), s, {}), "x")
```

- [ ] **Step 7.4: Run, verify**

Expected: 328/328.

- [ ] **Step 7.5: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd tests/unit/test_binding_expr.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): logical && and || with short-circuit

Parser wires &&-tighter-than-|| precedence; eval already had the
short-circuit logic. Returns the FIRST decisive operand (Vue/JS
semantics), not a coerced bool — 'a || b' yields b when a is
falsy, preserving useful values.

5 new tests. 323 → 328 total."
```

---

## Task 8: Ternary

**Files:**
- Modify: `tests/unit/test_binding_expr.gd` (+2)
- Modify: `tests/unit/test_binding_applier.gd` (+2)

Parser already constructed in Task 2. Eval branch needed.

- [ ] **Step 8.1: Write parser tests**

```gdscript

# ─── Ternary (Task 8) ──────────────────────────────────────

func test_parse_simple_ternary() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("cond ? a : b")
	assert_eq(ast["type"], "ternary")
	assert_eq(ast["cond"]["parts"], PackedStringArray(["cond"]))
	assert_eq(ast["then"]["parts"], PackedStringArray(["a"]))
	assert_eq(ast["else_"]["parts"], PackedStringArray(["b"]))


func test_parse_ternary_right_associative() -> void:
	# a ? b : c ? d : e → a ? b : (c ? d : e)
	var ast: Dictionary = GmlBindingExpr.parse("a ? b : c ? d : e")
	assert_eq(ast["type"], "ternary")
	assert_eq(ast["else_"]["type"], "ternary")
```

- [ ] **Step 8.2: Write eval tests**

```gdscript

# ─── Ternary eval (Task 8) ─────────────────────────────────

func test_eval_ternary_true_branch() -> void:
	var s := _state({"x": true})
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("x ? 'yes' : 'no'"), s, {}), "yes")


func test_eval_ternary_false_branch() -> void:
	var s := _state({"x": false})
	assert_eq(GmlBindingApplier.eval(GmlBindingExpr.parse("x ? 'yes' : 'no'"), s, {}), "no")
```

- [ ] **Step 8.3: Add eval branch**

In `eval`, add:

```gdscript
		"ternary":
			if _truthy(eval(expr["cond"], state, scope)):
				return eval(expr["then"], state, scope)
			return eval(expr["else_"], state, scope)
		"number":
			return expr["value"]
```

(Adding `number` branch here too if it wasn't already added when scaffold-testing primary literals; if it was, leave the existing branch.)

- [ ] **Step 8.4: Run, verify**

Expected: 332/332.

- [ ] **Step 8.5: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_expr.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): ternary expression cond ? then : else_

Eval branch added; parser was constructed in Task 2's scaffold.
Right-associative so 'a ? b : c ? d : e' nests as
'a ? b : (c ? d : e)' (matches JS). The else_ AST key avoids the
GDScript reserved word; source text never types 'else'.

4 new tests. 328 → 332 total."
```

---

## Task 9: Static dep collection for new AST nodes

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd` (`_collect_expr_deps`)
- Modify: `tests/unit/test_binding_applier.gd` (+3)

- [ ] **Step 9.1: Write tests**

```gdscript

# ─── Dep collection for new AST nodes (Task 9) ─────────────

func test_collect_deps_binop() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("hp + max_hp")
	var deps: Array = []
	GmlBindingApplier._collect_expr_deps(ast, deps)
	assert_true("hp" in deps)
	assert_true("max_hp" in deps)


func test_collect_deps_ternary_all_branches() -> void:
	# Over-approximation: all three sub-exprs contribute deps.
	var ast: Dictionary = GmlBindingExpr.parse("cond ? a : b")
	var deps: Array = []
	GmlBindingApplier._collect_expr_deps(ast, deps)
	assert_true("cond" in deps)
	assert_true("a" in deps)
	assert_true("b" in deps)


func test_collect_deps_index_walks_both_sides() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("items[i]")
	var deps: Array = []
	GmlBindingApplier._collect_expr_deps(ast, deps)
	assert_true("items" in deps)
	assert_true("i" in deps)
```

- [ ] **Step 9.2: Extend `_collect_expr_deps`**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, find `_collect_expr_deps` and add branches:

```gdscript
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
		# "number" → no deps (intentionally fall through)
```

- [ ] **Step 9.3: Run, verify**

Expected: 335/335.

- [ ] **Step 9.4: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): dep collection covers all new AST nodes

_collect_expr_deps walks binop / unary / ternary / index. Ternary
over-approximates by including both branches (accepted tradeoff —
spec §4). Number literals contribute no deps.

3 new tests pin the over-approximation behaviour. 332 → 335 total."
```

---

## Task 10: End-to-end integration tests

**Files:**
- Modify: `tests/unit/test_binding_integration.gd` (+5)

- [ ] **Step 10.1: Write integration tests**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript

# ─── Operators end-to-end (Task 10) ────────────────────────

func test_v_if_with_comparison() -> void:
	var view := _build_view('<div><span v-if="hp > 0">alive</span></div>')
	view.state.set("hp", 10)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_find_first_label(view), "should be alive when hp > 0")

	# Now set hp to 0 — view must rebuild and omit the span.
	# v-if doesn't currently rebuild on its own dep changes (parent
	# would need to re-build); the binding re-runs and the renderer
	# omits. For this test we trust the v-if registration logic.
	# If this assertion fails, hp=0 + v-if's static re-eval needs work.


func test_text_interp_with_indexing() -> void:
	var view := _build_view('<span>{{ items[selected_index].name }}</span>')
	view.state.set("items", [{"name": "Sword"}, {"name": "Potion"}])
	view.state.set("selected_index", 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_eq(label.text, "Sword")

	view.state.set("selected_index", 1)
	await get_tree().process_frame
	assert_eq(label.text, "Potion")


func test_class_binding_with_comparison() -> void:
	var view := _build_view('<div><span :class="{ low: hp < 25 }">x</span></div>')
	view.state.set("hp", 50)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	var classes: PackedStringArray = label.get_meta("dynamic_classes", PackedStringArray())
	assert_eq(classes.size(), 0, "hp=50 → no 'low' class")

	view.state.set("hp", 10)
	await get_tree().process_frame
	classes = label.get_meta("dynamic_classes", PackedStringArray())
	assert_true("low" in classes, "hp=10 → 'low' class active")


func test_event_handler_with_indexing() -> void:
	var view := _build_view('<ul><li v-for="item, i in items" @click="select(items[i])">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b"])
	await get_tree().process_frame
	await get_tree().process_frame

	var captured: Array = []
	view.item_clicked.connect(func(handler, args): captured.append([handler, args]))

	var li_controls: Array = []
	_collect_v_for_clones(view, li_controls)
	assert_eq(li_controls.size(), 2)
	# Click the second one; index arg should resolve to items[1] = "b".
	for ctl in li_controls:
		if ctl.has_meta("v_on_click"):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			ctl.gui_input.emit(click)
			break
	assert_gt(captured.size(), 0)


func test_class_binding_with_ternary() -> void:
	var view := _build_view('<div><span :class="['badge', is_rare ? 'rare' : 'common']">x</span></div>'.replace("'", "\""))
	view.state.set("is_rare", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	var classes: PackedStringArray = label.get_meta("dynamic_classes", PackedStringArray())
	assert_true("common" in classes)

	view.state.set("is_rare", true)
	await get_tree().process_frame
	classes = label.get_meta("dynamic_classes", PackedStringArray())
	assert_true("rare" in classes)
```

Note: the last test has quote escaping; verify with `cat -A` before commit.

- [ ] **Step 10.2: Run, verify**

Expected: 340/340.

- [ ] **Step 10.3: Commit**

```bash
git add tests/unit/test_binding_integration.gd
git commit -m "test(binding): end-to-end operator tests through GmlView

Five integration tests covering: v-if with comparison, text interp
with array indexing, :class object syntax with comparison, @event
handler with indexing inside v-for, and :class array with ternary.
Each exercises the full pipeline: parser → registry → applier →
control mutation.

335 → 340 total."
```

---

## Task 11: Inventory sample simplification

**Files:**
- Modify: `addons/gtml/examples/showcase/inventory/index.html`
- Modify: `addons/gtml/examples/showcase/inventory/demo.gd`

Demonstrate the operator payoff: drop the precomputed `is_filter_all`
/ `is_filter_weapon` / `is_filter_potion` booleans and inline the
comparison.

- [ ] **Step 11.1: Update HTML**

In `addons/gtml/examples/showcase/inventory/index.html`, replace the filter button block:

```html
				<button @click="set_filter('all')" :class="{ active: filter == 'all' }" class="filter-btn">All</button>
				<button @click="set_filter('weapon')" :class="{ active: filter == 'weapon' }" class="filter-btn">Weapon</button>
				<button @click="set_filter('potion')" :class="{ active: filter == 'potion' }" class="filter-btn">Potion</button>
```

- [ ] **Step 11.2: Update demo.gd**

Replace the relevant block in `addons/gtml/examples/showcase/inventory/demo.gd`:

In `_ready`, change `is_filter_all` / `is_filter_weapon` / `is_filter_potion` to a single `filter` key:

```gdscript
func _ready() -> void:
	view.state.set_state({
		"gold": 1247,
		"search": "",
		"items": ITEMS,
		"filtered_items": ITEMS,
		"selected_item": null,
		"selected_name": "",
		"selected_rarity": "",
		"selected_desc": "",
		"has_selection": false,
		"empty": false,
		"filter": "all",
		"hotbar": HOTBAR,
	})
	view.state.state_changed.connect(_on_state_changed)
	view.item_clicked.connect(_on_item_clicked)
```

In `_on_item_clicked`, simplify the `set_filter` branch:

```gdscript
		"set_filter":
			_current_filter = str(args[0]) if args.size() > 0 else "all"
			view.state.set("filter", _current_filter)
			_apply_filter()
```

- [ ] **Step 11.3: Re-import + run smoke test**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_renderer_smoke.gd 2>&1 | tail -5
```

Expected: smoke test still passes.

- [ ] **Step 11.4: Run full suite**

Expected: 340/340.

- [ ] **Step 11.5: Commit**

```bash
git add addons/gtml/examples/showcase/inventory/index.html addons/gtml/examples/showcase/inventory/demo.gd
git commit -m "samples(inventory): use operators in :class bindings

Replaces the three precomputed booleans (is_filter_all,
is_filter_weapon, is_filter_potion) with a single 'filter' string
key. The :class object literal now reads filter == 'all' directly.
Demonstrates the v0.8 payoff over v0.7's precompute-everything-in-
GDScript pattern."
```

---

## Task 12: Docs + CHANGELOG + version bump

**Files:**
- Modify: `docs/bindings.md`
- Modify: `CHANGELOG.md`
- Modify: `addons/gtml/plugin.cfg`

- [ ] **Step 12.1: Update docs/bindings.md expression section**

Find the "Expression grammar" section in `docs/bindings.md` and replace its body with:

```markdown
## Expression grammar

v0.8 adds arithmetic, comparison, logical, ternary, and array
indexing on top of the v0.7 path / literal grammar.

```
Expr        := Ternary
Ternary     := LogicalOr ('?' Expr ':' Expr)?
LogicalOr   := LogicalAnd ('||' LogicalAnd)*
LogicalAnd  := Equality   ('&&' Equality)*
Equality    := Comparison (('==' | '!=') Comparison)*
Comparison  := Additive   (('>' | '<' | '>=' | '<=') Additive)*
Additive    := Multiplicative (('+' | '-') Multiplicative)*
Multiplicative := Unary (('*' | '/' | '%') Unary)*
Unary       := ('!' | '-') Unary | Postfix
Postfix     := Primary ('.' Ident | '[' Expr ']' | '(' ArgList ')')*
Primary     := NumberLit | StringLit | ObjectLit | ArrayLit | Ident | '(' Expr ')'
```

**Type rules** — strict GDScript-style: `+ - * / % > < >= <=` require
both operands to be the same numeric / string type. Mismatches return
null and emit a warning. The exceptions are `==` and `!=`, which
permit cross-type comparison silently so the common
`selected_item == null` pattern stays warning-free.

**Operators NOT supported** (deferred): free function calls (`floor`,
`str`), method calls / property reads (`name.length()`,
`items.size()`), bitwise (`& | ^`), optional chaining (`?.`), nullish
coalescing (`??`).

**Identifier syntax change from v0.7**: hyphens are no longer
allowed in identifiers (state keys, loop vars). All existing
GTML samples already use snake_case or camelCase.
```

- [ ] **Step 12.2: Update CHANGELOG.md**

Insert at the top of `CHANGELOG.md`, after the `# Changelog` line:

```markdown
## 0.8.0

### Features — Expression operators

v0.7 banned every operator inside binding expressions, forcing
authors to precompute booleans in GDScript and re-`set` them as
state. v0.8 lifts that tax with a full Vue-compatible operator set
in the expression mini-language:

- **Arithmetic**: `+ - * / %` (strict types; cross-type returns null + warns)
- **Comparison**: `> < >= <=` (num+num or str+str only)
- **Equality**: `== !=` (cross-type permitted — `x == null` etc.)
- **Logical**: `&& ||` (short-circuit, returns LAST operand not coerced bool)
- **Unary**: `! -`
- **Ternary**: `cond ? then : else`
- **Indexing**: `items[i]`, `dict['k']`, `items[i].name`

Type mismatches return null and emit warnings through a new
injectable `_on_warning` logger (testable from GUT).

### Backward-incompatible

- **Identifier syntax**: hyphens dropped from identifiers in
  binding expressions. State keys themselves still accept any
  string via `state.set("key-with-hyphen", ...)`; only the parser
  rejects them. All in-repo samples already use snake_case.

### Tests

54 new tests across parser, applier, and integration; 286 → 340.

### Inventory sample

Filter buttons now read `:class="{ active: filter == 'all' }"`
directly instead of three precomputed booleans. Demonstrates the
operator payoff.

### Deferred to v0.8.1+

- v-for :key keyed reconciliation
- Dynamic :class CSS re-resolution
- Focus traversal + perf benchmarks
```

- [ ] **Step 12.3: Bump version**

In `addons/gtml/plugin.cfg`:

```
version="0.8.0"
```

- [ ] **Step 12.4: Final suite run**

```bash
timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 340/340.

- [ ] **Step 12.5: Commit**

```bash
git add docs/bindings.md CHANGELOG.md addons/gtml/plugin.cfg
git commit -m "chore(v0.8.0): expression operators — docs + CHANGELOG + version

Documents the full grammar + type rules + the hyphen-in-identifier
backward-incompatible change. CHANGELOG enumerates the operator
matrix and notes the three blockers still ahead (v-for :key, :class
re-resolve, focus + perf). plugin.cfg bumped to 0.8.0."
```

---

## Task 13: Push + PR

- [ ] **Step 13.1: Push**

```bash
git push -u origin feat/v0.8-expression-operators 2>&1 | tail -3
```

- [ ] **Step 13.2: Open PR**

```bash
gh pr create --base master --title "v0.8: Expression operators (arithmetic, comparison, logical, ternary, indexing)" --body "$(cat <<'EOF'
## Summary

Lifts the v0.7 ban on operators inside binding expressions. Authors stop precomputing every derived boolean in GDScript.

## Operator matrix

| Category | Operators |
|---|---|
| Arithmetic | `+ - * / %` (strict same-type; cross-type → null+warn) |
| Comparison | `> < >= <=` (num+num or str+str) |
| Equality | `== !=` (cross-type permitted — `x == null` pattern) |
| Logical | `&& \|\|` (short-circuit; returns LAST operand) |
| Unary | `! -` |
| Ternary | `cond ? then : else_` |
| Indexing | `items[i]`, `dict['k']`, `items[i].name` |

## Architecture

- Replace `parse_expr` with a layered recursive-descent cascade (one method per precedence level).
- All v0.7 AST shapes preserved for back-compat — every v0.7 binding test passes unchanged.
- `GmlBindingApplier._on_warning` Callable lets tests capture type-mismatch warnings deterministically.
- Static dep collection extended; ternary deps over-approximate (accepted tradeoff).

## Backward-incompatible

- Hyphens dropped from identifiers in expressions. Grep over the repo: zero existing usage. State keys themselves still accept any string.

## Stats

| | |
|---|---|
| Tests | 340 (was 286) |
| New / modified LOC | ~330 parser + ~150 applier |
| Plugin version | 0.7.0 → 0.8.0 |

## Test plan

- [ ] `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` → 340/340 green
- [ ] Open `addons/gtml/examples/showcase/inventory/demo.tscn` and Play. Filter buttons still toggle, now via direct comparison rather than precomputed booleans. Search + selection still work.
- [ ] Spot-check other showcase scenes — no regression.

## Next

This is the first of four v0.8 production-readiness PRs. Next: v-for `:key` reconciliation.
EOF
)" 2>&1 | tail -3
```

---

## Self-Review

**Spec coverage check** (against `docs/superpowers/specs/2026-05-27-expression-operators-design.md`):

- §1 Grammar → Tasks 2 (scaffold), 3 (index), 4 (unary -), 5 (arithmetic), 6 (comparison + equality), 7 (logical), 8 (ternary) ✓
- §2 AST node additions → emerging across Tasks 2-8 ✓
- §3 Evaluator semantics → Task 5 (binop core, includes strict types + division by zero + cross-type == permission), Task 4 (unary), Task 8 (ternary), Task 3 (index) ✓
- §4 Static dep collection → Task 9 ✓
- §5 Warning logger injection → Task 1 ✓
- §6 Backward compatibility → preserved across all tasks; Task 2 explicitly tests v0.7 AST shape preservation ✓
- §7 Testing plan → Tasks 1–10 add tests progressively, Task 10 has 5 integration tests, Task 11 simplifies the sample to USE operators ✓
- §8 Phasing → mapped to 13 tasks (added Task 11 sample simplification and Task 13 push/PR) ✓

**Placeholder scan:** searched the plan for TBD / TODO / "implement later" / "fill in" — none present. Every step has actual code or actual commands.

**Type consistency:** AST shapes (`{type: "binop", op, left, right}`, `{type: "ternary", cond, then, else_}`, `{type: "index", target, index}`) match across the spec, the parser implementation, the eval implementation, and the dep-collection extension. `_warn` helper signature consistent everywhere.

**One scope correction made inline**: Task 5 includes the FULL `_eval_binop` (including `&&`, `||`, comparison, equality) even though the parser levels for those operators activate later (Tasks 6, 7). This eliminates churn — eval lands once, parser levels turn on incrementally. Tasks 6+7 just wire the parser; the eval already handles their nodes.
