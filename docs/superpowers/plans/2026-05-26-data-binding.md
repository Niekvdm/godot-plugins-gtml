# GTML v0.7 — Data binding + interpolation + list rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Vue-style reactive layer (state, interpolation, directives, list rendering) so dynamic UIs become feasible without per-element GDScript glue.

**Architecture:** Five new modules under `addons/gtml/src/binding/` form a pure-data engine — `GmlState` (per-view reactive store), `GmlBindingExpr` (mini-expression parser), `GmlBindingParser` (scan HTML for directives), `GmlBindingRegistry` (key → bindings reverse-index), `GmlBindingApplier` (eval + write to controls). `GmlView` exposes `state` and `item_clicked`; `GmlRenderer._build_node` gains three hooks for v-if / v-for / post-build registration.

**Tech Stack:** Godot 4.6 GDScript, GUT 9.6 test framework, existing GTML renderer pipeline.

**Reference spec:** `docs/superpowers/specs/2026-05-26-data-binding-design.md`

---

## Pre-flight

- Branch: `feat/v0.7-data-binding` (spec already committed there)
- Working directory: `/data/personal/projects/godot/godot-plugins-gtml`
- Test runner: `timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Test count baseline: **223 tests** (post v0.6 merge)
- Style: **TABS for indentation** (project convention; verify any new file with `cat -A`)
- Commit messages: NO Co-Authored-By line (project strips Claude attribution)

---

## File Structure

**New under `addons/gtml/src/binding/`:**

```
GmlState.gd              # reactive key→value store (~80 LOC)
GmlBindingExpr.gd        # mini-expression parser (~200 LOC)
GmlBindingParser.gd      # text-interp + attr directive classifier (~100 LOC)
GmlBindingRegistry.gd    # per-view {key → [bindings]} reverse index (~80 LOC)
GmlBindingApplier.gd     # eval expressions + write to controls (~250 LOC)
```

**Modified files:**

```
addons/gtml/src/GmlView.gd                # +state property, +item_clicked signal, +registry
addons/gtml/src/html_renderer/GmlRenderer.gd     # v-if / v-for / post-build hooks
addons/gtml/src/html_parser/GmlHtmlParser.gd     # allow : and v- as first char of attr name
```

**New tests:**

```
tests/unit/test_state.gd
tests/unit/test_binding_expr.gd
tests/unit/test_binding_parser.gd
tests/unit/test_binding_registry.gd
tests/unit/test_binding_applier.gd
tests/unit/test_binding_integration.gd
```

**New sample:**

```
addons/gtml/examples/showcase/inventory/{index.html,style.css,demo.gd,demo.tscn}
```

**New docs:** `docs/bindings.md` + edit to `docs/getting-started.md`

---

## Task 1: Scaffold engine modules + GmlState

**Files:**
- Create: `addons/gtml/src/binding/GmlState.gd`
- Create: `addons/gtml/src/binding/GmlBindingExpr.gd` (stub)
- Create: `addons/gtml/src/binding/GmlBindingParser.gd` (stub)
- Create: `addons/gtml/src/binding/GmlBindingRegistry.gd` (stub)
- Create: `addons/gtml/src/binding/GmlBindingApplier.gd` (stub)
- Create: `tests/unit/test_state.gd` (8 tests)

- [ ] **Step 1.1: Write the failing test file**

Create `tests/unit/test_state.gd`:

```gdscript
extends GutTest

## Tests for GmlState — the per-view reactive store.

func test_set_then_get_returns_value() -> void:
	var s := GmlState.new()
	s.set("score", 42)
	assert_eq(s.get("score"), 42)


func test_get_missing_key_returns_null() -> void:
	var s := GmlState.new()
	assert_null(s.get("nope"))


func test_has_returns_true_when_set_false_when_not() -> void:
	var s := GmlState.new()
	assert_false(s.has("x"))
	s.set("x", 1)
	assert_true(s.has("x"))


func test_set_emits_state_changed_with_old_and_new() -> void:
	var s := GmlState.new()
	s.set("score", 10)
	var captured: Array = []
	s.state_changed.connect(func(k, n, o): captured.append([k, n, o]))
	s.set("score", 20)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], ["score", 20, 10])


func test_set_same_value_does_not_emit() -> void:
	var s := GmlState.new()
	s.set("score", 10)
	var captured: Array = []
	s.state_changed.connect(func(k, n, o): captured.append(k))
	s.set("score", 10)
	assert_eq(captured.size(), 0, "setting unchanged value must not emit")


func test_first_set_emits_with_null_old() -> void:
	var s := GmlState.new()
	var captured: Array = []
	s.state_changed.connect(func(k, n, o): captured.append([k, n, o]))
	s.set("new_key", "v")
	assert_eq(captured[0], ["new_key", "v", null])


func test_set_state_batched_emits_per_changed_key() -> void:
	var s := GmlState.new()
	s.set("a", 1)
	var captured: Array = []
	s.state_changed.connect(func(k, _n, _o): captured.append(k))
	s.set_state({"a": 1, "b": 2, "c": 3})
	# 'a' unchanged so no emit; 'b' and 'c' fire
	assert_eq(captured.size(), 2)
	assert_true("b" in captured)
	assert_true("c" in captured)


func test_keys_returns_set_keys() -> void:
	var s := GmlState.new()
	s.set("a", 1)
	s.set("player.health", 100)
	var keys: PackedStringArray = s.keys()
	assert_eq(keys.size(), 2)
	assert_true("a" in keys)
	assert_true("player.health" in keys)
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_state.gd 2>&1 | tail -10
```

Expected: parse errors on `Identifier "GmlState" not declared`.

- [ ] **Step 1.3: Create the directory**

```bash
mkdir -p /data/personal/projects/godot/godot-plugins-gtml/addons/gtml/src/binding
```

- [ ] **Step 1.4: Implement GmlState**

Create `addons/gtml/src/binding/GmlState.gd` (USE TABS):

```gdscript
class_name GmlState
extends RefCounted

## Per-view reactive key→value store.
##
## Storage is flat with dotted keys ("player.health") rather than nested
## dicts so subscription lookup in the registry is O(1) on the exact key
## the view declared a binding against.
##
## Equality check on set() prevents emitting state_changed for no-op writes,
## which would otherwise trigger redundant re-renders.

signal state_changed(key: String, new_value: Variant, old_value: Variant)

var _values: Dictionary = {}


func set(key: String, value: Variant) -> void:
	var has_old: bool = _values.has(key)
	var old_value = _values.get(key)
	if has_old and _values_equal(old_value, value):
		return
	_values[key] = value
	state_changed.emit(key, value, old_value)


func get(key: String) -> Variant:
	return _values.get(key)


func has(key: String) -> bool:
	return _values.has(key)


## Set multiple keys; emits state_changed per CHANGED key (unchanged
## values are silently skipped, same as a single set() call).
func set_state(values: Dictionary) -> void:
	for k in values:
		set(k, values[k])


func keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k in _values.keys():
		out.append(str(k))
	return out


static func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	# Direct equality works for primitives, Dictionaries, and Arrays by
	# value in Godot 4.
	return a == b
```

- [ ] **Step 1.5: Create empty stubs**

Create `addons/gtml/src/binding/GmlBindingExpr.gd`:

```gdscript
class_name GmlBindingExpr
extends RefCounted

## Mini-expression parser for binding directives.
## Populated in Task 2.

static func parse(_source: String) -> Dictionary:
	return {}
```

Create `addons/gtml/src/binding/GmlBindingParser.gd`:

```gdscript
class_name GmlBindingParser
extends RefCounted

## Scans HTML attributes + text nodes; classifies directives.
## Populated in Task 3.

static func find_interpolations(_text: String) -> Array:
	return []
```

Create `addons/gtml/src/binding/GmlBindingRegistry.gd`:

```gdscript
class_name GmlBindingRegistry
extends RefCounted

## Per-view reverse-index of {key → Array[binding]}.
## Populated in Task 3.

func register(_binding: Dictionary) -> void:
	pass


func fire(_key: String) -> void:
	pass


func clear() -> void:
	pass
```

Create `addons/gtml/src/binding/GmlBindingApplier.gd`:

```gdscript
class_name GmlBindingApplier
extends RefCounted

## Evaluates expressions + writes resolved values into controls.
## Populated in Tasks 4–8.

static func eval(_expr: Dictionary, _state: GmlState, _scope: Dictionary) -> Variant:
	return null
```

- [ ] **Step 1.6: Re-import + run tests**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_state.gd 2>&1 | tail -10
```

Expected: 8/8 pass.

- [ ] **Step 1.7: Run full suite**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 231/231 (223 + 8).

- [ ] **Step 1.8: Commit**

```bash
git add addons/gtml/src/binding/ tests/unit/test_state.gd
git commit -m "feat(binding): scaffold engine modules + GmlState

GmlState is the per-view reactive key→value store. Flat Dictionary
keyed by dotted paths (player.health) so the registry's reverse index
can do O(1) lookups on the exact key. set() short-circuits no-op writes
so re-renders only fire when values actually change. set_state batches
multiple keys, emitting per changed key.

Adds four empty stubs (GmlBindingExpr, GmlBindingParser,
GmlBindingRegistry, GmlBindingApplier) populated by later tasks.

8 new tests pin the state API: set/get, missing key, has, change
signal with old+new, no-op skip, first-set null-old, batch set,
keys()."
```

---

## Task 2: Expression parser

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingExpr.gd`
- Create: `tests/unit/test_binding_expr.gd` (14 tests)

The grammar:

```
Expr     := Path | NegPath | ObjectLit | ArrayLit | CallExpr | StringLit
Path     := Ident ('.' Ident)*
NegPath  := '!' Path
ObjectLit:= '{' (Ident ':' Expr (',' Ident ':' Expr)*)? '}'
ArrayLit := '[' (Expr (',' Expr)*)? ']'
CallExpr := Ident '(' (Expr (',' Expr)*)? ')'
StringLit:= "'…'" | '"…"'
Ident    := [a-zA-Z_][\w-]*
```

Return shape:

```
{type: "path",   parts: ["player", "health"]}
{type: "neg",    inner: {...}}
{type: "object", entries: [{key: String, value: Expr}, ...]}
{type: "array",  items: [Expr, ...]}
{type: "call",   name: String, args: [Expr, ...]}
{type: "string", value: String}
{type: "error",  message: String}        # for unparseable input
```

- [ ] **Step 2.1: Write the failing tests**

Create `tests/unit/test_binding_expr.gd`:

```gdscript
extends GutTest

## Tests for GmlBindingExpr — the mini-expression parser.

func test_parse_simple_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("score")
	assert_eq(ast["type"], "path")
	assert_eq(ast["parts"], ["score"])


func test_parse_dotted_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("player.health")
	assert_eq(ast["type"], "path")
	assert_eq(ast["parts"], ["player", "health"])


func test_parse_deep_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a.b.c.d")
	assert_eq(ast["parts"], ["a", "b", "c", "d"])


func test_parse_negation() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("!loading")
	assert_eq(ast["type"], "neg")
	assert_eq(ast["inner"]["type"], "path")
	assert_eq(ast["inner"]["parts"], ["loading"])


func test_parse_negation_dotted_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("!player.invincible")
	assert_eq(ast["type"], "neg")
	assert_eq(ast["inner"]["parts"], ["player", "invincible"])


func test_parse_string_double_quoted() -> void:
	var ast: Dictionary = GmlBindingExpr.parse('"hello"')
	assert_eq(ast["type"], "string")
	assert_eq(ast["value"], "hello")


func test_parse_string_single_quoted() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("'world'")
	assert_eq(ast["type"], "string")
	assert_eq(ast["value"], "world")


func test_parse_object_literal_single_entry() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_active }")
	assert_eq(ast["type"], "object")
	assert_eq(ast["entries"].size(), 1)
	assert_eq(ast["entries"][0]["key"], "active")
	assert_eq(ast["entries"][0]["value"]["type"], "path")
	assert_eq(ast["entries"][0]["value"]["parts"], ["is_active"])


func test_parse_object_literal_multiple_with_negation() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_active, dim: !is_active }")
	assert_eq(ast["entries"].size(), 2)
	assert_eq(ast["entries"][0]["key"], "active")
	assert_eq(ast["entries"][1]["key"], "dim")
	assert_eq(ast["entries"][1]["value"]["type"], "neg")


func test_parse_array_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("['static', dynamic_key]")
	assert_eq(ast["type"], "array")
	assert_eq(ast["items"].size(), 2)
	assert_eq(ast["items"][0]["type"], "string")
	assert_eq(ast["items"][0]["value"], "static")
	assert_eq(ast["items"][1]["type"], "path")


func test_parse_call_no_args() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("handler()")
	assert_eq(ast["type"], "call")
	assert_eq(ast["name"], "handler")
	assert_eq(ast["args"].size(), 0)


func test_parse_call_one_arg() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("select(item)")
	assert_eq(ast["type"], "call")
	assert_eq(ast["name"], "select")
	assert_eq(ast["args"].size(), 1)
	assert_eq(ast["args"][0]["type"], "path")
	assert_eq(ast["args"][0]["parts"], ["item"])


func test_parse_call_multiple_args() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("select(item, index)")
	assert_eq(ast["args"].size(), 2)
	assert_eq(ast["args"][0]["parts"], ["item"])
	assert_eq(ast["args"][1]["parts"], ["index"])


func test_parse_malformed_returns_error() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("{ unclosed")
	assert_eq(ast["type"], "error")
	assert_true("message" in ast)
```

- [ ] **Step 2.2: Run, verify fail**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_expr.gd 2>&1 | tail -8
```

Expected: 14 fails.

- [ ] **Step 2.3: Implement the parser**

Replace `addons/gtml/src/binding/GmlBindingExpr.gd` (TABS):

```gdscript
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
## No arithmetic, comparison, string concat, or ternary. Authors compute
## complex values in GDScript and state.set() them in.
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
```

- [ ] **Step 2.4: Run, verify pass**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_expr.gd 2>&1 | tail -8
```

Expected: 14/14 pass.

- [ ] **Step 2.5: Run full suite (no regressions)**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 245/245 (231 + 14).

- [ ] **Step 2.6: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingExpr.gd tests/unit/test_binding_expr.gd
git commit -m "feat(binding): mini-expression parser for directive values

GmlBindingExpr.parse(source) returns a tagged Dictionary representing
the AST. Grammar:

  Expr     := Path | NegPath | ObjectLit | ArrayLit | CallExpr | StringLit
  Path     := Ident ('.' Ident)*
  NegPath  := '!' Path
  ObjectLit:= '{' (Ident ':' Expr (',' Ident ':' Expr)*)? '}'
  ArrayLit := '[' (Expr (',' Expr)*)? ']'
  CallExpr := Ident '(' (Expr (',' Expr)*)? ')'
  StringLit:= \"'…'\" | '\"…\"'

No arithmetic, comparison, string concat, or ternary. Authors who need
computed values do them in GDScript and state.set() them in. Malformed
input returns {type: 'error', message: ...} so callers can degrade
gracefully.

14 new tests cover simple/dotted/deep paths, negation (with paths),
quoted strings, single+multi-entry object literals (with negation),
array literals, call expressions (no/single/multi args), and the
malformed-input error path."
```

---

## Task 3: Binding parser + registry

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingParser.gd`
- Modify: `addons/gtml/src/binding/GmlBindingRegistry.gd`
- Create: `tests/unit/test_binding_parser.gd` (8 tests)
- Create: `tests/unit/test_binding_registry.gd` (6 tests)

### Binding parser

Responsibilities:
1. **Find text-interpolation spans in a string**: `Hello, {{ name }}!` → `[{type:"literal", value:"Hello, "}, {type:"interp", expr:{type:"path",parts:["name"]}}, {type:"literal", value:"!"}]`
2. **Classify an HTML attribute name** as one of: `text` (regular), `v-bind` (`:foo` or `v-bind:foo`), `v-on` (`@foo` or `v-on:foo`), `v-if`, `v-show`, `v-for`, `v-model`, or `passthrough`. Return both classification and stripped target.

- [ ] **Step 3.1: Write the failing tests for parser**

Create `tests/unit/test_binding_parser.gd`:

```gdscript
extends GutTest

## Tests for GmlBindingParser — scans for {{ }} interpolations and classifies
## attribute names.

# ─── Text interpolation ──────────────────────────────────────────

func test_find_interpolations_none() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("plain text")
	assert_eq(spans.size(), 1)
	assert_eq(spans[0]["type"], "literal")
	assert_eq(spans[0]["value"], "plain text")


func test_find_interpolations_single() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("Hello, {{ name }}!")
	assert_eq(spans.size(), 3)
	assert_eq(spans[0]["type"], "literal")
	assert_eq(spans[0]["value"], "Hello, ")
	assert_eq(spans[1]["type"], "interp")
	assert_eq(spans[1]["expr"]["type"], "path")
	assert_eq(spans[1]["expr"]["parts"], ["name"])
	assert_eq(spans[2]["type"], "literal")
	assert_eq(spans[2]["value"], "!")


func test_find_interpolations_at_start_and_end() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("{{ a }} and {{ b }}")
	assert_eq(spans.size(), 3)
	assert_eq(spans[0]["type"], "interp")
	assert_eq(spans[1]["type"], "literal")
	assert_eq(spans[1]["value"], " and ")
	assert_eq(spans[2]["type"], "interp")


func test_find_interpolations_dotted_path() -> void:
	var spans: Array = GmlBindingParser.find_interpolations("HP: {{ player.health }}/100")
	assert_eq(spans.size(), 3)
	assert_eq(spans[1]["expr"]["parts"], ["player", "health"])


# ─── Attribute classification ────────────────────────────────────

func test_classify_attribute_v_bind_colon_shorthand() -> void:
	var cls: Dictionary = GmlBindingParser.classify_attribute(":disabled")
	assert_eq(cls["kind"], "v-bind")
	assert_eq(cls["target"], "disabled")


func test_classify_attribute_v_on_at_shorthand() -> void:
	var cls: Dictionary = GmlBindingParser.classify_attribute("@click")
	assert_eq(cls["kind"], "v-on")
	assert_eq(cls["target"], "click")


func test_classify_attribute_v_directives() -> void:
	for tag in ["v-if", "v-show", "v-for", "v-model"]:
		var cls: Dictionary = GmlBindingParser.classify_attribute(tag)
		assert_eq(cls["kind"], tag, "expected kind=%s for attr %s" % [tag, tag])


func test_classify_attribute_passthrough() -> void:
	var cls: Dictionary = GmlBindingParser.classify_attribute("class")
	assert_eq(cls["kind"], "passthrough")
	assert_eq(cls["target"], "class")
```

- [ ] **Step 3.2: Implement the parser**

Replace `addons/gtml/src/binding/GmlBindingParser.gd`:

```gdscript
class_name GmlBindingParser
extends RefCounted

## Scans HTML text + attributes for binding markers.
##
## Two responsibilities:
##   1. find_interpolations(text) splits a text string into a sequence of
##      {literal, value} and {interp, expr} spans.
##   2. classify_attribute(name) tags an attribute name as one of:
##      v-bind | v-on | v-if | v-show | v-for | v-model | passthrough
##      plus the "target" (the part after the prefix).


## Returns Array of spans:
##   {type: "literal", value: String}
##   {type: "interp",  expr: Dictionary (from GmlBindingExpr.parse)}
static func find_interpolations(text: String) -> Array:
	var out: Array = []
	var i: int = 0
	var n: int = text.length()
	var literal_start: int = 0
	while i < n - 1:
		if text[i] == "{" and text[i + 1] == "{":
			# Flush preceding literal
			if i > literal_start:
				out.append({"type": "literal", "value": text.substr(literal_start, i - literal_start)})
			# Find closing }}
			var close: int = text.find("}}", i + 2)
			if close < 0:
				# Unterminated — treat rest as literal
				out.append({"type": "literal", "value": text.substr(i)})
				return out
			var src: String = text.substr(i + 2, close - i - 2).strip_edges()
			var expr: Dictionary = GmlBindingExpr.parse(src)
			out.append({"type": "interp", "expr": expr})
			i = close + 2
			literal_start = i
		else:
			i += 1
	# Trailing literal
	if literal_start < n:
		out.append({"type": "literal", "value": text.substr(literal_start)})
	# If nothing matched and we have no spans yet, return the whole string as a literal
	if out.is_empty():
		out.append({"type": "literal", "value": text})
	return out


## Returns {kind: String, target: String}.
## kind ∈ {"v-bind", "v-on", "v-if", "v-show", "v-for", "v-model", "passthrough"}.
## target is the part after the prefix (the attr being bound, or the event name).
static func classify_attribute(name: String) -> Dictionary:
	# Shorthand : for v-bind
	if name.begins_with(":"):
		return {"kind": "v-bind", "target": name.substr(1)}
	# Shorthand @ for v-on
	if name.begins_with("@"):
		return {"kind": "v-on", "target": name.substr(1)}
	# Full forms
	if name.begins_with("v-bind:"):
		return {"kind": "v-bind", "target": name.substr(7)}
	if name.begins_with("v-on:"):
		return {"kind": "v-on", "target": name.substr(5)}
	if name == "v-if" or name == "v-show" or name == "v-for" or name == "v-model":
		return {"kind": name, "target": ""}
	return {"kind": "passthrough", "target": name}
```

- [ ] **Step 3.3: Write tests for registry**

Create `tests/unit/test_binding_registry.gd`:

```gdscript
extends GutTest

## Tests for GmlBindingRegistry — per-view {key → Array[binding]} reverse index.

func test_register_then_fire_invokes_applier() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	var binding := {
		"deps": ["score"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	}
	r.register(binding)
	r.fire("score")
	assert_eq(fired.size(), 1)


func test_fire_unrelated_key_does_not_invoke() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["score"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.fire("name")
	assert_eq(fired.size(), 0)


func test_multiple_deps_fire_on_any_key() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["a", "b"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.fire("a")
	r.fire("b")
	assert_eq(fired.size(), 2)


func test_clear_drops_all_bindings() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["a"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.clear()
	r.fire("a")
	assert_eq(fired.size(), 0)


func test_pruned_when_control_ref_freed() -> void:
	var r := GmlBindingRegistry.new()
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var ref := weakref(ctrl)
	r.register({
		"deps": ["x"],
		"apply": func(): pass,
		"control_ref": ref,
	})
	# Free the control
	ctrl.queue_free()
	await get_tree().process_frame
	r.fire("x")
	# After firing, the binding should have been pruned (verify via count)
	assert_eq(r.binding_count(), 0, "freed-control binding should be pruned on fire")


func test_fire_batched_runs_each_binding_once() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["a", "b"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	# Two keys touched, but the binding depends on both — should only fire once.
	r.fire_batch(["a", "b"])
	assert_eq(fired.size(), 1)
```

- [ ] **Step 3.4: Implement the registry**

Replace `addons/gtml/src/binding/GmlBindingRegistry.gd`:

```gdscript
class_name GmlBindingRegistry
extends RefCounted

## Per-view {key → Array[binding]} reverse index for reactive bindings.
##
## A binding is a Dictionary:
##   {
##     deps: Array[String]   # state keys this binding reads
##     apply: Callable       # invoked when any dep changes; takes no args
##     control_ref: WeakRef  # null OR weakref to the Control; pruned when dead
##   }
##
## Each binding registers once; the registry mirrors it into the reverse
## index for every dep. On fire(key), all bindings touching that key are
## invoked once. Bindings whose control_ref has been freed are pruned
## lazily in the same pass.

var _by_key: Dictionary = {}   # key → Array[binding]
var _all: Array = []           # bookkeeping for clear() and binding_count()


func register(binding: Dictionary) -> void:
	_all.append(binding)
	var deps: Array = binding.get("deps", [])
	for dep in deps:
		if not _by_key.has(dep):
			_by_key[dep] = []
		_by_key[dep].append(binding)


func fire(key: String) -> void:
	if not _by_key.has(key):
		return
	var bindings: Array = _by_key[key]
	var still_valid: Array = []
	for b in bindings:
		if _is_alive(b):
			b["apply"].call()
			still_valid.append(b)
		# else: drop
	# Replace the bucket with the surviving bindings
	_by_key[key] = still_valid
	# Also prune the all-list if anything was dropped
	if still_valid.size() != bindings.size():
		_all = _all.filter(_is_alive)


## Fire many keys at once; each binding affected fires AT MOST ONCE even
## when it depends on multiple of the keys.
func fire_batch(keys: Array) -> void:
	var seen: Dictionary = {}
	for k in keys:
		if not _by_key.has(k):
			continue
		for b in _by_key[k]:
			var bid: int = b.get_instance_id() if b is Object else hash(b)
			# Dictionaries don't have get_instance_id; hash the binding ref via its 'apply' Callable.
			var key_id = b["apply"]
			if seen.has(key_id):
				continue
			seen[key_id] = true
			if _is_alive(b):
				b["apply"].call()
	# Prune across all keys at the end
	for k in _by_key.keys():
		_by_key[k] = (_by_key[k] as Array).filter(_is_alive)
	_all = _all.filter(_is_alive)


func clear() -> void:
	_by_key.clear()
	_all.clear()


func binding_count() -> int:
	return _all.size()


static func _is_alive(binding: Dictionary) -> bool:
	var ref = binding.get("control_ref")
	if ref == null:
		return true
	if not (ref is WeakRef):
		return true
	return ref.get_ref() != null
```

- [ ] **Step 3.5: Run new test files**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_parser.gd 2>&1 | tail -8
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_registry.gd 2>&1 | tail -8
```

Expected: parser 8/8 pass, registry 6/6 pass.

- [ ] **Step 3.6: Run full suite**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 259/259 (245 + 14).

- [ ] **Step 3.7: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingParser.gd addons/gtml/src/binding/GmlBindingRegistry.gd \
        tests/unit/test_binding_parser.gd tests/unit/test_binding_registry.gd
git commit -m "feat(binding): parser scanner + registry reverse index

GmlBindingParser provides two pure helpers:
  - find_interpolations(text): split a string into literal/interp spans
    around {{ ... }} markers; each interp carries the parsed Expr AST
  - classify_attribute(name): tag attr name as v-bind/v-on/v-if/v-show/
    v-for/v-model/passthrough, with the target suffix extracted

GmlBindingRegistry maintains the per-view {key → Array[binding]} reverse
index. Each binding stores its dependency keys, an apply Callable, and
an optional WeakRef to the Control. fire(key) invokes all bindings
touching that key and prunes any whose control was freed. fire_batch
dedupes so a binding reading multiple changed keys fires once.

14 new tests cover both modules including the freed-control-pruning
path and batched-dedup semantics."
```

---

## Task 4: Applier — text interpolation + simple attributes

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Create: `tests/unit/test_binding_applier.gd` (initial 6 tests)

The applier owns the "given an expression AST and a state, write the result to a control" responsibility. Task 4 covers:
- `eval(expr, state, scope)` for path / neg / string types (object/array/call come in Task 5)
- `register_text_interpolation(label, spans, registry, state)` — wires a Label whose `.text` reflects `{{...}}` substitutions
- `register_attr_binding(control, target_attr, expr_ast, registry, state)` — wires `:disabled`, `:value`, `:src`, `:href` to state keys

- [ ] **Step 4.1: Write the failing tests**

Create `tests/unit/test_binding_applier.gd`:

```gdscript
extends GutTest

## Tests for GmlBindingApplier — evaluates AST + writes to controls.
##
## Helper builds a state + registry + label + invokes register_text_interpolation,
## then exercises state.set() and asserts label.text changes.


func _state(values: Dictionary = {}) -> GmlState:
	var s := GmlState.new()
	for k in values:
		s.set(k, values[k])
	return s


# ─── eval() basics ───────────────────────────────────────────────

func test_eval_path_returns_state_value() -> void:
	var s := _state({"score": 42})
	var ast: Dictionary = GmlBindingExpr.parse("score")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), 42)


func test_eval_dotted_path_reads_flat_key() -> void:
	var s := _state({"player.health": 85})
	var ast: Dictionary = GmlBindingExpr.parse("player.health")
	assert_eq(GmlBindingApplier.eval(ast, s, {}), 85)


func test_eval_path_falls_back_to_scope_first() -> void:
	# Loop scope shadows global state for the duration of v-for.
	var s := _state({"item": "global_value"})
	var ast: Dictionary = GmlBindingExpr.parse("item")
	var scope := {"item": "loop_value"}
	assert_eq(GmlBindingApplier.eval(ast, s, scope), "loop_value")


func test_eval_negation_inverts_truthy() -> void:
	var s := _state({"loading": false})
	var ast: Dictionary = GmlBindingExpr.parse("!loading")
	assert_true(GmlBindingApplier.eval(ast, s, {}))


func test_eval_string_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("'hello'")
	assert_eq(GmlBindingApplier.eval(ast, _state(), {}), "hello")


# ─── Text interpolation end-to-end ───────────────────────────────

func test_register_text_interpolation_initial_apply_writes_label() -> void:
	var s := _state({"name": "Ada"})
	var r := GmlBindingRegistry.new()
	var label := Label.new()
	label.text = "{{ name }}"
	add_child_autofree(label)
	var spans: Array = GmlBindingParser.find_interpolations("Hello, {{ name }}!")
	GmlBindingApplier.register_text_interpolation(label, spans, r, s)
	# After registration, initial apply runs synchronously
	assert_eq(label.text, "Hello, Ada!")


func test_register_text_interpolation_updates_on_state_change() -> void:
	var s := _state({"name": "Ada"})
	var r := GmlBindingRegistry.new()
	var label := Label.new()
	add_child_autofree(label)
	var spans: Array = GmlBindingParser.find_interpolations("Hello, {{ name }}!")
	GmlBindingApplier.register_text_interpolation(label, spans, r, s)
	# Wire state changes to the registry
	s.state_changed.connect(func(k, _n, _o): r.fire(k))
	s.set("name", "Bob")
	assert_eq(label.text, "Hello, Bob!")


# ─── Attribute binding ──────────────────────────────────────────

func test_register_attr_binding_disabled_writes_bool() -> void:
	var s := _state({"locked": true})
	var r := GmlBindingRegistry.new()
	var btn := Button.new()
	add_child_autofree(btn)
	var ast: Dictionary = GmlBindingExpr.parse("locked")
	GmlBindingApplier.register_attr_binding(btn, "disabled", ast, r, s)
	assert_true(btn.disabled)
	s.state_changed.connect(func(k, _n, _o): r.fire(k))
	s.set("locked", false)
	assert_false(btn.disabled)


func test_register_attr_binding_value_writes_text() -> void:
	var s := _state({"name": "Ada"})
	var r := GmlBindingRegistry.new()
	var line := LineEdit.new()
	add_child_autofree(line)
	var ast: Dictionary = GmlBindingExpr.parse("name")
	GmlBindingApplier.register_attr_binding(line, "value", ast, r, s)
	assert_eq(line.text, "Ada")


func test_register_attr_binding_unknown_target_is_noop() -> void:
	# An unknown :foo target should not crash; just no-op.
	var s := _state({"x": 1})
	var r := GmlBindingRegistry.new()
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var ast: Dictionary = GmlBindingExpr.parse("x")
	GmlBindingApplier.register_attr_binding(ctrl, "unrecognized_attr", ast, r, s)
	# Pass criterion: didn't crash
	assert_true(true)
```

- [ ] **Step 4.2: Implement the applier (Task 4 surface)**

Replace `addons/gtml/src/binding/GmlBindingApplier.gd`:

```gdscript
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
		# Walk remaining parts as Dictionary lookups (item.name etc.)
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
## non-null objects, true, non-empty containers. Empty array / dict / string
## / 0 / null / false are falsy.
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
	var ref := weakref(label)
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
	# Initial paint
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
	var ref := weakref(control)
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
```

- [ ] **Step 4.3: Run, verify pass**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_applier.gd 2>&1 | tail -8
```

Expected: 10/10 pass.

- [ ] **Step 4.4: Run full suite**

Expected: 269/269 (259 + 10).

- [ ] **Step 4.5: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): applier eval() + text-interp + simple :attr bindings

GmlBindingApplier.eval(expr, state, scope) resolves path / neg / string
AST nodes against the view's state and the current scope frame. Scope
takes precedence over state on key collisions (this is what makes
{{ item.name }} read the loop variable rather than a global).

register_text_interpolation(label, spans, registry, state) installs a
binding so a Label.text reflects 'literal {{ expr }} literal' spans;
collects deps via _collect_expr_deps so the registry fires only when
relevant keys change.

register_attr_binding(control, target, expr, registry, state) wires
the four simple :attr targets (:disabled, :value, :src, :href). Unknown
targets warn via push_warning so author typos are visible.

Object / array / call eval is stubbed (returns null) — Task 5 + Task 8
fill those branches.

10 new tests: eval basics (path, dotted, scope shadowing, negation,
string), text interp (initial + update), :attr (disabled, value,
unknown-noop)."
```

---

## Task 5: Applier — :class object/array + array support in eval

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `tests/unit/test_binding_applier.gd` (append region)

`:class` is the most common case for object/array literal syntax. Vue's:
- `:class="{ active: is_active }"` — toggle "active" class based on is_active key
- `:class="['static', dyn_key]"` — concatenate literal + state-driven names

In GTML, classes participate in CSS selector matching at resolve time. The CSS is already parsed and the styles are already computed at this stage. So `:class` updates need to:
1. Read the resolved style for the new class set from the cached `styles` Dict the resolver returned
2. Re-apply that style to the control

That's complex enough that for v0.7 we simplify: `:class` only manipulates **the Control's class metadata + theme stylebox swaps for known dynamic classes**. The current renderer applies all styles at build time; dynamic class addition won't pull in new styles unless we re-resolve.

Pragmatic scope: `:class` adds/removes class names in the Control's class meta (so downstream code that reads classes sees the update) AND emits a `state_changed` re-resolve hook for the view. Full reactive style rebinding is out of scope for v0.7; doc the limitation.

- [ ] **Step 5.1: Write the failing tests**

Append to `tests/unit/test_binding_applier.gd`:

```gdscript
# ─── Object/array eval (Task 5) ──────────────────────────────────

func test_eval_object_returns_filtered_keys_by_truthy_values() -> void:
	var s := _state({"is_active": true, "is_dim": false})
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_active, dim: is_dim }")
	var result = GmlBindingApplier.eval(ast, s, {})
	# Object eval returns the keys whose values are truthy, as PackedStringArray
	assert_true(result is PackedStringArray)
	assert_eq(result.size(), 1)
	assert_eq(result[0], "active")


func test_eval_object_with_negation() -> void:
	var s := _state({"is_loading": false})
	var ast: Dictionary = GmlBindingExpr.parse("{ ready: !is_loading }")
	var result = GmlBindingApplier.eval(ast, s, {})
	assert_eq(result.size(), 1)
	assert_eq(result[0], "ready")


func test_eval_array_returns_concatenated_strings() -> void:
	var s := _state({"dyn": "highlighted"})
	var ast: Dictionary = GmlBindingExpr.parse("['static', dyn]")
	var result = GmlBindingApplier.eval(ast, s, {})
	assert_true(result is PackedStringArray)
	assert_eq(result.size(), 2)
	assert_eq(result[0], "static")
	assert_eq(result[1], "highlighted")


# ─── :class registration ─────────────────────────────────────────

func test_register_class_binding_writes_meta_classes() -> void:
	# Verify :class updates a Control's "dynamic_classes" meta which the
	# view exposes via get_dynamic_classes(). Initial state + update.
	var s := _state({"is_on": true})
	var r := GmlBindingRegistry.new()
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_on }")
	GmlBindingApplier.register_class_binding(ctrl, ast, r, s)
	var classes: PackedStringArray = ctrl.get_meta("dynamic_classes", PackedStringArray())
	assert_eq(classes.size(), 1)
	assert_eq(classes[0], "active")

	s.state_changed.connect(func(k, _n, _o): r.fire(k))
	s.set("is_on", false)
	classes = ctrl.get_meta("dynamic_classes", PackedStringArray())
	assert_eq(classes.size(), 0)
```

- [ ] **Step 5.2: Extend the applier**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, replace the `eval` function's `match` body to handle object/array (call still stubbed):

```gdscript
static func eval(expr: Dictionary, state: GmlState, scope: Dictionary) -> Variant:
	match expr.get("type", ""):
		"path":
			return _eval_path(expr["parts"], state, scope)
		"neg":
			var inner = eval(expr["inner"], state, scope)
			return not _truthy(inner)
		"string":
			return expr["value"]
		"object":
			return _eval_object(expr["entries"], state, scope)
		"array":
			return _eval_array(expr["items"], state, scope)
		"call":
			# Implemented in Task 8
			return null
		_:
			return null
```

Add the helpers below `_truthy`:

```gdscript
## Object literal evaluation returns the KEYS whose evaluated VALUES are
## truthy. Used by :class for the { active: is_active } toggle syntax.
static func _eval_object(entries: Array, state: GmlState, scope: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e in entries:
		if _truthy(eval(e["value"], state, scope)):
			out.append(e["key"])
	return out


## Array literal evaluation returns each element coerced to String.
## Path elements pull from state; string literals pass through.
static func _eval_array(items: Array, state: GmlState, scope: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for item in items:
		var v = eval(item, state, scope)
		if v != null:
			out.append(str(v))
	return out
```

Add `register_class_binding`:

```gdscript
## Wire :class="..." to a Control. The result is stored on the control's
## "dynamic_classes" meta as a PackedStringArray. The view's renderer (and
## any downstream code) can read this meta to know which dynamic classes
## are currently active on this element.
##
## Note: v0.7 does NOT re-resolve CSS rules when dynamic classes change.
## Dynamic class addition affects only the meta; the Control's existing
## stylebox is not updated. Static styling (declared on classes present
## at build time) still works. Document the limitation in docs/bindings.md.
static func register_class_binding(control: Control, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState) -> void:
	var ref := weakref(control)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		var resolved = eval(expr, state, {})
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
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	})
	apply.call()
```

- [ ] **Step 5.3: Run, verify pass**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_applier.gd 2>&1 | tail -8
```

Expected: 14/14 pass (10 prior + 4 new).

- [ ] **Step 5.4: Full suite**

Expected: 273/273.

- [ ] **Step 5.5: Commit**

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd tests/unit/test_binding_applier.gd
git commit -m "feat(binding): :class object/array syntax + applier extension

eval() now handles object literals (returns PackedStringArray of keys
whose values are truthy) and array literals (concatenated string list).

register_class_binding wires :class=\"{ ... }\" or :class=\"[ ... ]\"
expressions; the result is stored on the control's dynamic_classes
meta as a PackedStringArray. Downstream code can read this meta to
inspect the live class set.

Limitation documented inline: v0.7 does not re-resolve CSS rules when
dynamic classes change. Static styling (declared on classes present at
build time) still works; full reactive style rebinding deferred. The
inventory sample uses precomputed boolean state keys to drive class
toggles, which lets us reach all the styling we need without
re-resolution.

4 new tests cover object/array eval and the meta-write registration."
```

---

## Task 6: v-if + v-show + renderer integration

**Files:**
- Modify: `addons/gtml/src/html_renderer/GmlRenderer.gd`
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `addons/gtml/src/html_parser/GmlHtmlParser.gd`
- Modify: `tests/unit/test_binding_applier.gd`
- Create: `tests/unit/test_binding_integration.gd` (initial tests)

This task wires:
1. HTML parser accepts `:`, `@`, `v-` as first attr-name characters (currently allows `@`)
2. Renderer checks `v-if` before dispatching to element builders; returns null if falsy
3. Renderer checks `v-show` after building the control; sets `visible` initially + registers binding
4. Renderer integration: gets the binding registry from `GmlView` via ctx

- [ ] **Step 6.1: Extend HTML parser to allow `:` first-char**

In `addons/gtml/src/html_parser/GmlHtmlParser.gd`, find `_parse_attribute_name` (around line 195). Current code already allows `@` as first char. Add `:` and verify `v-` works (the `v` is an identifier char + the `-` is allowed mid-name, so `v-if` should already parse).

Locate the function:

```gdscript
func _parse_attribute_name() -> String:
	var start := _pos

	# Allow @ as first character for @click etc.
	if _peek() == "@":
		_advance()

	while _pos < _length:
		var ch := _peek()
		# Allow letters, digits, hyphens, underscores, colons (for SVG attributes like x1, y1, etc.)
		if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch == ":" or ch.is_valid_int():
			_advance()
		else:
			break

	return _html.substr(start, _pos - start)
```

Replace the `# Allow @` block with:

```gdscript
	# Allow @ (event shorthand) and : (v-bind shorthand) as first char.
	if _peek() == "@" or _peek() == ":":
		_advance()
```

`v-if` etc. already parse because `v` starts identifier chars.

- [ ] **Step 6.2: Write parser regression test**

Append to `tests/unit/test_parser_unit.gd` (TABS):

```gdscript
func test_parser_accepts_colon_prefix_attribute() -> void:
	var dom = GmlHtmlParserScript.new().parse('<div :class="x">y</div>')
	assert_eq(dom.attrs.get(":class", ""), "x")


func test_parser_accepts_v_directive_attribute() -> void:
	var dom = GmlHtmlParserScript.new().parse('<div v-if="cond"></div>')
	assert_eq(dom.attrs.get("v-if", ""), "cond")
```

Run + commit incrementally (this is a small parser change):

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 275/275 (273 + 2).

- [ ] **Step 6.3: Add v-if/v-show registration to applier**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, add:

```gdscript
## Wire v-show. Initial visibility set from expr; subsequent state
## changes flip control.visible. Does NOT remove the control from the
## tree (that's v-if's job at the renderer level).
static func register_v_show(control: Control, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState) -> void:
	var ref := weakref(control)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		ctl.visible = _truthy(eval(expr, state, {}))
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	})
	apply.call()


## Static helper used by the renderer's v-if check at build time.
## Returns whether the v-if expression is currently truthy.
static func eval_v_if(expr_source: String, state: GmlState, scope: Dictionary) -> bool:
	var ast: Dictionary = GmlBindingExpr.parse(expr_source)
	return _truthy(eval(ast, state, scope))
```

- [ ] **Step 6.4: Wire renderer hooks (v-if + v-show + post-build binding registration)**

Modify `addons/gtml/src/html_renderer/GmlRenderer.gd`. At the top, add:

```gdscript
const GmlBindingParserScript = preload("res://addons/gtml/src/binding/GmlBindingParser.gd")
const GmlBindingApplierScript = preload("res://addons/gtml/src/binding/GmlBindingApplier.gd")
const GmlBindingExprScript = preload("res://addons/gtml/src/binding/GmlBindingExpr.gd")
const GmlBindingRegistryScript = preload("res://addons/gtml/src/binding/GmlBindingRegistry.gd")
```

Find `_build_node(node)`. At the very top, before any existing logic, add v-if check:

```gdscript
func _build_node(node) -> Control:
	if node == null:
		return null
	if node.is_text_node:
		return _build_text_node(node)

	# v-if: omit element entirely when falsy. The element is NOT registered as
	# a binding because there's no control to update; if state changes flip
	# v-if, the parent must rebuild. Re-evaluation on state change is handled
	# by a sentinel binding the parent registers on its own behalf.
	if node.attrs.has("v-if"):
		var v_if_src: String = node.attrs["v-if"]
		if not GmlBindingApplierScript.eval_v_if(v_if_src, _gml_view.state, {}):
			return null

	# ... existing dispatch ...
```

After the existing `_dispatch(node, ctx)` call and the existing wiring (style application etc.), add post-build registration. Find the section after `GmlTransitionSetup.setup(...)` (near the end of `_build_node`); after that call, add:

```gdscript
	# Post-build: register Vue-style bindings on the resolved control.
	_register_bindings_for_node(node, control)

	return control
```

Add the `_register_bindings_for_node` helper at the end of the file:

```gdscript
## Walk the node's attributes + text children and register bindings on
## the resolved control. Handles :attr, v-bind:attr, v-show, and text
## interpolation in immediate text children. v-if was handled at dispatch
## time; v-for + v-model + @event(args) live in later tasks.
func _register_bindings_for_node(node, control: Control) -> void:
	if _gml_view == null or control == null:
		return
	var registry: GmlBindingRegistry = _gml_view._binding_registry
	if registry == null:
		return
	var state: GmlState = _gml_view.state
	if state == null:
		return

	for attr_name in node.attrs:
		var cls: Dictionary = GmlBindingParserScript.classify_attribute(attr_name)
		match cls["kind"]:
			"v-bind":
				var expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				if cls["target"] == "class":
					GmlBindingApplierScript.register_class_binding(control, expr, registry, state)
				else:
					GmlBindingApplierScript.register_attr_binding(control, cls["target"], expr, registry, state)
			"v-show":
				var v_show_expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				GmlBindingApplierScript.register_v_show(control, v_show_expr, registry, state)
			# v-if handled at dispatch (above), v-for/v-model/v-on(args) come later
			_:
				pass

	# Text interpolation on direct text children — only meaningful for
	# elements whose body is a single text node (e.g. <span>{{ name }}</span>).
	# Multi-child elements have their text children built individually by
	# the element builder; if any of those text children has {{ }}, the
	# child build path also routes through here.
	if control is Label and node.children.size() > 0:
		var combined: String = ""
		for child in node.children:
			if child.is_text_node:
				combined += child.text
		if "{{" in combined:
			var spans: Array = GmlBindingParserScript.find_interpolations(combined)
			GmlBindingApplierScript.register_text_interpolation(control as Label, spans, registry, state)
```

- [ ] **Step 6.5: Add `_binding_registry` to GmlView**

In `addons/gtml/src/GmlView.gd`, add near other state vars:

```gdscript
const GmlStateScript = preload("res://addons/gtml/src/binding/GmlState.gd")
const GmlBindingRegistryScript = preload("res://addons/gtml/src/binding/GmlBindingRegistry.gd")
```

Add fields:

```gdscript
var state: GmlState
var _binding_registry: GmlBindingRegistry
```

In `_init`, instantiate them:

```gdscript
func _init() -> void:
	state = GmlStateScript.new()
	_binding_registry = GmlBindingRegistryScript.new()
	# Wire state changes through the registry
	state.state_changed.connect(func(k, _n, _o): _binding_registry.fire(k))
```

In `_rebuild()`, clear the registry before walking (so re-builds don't stack stale bindings):

```gdscript
func _rebuild() -> void:
	_binding_registry.clear()
	# ... existing rebuild logic ...
```

- [ ] **Step 6.6: Write integration tests**

Create `tests/unit/test_binding_integration.gd`:

```gdscript
extends GutTest

## End-to-end tests: instantiate GmlView, set state, verify DOM reacts.

const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")


func _build_view(html: String, css: String = "") -> GmlView:
	var dir := "res://tests/snapshots/.actual/binding_fixture"
	var html_path := dir + "/index.html"
	var css_path := dir + "/style.css"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fh := FileAccess.open(html_path, FileAccess.WRITE)
	fh.store_string(html)
	fh.close()
	var fc := FileAccess.open(css_path, FileAccess.WRITE)
	fc.store_string(css)
	fc.close()

	var view: GmlView = GmlViewScript.new()
	view.html_path = html_path
	view.css_path = css_path
	view.size = Vector2(400, 200)
	add_child_autofree(view)
	return view


func _find_first_label(node: Node) -> Label:
	if node is Label:
		return node
	for c in node.get_children():
		var l = _find_first_label(c)
		if l != null:
			return l
	return null


func test_text_interpolation_updates_dom_on_set() -> void:
	var view := _build_view('<span>Hello, {{ name }}!</span>')
	view.state.set("name", "Ada")
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label)
	assert_eq(label.text, "Hello, Ada!")

	view.state.set("name", "Bob")
	await get_tree().process_frame
	assert_eq(label.text, "Hello, Bob!")


func test_v_if_omits_subtree_when_falsy() -> void:
	# Empty initial state → v-if="show" reads null → falsy → element omitted.
	var view := _build_view('<div><span v-if="show">shown</span></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_null(label, "v-if=false should omit the span entirely")


func test_v_show_initially_hides_then_shows() -> void:
	var view := _build_view('<div><span v-show="visible">x</span></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_label(view)
	assert_not_null(label, "v-show keeps element in tree")
	assert_false(label.visible)
	view.state.set("visible", true)
	await get_tree().process_frame
	assert_true(label.visible)
```

- [ ] **Step 6.7: Run + commit**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 278/278 (275 + 3 integration).

```bash
git add addons/gtml/src/html_parser/GmlHtmlParser.gd \
        addons/gtml/src/html_renderer/GmlRenderer.gd \
        addons/gtml/src/GmlView.gd \
        addons/gtml/src/binding/GmlBindingApplier.gd \
        tests/unit/test_parser_unit.gd \
        tests/unit/test_binding_integration.gd
git commit -m "feat(binding): v-if + v-show + renderer integration

HTML parser now accepts ':' as a first character of attribute names so
':class', ':disabled', etc. parse. ('@' already worked; 'v-' worked
implicitly because 'v' is an identifier char.)

GmlRenderer._build_node gains two hooks:
  - Before dispatch: v-if check. Falsy → return null and skip the
    subtree.
  - After dispatch: _register_bindings_for_node walks attrs + text
    children and routes each binding through the parser+applier
    (currently :attr, :class, v-show, text {{ }} interpolation).

GmlView gets a state: GmlState field and _binding_registry. _init()
constructs both and wires state.state_changed → registry.fire. _rebuild
clears the registry before walking so live-reloads don't accumulate
stale bindings.

3 end-to-end integration tests confirm: text interpolation updates the
Label, v-if removes the element from the tree, v-show keeps it but
toggles visible."
```

---

## Task 7: v-for list rendering

**Files:**
- Modify: `addons/gtml/src/html_renderer/GmlRenderer.gd`
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `tests/unit/test_binding_integration.gd`

`v-for` is the most complex directive. Strategy:
1. Renderer detects `v-for` before dispatch
2. Parses the expression `item in items` (or `item, idx in items`) into `{loop_var, index_var, array_key}`
3. Reads `state.get(array_key)`; for each element, clones the node (recursively) without the `v-for` attr, builds it with scope = `{loop_var: item, index_var: i}`
4. Registers a binding that on `state.set(array_key, new_array)` tears down all generated children and rebuilds

The scope propagates DOWN: bindings inside the v-for subtree need to see `item` when they evaluate paths. Easiest approach: stash the scope on the DOM node via meta so child binding registration reads it.

- [ ] **Step 7.1: Write the failing tests**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript
func test_v_for_renders_one_child_per_array_element() -> void:
	var view := _build_view('<ul><li v-for="item in items">{{ item.name }}</li></ul>')
	view.state.set("items", [{"name": "Sword"}, {"name": "Potion"}])
	await get_tree().process_frame
	await get_tree().process_frame
	# Find all labels and collect their text
	var texts: Array = []
	_collect_label_texts(view, texts)
	assert_true("Sword" in texts, "Sword not found in %s" % str(texts))
	assert_true("Potion" in texts, "Potion not found in %s" % str(texts))


func test_v_for_rebuilds_on_array_change() -> void:
	var view := _build_view('<ul><li v-for="item in items">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b"])
	await get_tree().process_frame
	await get_tree().process_frame
	var texts1: Array = []
	_collect_label_texts(view, texts1)
	assert_true("a" in texts1 and "b" in texts1)

	view.state.set("items", ["x", "y", "z"])
	await get_tree().process_frame
	var texts2: Array = []
	_collect_label_texts(view, texts2)
	assert_true("x" in texts2 and "y" in texts2 and "z" in texts2)
	assert_false("a" in texts2, "old item 'a' should be torn down")


func test_v_for_indexed_form_exposes_index() -> void:
	var view := _build_view('<ul><li v-for="item, i in items">{{ i }}: {{ item }}</li></ul>')
	view.state.set("items", ["alpha", "beta"])
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array = []
	_collect_label_texts(view, texts)
	assert_true("0: alpha" in texts)
	assert_true("1: beta" in texts)


func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_label_texts(c, out)
```

- [ ] **Step 7.2: Add v-for parser helper to applier**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, add:

```gdscript
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
```

- [ ] **Step 7.3: Wire v-for in renderer**

In `addons/gtml/src/html_renderer/GmlRenderer.gd`, modify `_build_node` so the v-for check runs BEFORE v-if (an array-element-specific v-if is unusual but possible):

```gdscript
func _build_node(node) -> Control:
	if node == null:
		return null
	if node.is_text_node:
		return _build_text_node(node)

	# v-for: take over, build N children and register a list binding.
	# Returns null at this level — children are added directly to the
	# parent during the list-build callback via the scope-aware build path.
	if node.attrs.has("v-for"):
		return _build_v_for(node)

	# v-if: omit element entirely when falsy.
	if node.attrs.has("v-if"):
		var v_if_src: String = node.attrs["v-if"]
		var scope: Dictionary = node.get_meta("_binding_scope", {})
		if not GmlBindingApplierScript.eval_v_if(v_if_src, _gml_view.state, scope):
			return null

	# ... rest of existing build ...
```

After `_register_bindings_for_node`, add:

```gdscript
## Build a v-for'd element. Returns a Container that becomes the parent
## of N clones. On state change to the bound array, the container's
## children are torn down and rebuilt.
func _build_v_for(node) -> Control:
	var v_for_src: String = node.attrs["v-for"]
	var spec = GmlBindingApplierScript.parse_v_for(v_for_src)
	if spec == null:
		push_warning("GmlRenderer: invalid v-for expression: %s" % v_for_src)
		return null

	# We use a VBoxContainer as the host so list items stack visually by
	# default. Authors who want horizontal lists can wrap the v-for in
	# their own flex parent — the v-for host itself is a thin container.
	var host := VBoxContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var state: GmlState = _gml_view.state
	var registry: GmlBindingRegistry = _gml_view._binding_registry
	var renderer_ref := weakref(self)
	var host_ref := weakref(host)
	var node_ref: WeakRef = weakref(node)

	var rebuild := func():
		var h = host_ref.get_ref()
		var n = node_ref.get_ref()
		var r = renderer_ref.get_ref()
		if h == null or n == null or r == null:
			return
		# Tear down existing children
		for child in h.get_children():
			h.remove_child(child)
			child.queue_free()
		# Build fresh
		var array = state.get(spec["array_key"])
		if array == null:
			return
		if not (array is Array):
			push_warning("GmlRenderer: v-for source '%s' is not an Array" % spec["array_key"])
			return
		for i in (array as Array).size():
			var item = array[i]
			var clone = _clone_dom_node(n)
			clone.attrs.erase("v-for")
			var scope: Dictionary = {spec["loop_var"]: item}
			if spec["index_var"] != "":
				scope[spec["index_var"]] = i
			clone.set_meta("_binding_scope", scope)
			var child_ctrl = r._build_node(clone)
			if child_ctrl != null:
				h.add_child(child_ctrl)

	# Register a binding that rebuilds on array changes
	registry.register({
		"deps": [spec["array_key"]],
		"apply": rebuild,
		"control_ref": weakref(host),
	})
	# Initial build
	rebuild.call()

	return host


## Shallow clone of a DOM node (creates a new GmlNode with same tag,
## attrs, and children). Children are shared by reference; the renderer
## walks them via _build_node which uses _binding_scope meta for evaluation.
func _clone_dom_node(node):
	var GmlNode = preload("res://addons/gtml/src/html_parser/GmlNode.gd")
	var clone = GmlNode.create_element(node.tag, node.attrs.duplicate())
	clone.children = node.children.duplicate()
	return clone
```

The scope propagation requires `_register_bindings_for_node` to read the meta:

In `_register_bindings_for_node`, replace the existing eval/registration calls so they pass scope. First, get the scope:

```gdscript
func _register_bindings_for_node(node, control: Control) -> void:
	if _gml_view == null or control == null:
		return
	var registry: GmlBindingRegistry = _gml_view._binding_registry
	if registry == null:
		return
	var state: GmlState = _gml_view.state
	if state == null:
		return
	var scope: Dictionary = node.get_meta("_binding_scope", {})

	for attr_name in node.attrs:
		var cls: Dictionary = GmlBindingParserScript.classify_attribute(attr_name)
		match cls["kind"]:
			"v-bind":
				var expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				if cls["target"] == "class":
					GmlBindingApplierScript.register_class_binding_scoped(control, expr, registry, state, scope)
				else:
					GmlBindingApplierScript.register_attr_binding_scoped(control, cls["target"], expr, registry, state, scope)
			"v-show":
				var v_show_expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				GmlBindingApplierScript.register_v_show_scoped(control, v_show_expr, registry, state, scope)
			_:
				pass

	if control is Label and node.children.size() > 0:
		var combined: String = ""
		for child in node.children:
			if child.is_text_node:
				combined += child.text
		if "{{" in combined:
			var spans: Array = GmlBindingParserScript.find_interpolations(combined)
			GmlBindingApplierScript.register_text_interpolation_scoped(control as Label, spans, registry, state, scope)
```

Add scoped variants in `addons/gtml/src/binding/GmlBindingApplier.gd`. Each wraps an existing register, passing the scope through. To avoid a near-double of every register function, refactor: change existing register_* signatures to accept an optional scope param (default `{}`) and drop the `_scoped` suffix. Update call sites in earlier tasks.

Cleaner change: Replace each `register_*` to thread `scope`:

```gdscript
static func register_text_interpolation(label: Label, spans: Array, registry: GmlBindingRegistry, state: GmlState, scope: Dictionary = {}) -> void:
	var deps: Array = _collect_text_deps(spans)
	var ref := weakref(label)
	var apply := func():
		var ctl = ref.get_ref()
		if ctl == null:
			return
		(ctl as Label).text = _render_spans(spans, state, scope)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	})
	apply.call()


static func register_attr_binding(control: Control, target: String, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState, scope: Dictionary = {}) -> void:
	var ref := weakref(control)
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
	})
	apply.call()


static func register_class_binding(control: Control, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState, scope: Dictionary = {}) -> void:
	var ref := weakref(control)
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
			for x in (resolved as String).split(" ", false):
				classes.append(x)
		ctl.set_meta("dynamic_classes", classes)
	var deps: Array = []
	_collect_expr_deps(expr, deps)
	registry.register({
		"deps": deps,
		"apply": apply,
		"control_ref": ref,
	})
	apply.call()


static func register_v_show(control: Control, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState, scope: Dictionary = {}) -> void:
	var ref := weakref(control)
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
	})
	apply.call()


static func eval_v_if(expr_source: String, state: GmlState, scope: Dictionary = {}) -> bool:
	var ast: Dictionary = GmlBindingExpr.parse(expr_source)
	return _truthy(eval(ast, state, scope))
```

Update the renderer call sites to drop the `_scoped` suffix (use the same names):

```gdscript
GmlBindingApplierScript.register_class_binding(control, expr, registry, state, scope)
GmlBindingApplierScript.register_attr_binding(control, cls["target"], expr, registry, state, scope)
GmlBindingApplierScript.register_v_show(control, v_show_expr, registry, state, scope)
GmlBindingApplierScript.register_text_interpolation(control as Label, spans, registry, state, scope)
```

- [ ] **Step 7.4: Run + commit**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 281/281 (278 + 3).

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd \
        addons/gtml/src/html_renderer/GmlRenderer.gd \
        tests/unit/test_binding_integration.gd
git commit -m "feat(binding): v-for list rendering with scope frames

v-for parses 'item in items' or 'item, index in items' into a spec
{loop_var, index_var, array_key}. _build_v_for creates a VBoxContainer
host, clones the DOM template node per array element, stashes a
{loop_var: item, index_var: i} scope dict on the clone's meta, and
recursively builds. A registry binding on the array key tears down +
rebuilds when the array changes.

All register_* applier functions gained an optional 'scope' parameter
(default {}). Existing call sites are unchanged; the renderer now
threads the per-element scope through registration so {{ item.name }}
inside a v-for resolves correctly.

3 new integration tests: per-element rendering, rebuild on array
change, indexed form with index variable."
```

---

## Task 8: v-model + @event(args) + item_clicked signal

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `addons/gtml/src/html_renderer/GmlRenderer.gd`
- Modify: `addons/gtml/src/GmlView.gd`
- Modify: `tests/unit/test_binding_integration.gd`
- Modify: `tests/unit/test_binding_applier.gd`

### v-model

Two-way binding for inputs:
- `<input v-model="email">` (LineEdit) — `text ↔ state["email"]`
- `<input type="checkbox" v-model="opt">` (CheckBox, no group) — `button_pressed ↔ state["opt"]`
- `<select v-model="size">` (OptionButton) — selected text ↔ state["size"]
- `<input type="range" v-model="vol">` (HSlider) — `value ↔ state["vol"]`

Reentry guard: when state changes update the control, only write if `control.text != state.get(key)` (prevents text_changed from firing back).

### @event(args)

Existing `@click="handler"` (bare) keeps working. New: `@click="handler(item, index)"` — args are resolved against current scope. Fires `view.item_clicked(handler_name, args: Array)`.

- [ ] **Step 8.1: Write tests for v-model**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript
func test_v_model_text_input_state_to_control() -> void:
	var view := _build_view('<input v-model="email">')
	view.state.set("email", "ada@example.com")
	await get_tree().process_frame
	await get_tree().process_frame
	var line := _find_first_line_edit(view)
	assert_not_null(line)
	assert_eq(line.text, "ada@example.com")


func test_v_model_text_input_control_to_state() -> void:
	var view := _build_view('<input v-model="search">')
	view.state.set("search", "")
	await get_tree().process_frame
	await get_tree().process_frame
	var line := _find_first_line_edit(view)
	# Simulate typing
	line.text = "sword"
	line.text_changed.emit("sword")
	assert_eq(view.state.get("search"), "sword")


func test_v_model_checkbox_two_way() -> void:
	var view := _build_view('<input type="checkbox" v-model="opt">')
	view.state.set("opt", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var cb := _find_first_check_box(view)
	assert_not_null(cb)
	assert_true(cb.button_pressed)

	cb.button_pressed = false
	cb.toggled.emit(false)
	assert_false(view.state.get("opt"))


func test_event_handler_with_args_fires_item_clicked() -> void:
	var view := _build_view('<ul><li v-for="item, i in items" @click="select(item, i)">{{ item }}</li></ul>')
	view.state.set("items", ["a", "b", "c"])
	await get_tree().process_frame
	await get_tree().process_frame

	var captured: Array = []
	view.item_clicked.connect(func(handler, args):
		captured.append([handler, args])
	)
	# Find the third <li>'s wrapped control (an a-tag style click target).
	# For <li>, GmlListBuilder wraps marker+content; the control receiving
	# clicks is the inner HBoxContainer. We simulate by firing the gui_input
	# pattern the renderer wires up — call the binding's apply directly
	# via the registry would require knowing the binding ID; instead emit a
	# synthetic gui_input on the first list-item control.
	var li_controls: Array = []
	_collect_v_for_clones(view, li_controls)
	assert_eq(li_controls.size(), 3)
	# Find the "click handler control" — the one with meta "v-on-click"
	for ctl in li_controls:
		if ctl.has_meta("v-on-click"):
			# Fire it
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			ctl.gui_input.emit(click)
			break

	# Whichever item was clicked first, assert the call shape
	assert_gt(captured.size(), 0, "item_clicked should have fired")
	assert_eq(captured[0][0], "select", "handler name should be 'select'")
	assert_eq(captured[0][1].size(), 2, "args should be [item, index]")


func _find_first_line_edit(node: Node) -> LineEdit:
	if node is LineEdit:
		return node
	for c in node.get_children():
		var le = _find_first_line_edit(c)
		if le != null:
			return le
	return null


func _find_first_check_box(node: Node) -> CheckBox:
	if node is CheckBox:
		return node
	for c in node.get_children():
		var cb = _find_first_check_box(c)
		if cb != null:
			return cb
	return null


func _collect_v_for_clones(node: Node, out: Array) -> void:
	if node is Control and (node as Control).has_meta("v-on-click"):
		out.append(node)
	for c in node.get_children():
		_collect_v_for_clones(c, out)
```

- [ ] **Step 8.2: Implement v-model and @event(args) in applier**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, replace the `eval()` match `"call"` branch:

```gdscript
		"call":
			# Resolve the call's args; the call name itself doesn't evaluate
			# (call invocation is the renderer's job for @event handlers).
			var resolved_args: Array = []
			for a in expr.get("args", []):
				resolved_args.append(eval(a, state, scope))
			return {"_call": true, "name": expr["name"], "args": resolved_args}
```

Add registration helpers:

```gdscript
## Wire v-model two-way binding on an input control. The state-key is the
## v-model's source; the appropriate property on the control is bound.
## Supports LineEdit, TextEdit, CheckBox (non-group), HSlider, OptionButton.
static func register_v_model(control: Control, key: String, registry: GmlBindingRegistry, state: GmlState, scope: Dictionary = {}) -> void:
	# State → control (initial + reactive)
	var ref := weakref(control)
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
			# Find item by text; if found and not selected, select it
			for i in ob.item_count:
				if ob.get_item_text(i) == str(v):
					if ob.selected != i:
						ob.select(i)
					break
	registry.register({
		"deps": [key],
		"apply": apply_state_to_control,
		"control_ref": ref,
	})
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


## Wire @event with args. Stashes the parsed call AST + current scope on
## the control's meta and connects gui_input → item_clicked signal on
## the view. The view is needed so we can emit from a static helper —
## we accept it as a parameter.
static func register_event_with_args(control: Control, event: String, call_expr: Dictionary, state: GmlState, scope: Dictionary, view) -> void:
	if event != "click":
		push_warning("GmlBindingApplier: @event(args) currently supports only 'click', got '%s'" % event)
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.set_meta("v-on-click", true)
	var view_ref := weakref(view)
	control.gui_input.connect(func(event_obj: InputEvent):
		if not (event_obj is InputEventMouseButton):
			return
		var mb := event_obj as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var v = view_ref.get_ref()
		if v == null:
			return
		# Re-evaluate args at click time so the latest state is used.
		var resolved_args: Array = []
		for a in call_expr.get("args", []):
			resolved_args.append(eval(a, state, scope))
		v.item_clicked.emit(call_expr["name"], resolved_args)
	)
```

- [ ] **Step 8.3: Add item_clicked signal to GmlView**

In `addons/gtml/src/GmlView.gd`, near other signals:

```gdscript
## Emitted when an @event="handler(args...)" with arguments triggers.
## Bare @event="handler" continues to fire button_clicked (existing).
signal item_clicked(handler: String, args: Array)
```

- [ ] **Step 8.4: Wire v-model + @event(args) in renderer**

In `addons/gtml/src/html_renderer/GmlRenderer.gd`, extend `_register_bindings_for_node`:

```gdscript
	for attr_name in node.attrs:
		var cls: Dictionary = GmlBindingParserScript.classify_attribute(attr_name)
		match cls["kind"]:
			"v-bind":
				var expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				if cls["target"] == "class":
					GmlBindingApplierScript.register_class_binding(control, expr, registry, state, scope)
				else:
					GmlBindingApplierScript.register_attr_binding(control, cls["target"], expr, registry, state, scope)
			"v-show":
				var v_show_expr: Dictionary = GmlBindingExprScript.parse(node.attrs[attr_name])
				GmlBindingApplierScript.register_v_show(control, v_show_expr, registry, state, scope)
			"v-model":
				# The v-model "target" is empty; the source value IS the key.
				var v_model_key: String = node.attrs[attr_name]
				GmlBindingApplierScript.register_v_model(control, v_model_key, registry, state, scope)
			"v-on":
				# Bare @click="handler" continues through the existing element
				# builders (which emit button_clicked). Only @click="handler(args)"
				# is handled here — detected by parsing the value.
				var raw_value: String = node.attrs[attr_name]
				var raw_ast: Dictionary = GmlBindingExprScript.parse(raw_value)
				if raw_ast.get("type") == "call":
					GmlBindingApplierScript.register_event_with_args(control, cls["target"], raw_ast, state, scope, _gml_view)
			_:
				pass
```

- [ ] **Step 8.5: Run + commit**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 285/285 (281 + 4).

```bash
git add addons/gtml/src/binding/GmlBindingApplier.gd \
        addons/gtml/src/html_renderer/GmlRenderer.gd \
        addons/gtml/src/GmlView.gd \
        tests/unit/test_binding_integration.gd
git commit -m "feat(binding): v-model two-way + @event(args) → item_clicked

v-model wires LineEdit / TextEdit / CheckBox / HSlider / OptionButton
to a state key in both directions. State → control writes are guarded
by an equality check so the control's *_changed signal doesn't fire
back into state and create a loop. Control → state writes go through
the normal state.set() path so they re-trigger any other bindings.

@event=\"handler(arg1, arg2)\" with arguments fires the new
view.item_clicked(handler, args: Array) signal. Args are re-evaluated
at click time so they see the latest state. Bare @click=\"handler\"
continues to fire button_clicked unchanged.

4 new integration tests: v-model text input both directions, v-model
checkbox both directions, @event with args inside v-for fires
item_clicked with the right shape."
```

---

## Task 9: Inventory showcase sample

**Files:**
- Create: `addons/gtml/examples/showcase/inventory/index.html`
- Create: `addons/gtml/examples/showcase/inventory/style.css`
- Create: `addons/gtml/examples/showcase/inventory/demo.gd`
- Create: `addons/gtml/examples/showcase/inventory/demo.tscn`
- Modify: `tests/unit/test_renderer_smoke.gd` (add inventory smoke)

Parchment palette (warm cream + ink + gold accent) since the other 4 samples lean dark.

- [ ] **Step 9.1: Write the HTML**

Create `addons/gtml/examples/showcase/inventory/index.html`:

```html
<div class="page">
	<header class="topbar">
		<span class="title">Inventory</span>
		<span class="gold">⛁ {{ gold }}</span>
	</header>

	<div class="content">

		<div class="left-pane">
			<div class="filter-row">
				<input v-model="search" type="text" placeholder="Search items..." class="search-input">
				<button @click="set_filter('all')" :class="{ active: is_filter_all }" class="filter-btn">All</button>
				<button @click="set_filter('weapon')" :class="{ active: is_filter_weapon }" class="filter-btn">Weapon</button>
				<button @click="set_filter('potion')" :class="{ active: is_filter_potion }" class="filter-btn">Potion</button>
			</div>

			<ul class="item-grid">
				<li v-for="item, i in filtered_items" @click="select(item)" class="item-card">
					<span class="item-icon">{{ item.icon }}</span>
					<span class="item-name">{{ item.name }}</span>
					<span class="item-qty">×{{ item.qty }}</span>
				</li>
			</ul>

			<p v-if="empty" class="empty-msg">No items match.</p>
		</div>

		<div class="right-pane" v-show="has_selection">
			<h2 class="detail-name">{{ selected_name }}</h2>
			<p class="detail-rarity">{{ selected_rarity }}</p>
			<p class="detail-desc">{{ selected_desc }}</p>
			<button @click="use_item" :disabled="!has_selection" class="use-btn">Use</button>
		</div>

	</div>

	<div class="hotbar">
		<div v-for="slot, i in hotbar" class="slot">
			<span class="slot-num">{{ i }}</span>
			<span class="slot-icon">{{ slot }}</span>
		</div>
	</div>
</div>
```

- [ ] **Step 9.2: Write the CSS**

Create `addons/gtml/examples/showcase/inventory/style.css`:

```css
/* Inventory — parchment palette, warm cream + ink + gold accent.
 * v0.7 showcase: exercises every binding directive end-to-end.
 */

.page {
	--bg: #f5ecd9;
	--surface-1: #ebe0c4;
	--surface-2: #e3d4ae;
	--border-1: #c7b289;
	--border-2: #a89673;
	--text-1: #2a1f12;
	--text-2: #5a4a32;
	--text-muted: #8a7858;
	--accent: #b8860b;
	--accent-hot: #d4a017;
	--rare: #6b3e9b;
	--common: #5a5a5a;
	display: flex;
	flex-direction: column;
	width: 100%;
	height: 100%;
	background-color: var(--bg);
	color: var(--text-1);
}

.topbar {
	display: flex;
	flex-direction: row;
	justify-content: space-between;
	align-items: center;
	padding-left: 24px;
	padding-right: 24px;
	padding-top: 14px;
	padding-bottom: 14px;
	border-bottom: 1px solid var(--border-1);
	background-color: var(--surface-1);
}

.title {
	font-size: 16px;
	font-weight: 700;
	letter-spacing: 4;
	text-transform: uppercase;
	color: var(--text-1);
}

.gold {
	font-size: 14px;
	font-weight: 600;
	color: var(--accent);
}

.content {
	display: flex;
	flex-direction: row;
	flex-grow: 1;
	gap: 16px;
	padding: 16px;
}

.left-pane {
	display: flex;
	flex-direction: column;
	flex-grow: 1;
	gap: 12px;
}

.filter-row {
	display: flex;
	flex-direction: row;
	gap: 8px;
}

.search-input {
	flex-grow: 1;
	background-color: var(--surface-1);
	color: var(--text-1);
	border: 1px solid var(--border-1);
	border-radius: 3px;
	padding: 8px;
	font-size: 13px;
}

.filter-btn {
	background-color: var(--surface-1);
	color: var(--text-2);
	border: 1px solid var(--border-1);
	border-radius: 3px;
	padding-left: 12px;
	padding-right: 12px;
	padding-top: 6px;
	padding-bottom: 6px;
	font-size: 12px;
	font-weight: 600;
	transition: background-color 150ms, color 150ms;
}

.filter-btn:hover {
	background-color: var(--surface-2);
}

.filter-btn.active {
	background-color: var(--accent);
	color: var(--bg);
	border: 1px solid var(--accent-hot);
}

.item-grid {
	display: flex;
	flex-direction: column;
	gap: 4px;
	list-style-type: none;
	overflow-y: auto;
}

.item-card {
	display: flex;
	flex-direction: row;
	align-items: center;
	gap: 12px;
	padding: 10px;
	background-color: var(--surface-1);
	border: 1px solid var(--border-1);
	border-radius: 3px;
	transition: border 150ms, background-color 150ms;
}

.item-card:hover {
	background-color: var(--surface-2);
	border: 1px solid var(--accent);
}

.item-icon {
	font-size: 20px;
	min-width: 28px;
}

.item-name {
	flex-grow: 1;
	font-size: 14px;
	color: var(--text-1);
}

.item-qty {
	font-size: 12px;
	color: var(--text-muted);
}

.empty-msg {
	color: var(--text-muted);
	font-size: 13px;
	text-align: center;
	padding-top: 24px;
}

.right-pane {
	display: flex;
	flex-direction: column;
	width: 240px;
	gap: 10px;
	padding: 16px;
	background-color: var(--surface-1);
	border: 1px solid var(--border-1);
	border-radius: 3px;
}

.detail-name {
	font-size: 18px;
	font-weight: 700;
	color: var(--text-1);
}

.detail-rarity {
	font-size: 11px;
	color: var(--accent);
	letter-spacing: 2;
	text-transform: uppercase;
}

.detail-desc {
	font-size: 13px;
	color: var(--text-2);
	line-height: 5;
}

.use-btn {
	background-color: var(--accent);
	color: var(--bg);
	border: 1px solid var(--accent-hot);
	border-radius: 3px;
	padding: 8px;
	font-size: 13px;
	font-weight: 700;
	margin-top: 12px;
	transition: background-color 150ms;
}

.use-btn:hover {
	background-color: var(--accent-hot);
}

.hotbar {
	display: flex;
	flex-direction: row;
	gap: 6px;
	padding: 10px;
	background-color: var(--surface-2);
	border-top: 1px solid var(--border-1);
	justify-content: center;
}

.slot {
	display: flex;
	flex-direction: column;
	align-items: center;
	justify-content: center;
	width: 56px;
	height: 56px;
	background-color: var(--surface-1);
	border: 1px solid var(--border-1);
	border-radius: 3px;
}

.slot-num {
	font-size: 9px;
	color: var(--text-muted);
}

.slot-icon {
	font-size: 18px;
}
```

- [ ] **Step 9.3: Write the demo script**

Create `addons/gtml/examples/showcase/inventory/demo.gd`:

```gdscript
extends Control

## Inventory demo — v0.7 binding integration.
## This is the FIRST showcase sample with a real game-side script. Atlas,
## Atelier, Forge, and Kitchen are all pure HTML+CSS. The inventory shows
## how state.set(), state_changed, and item_clicked compose to make a
## fully reactive UI without per-element binding code.

@onready var view: GmlView = $GmlView

const ITEMS := [
	{"id": "sword",    "name": "Iron Sword",    "type": "weapon", "rarity": "common", "icon": "⚔", "qty": 1, "desc": "A reliable iron blade."},
	{"id": "bow",      "name": "Hunting Bow",   "type": "weapon", "rarity": "common", "icon": "🏹", "qty": 1, "desc": "Quick and quiet."},
	{"id": "axe",      "name": "War Axe",       "type": "weapon", "rarity": "rare",   "icon": "🪓", "qty": 1, "desc": "Heavy. Devastating."},
	{"id": "potion_s", "name": "Small Potion",  "type": "potion", "rarity": "common", "icon": "🧪", "qty": 5, "desc": "Restores 25 HP."},
	{"id": "potion_l", "name": "Large Potion",  "type": "potion", "rarity": "rare",   "icon": "🧴", "qty": 2, "desc": "Restores 75 HP."},
	{"id": "key",      "name": "Brass Key",     "type": "misc",   "rarity": "common", "icon": "🗝", "qty": 1, "desc": "Opens... something."},
]

const HOTBAR := ["⚔", "🧪", "🏹", "🗝"]

var _current_filter: String = "all"


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
		"is_filter_all": true,
		"is_filter_weapon": false,
		"is_filter_potion": false,
		"hotbar": HOTBAR,
	})
	view.state.state_changed.connect(_on_state_changed)
	view.item_clicked.connect(_on_item_clicked)


func _on_state_changed(key: String, _new_value, _old_value) -> void:
	if key == "search":
		_apply_filter()


func _on_item_clicked(handler: String, args: Array) -> void:
	match handler:
		"select":
			var item = args[0] if args.size() > 0 else null
			if item == null:
				return
			view.state.set_state({
				"selected_item": item,
				"selected_name": item["name"],
				"selected_rarity": item["rarity"],
				"selected_desc": item["desc"],
				"has_selection": true,
			})
		"set_filter":
			_current_filter = str(args[0]) if args.size() > 0 else "all"
			view.state.set_state({
				"is_filter_all": _current_filter == "all",
				"is_filter_weapon": _current_filter == "weapon",
				"is_filter_potion": _current_filter == "potion",
			})
			_apply_filter()
		"use_item":
			# Demo only — would consume the selected item in a real game.
			pass


func _apply_filter() -> void:
	var query: String = str(view.state.get("search")).to_lower()
	var out: Array = []
	for item in ITEMS:
		if _current_filter != "all" and item["type"] != _current_filter:
			continue
		if not query.is_empty() and not item["name"].to_lower().contains(query):
			continue
		out.append(item)
	view.state.set("filtered_items", out)
	view.state.set("empty", out.is_empty())
```

- [ ] **Step 9.4: Write the scene**

Create `addons/gtml/examples/showcase/inventory/demo.tscn`:

```
[gd_scene load_steps=3 format=3 uid="uid://gml_inventory_demo"]

[ext_resource type="Script" path="res://addons/gtml/src/GmlView.gd" id="1_gmlview"]
[ext_resource type="Script" path="res://addons/gtml/examples/showcase/inventory/demo.gd" id="2_demo"]

[node name="InventoryDemo" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("2_demo")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.96, 0.925, 0.852, 1)

[node name="GmlView" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_gmlview")
html_path = "res://addons/gtml/examples/showcase/inventory/index.html"
css_path = "res://addons/gtml/examples/showcase/inventory/style.css"
```

- [ ] **Step 9.5: Add smoke test**

In `tests/unit/test_renderer_smoke.gd`, find the `SHOWCASES` constant and append:

```gdscript
	{"name": "inventory", "dir": "showcase/inventory"},
```

Find the existing showcase test function pattern (e.g. `test_showcase_kitchen_renders`) and add:

```gdscript
func test_showcase_inventory_renders() -> void:
	# v0.7 binding showcase — exercises every directive end-to-end.
	var v := _build_showcase(SHOWCASES[4])
	await _assert_built(v, "inventory")
```

- [ ] **Step 9.6: Run + commit**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: 286/286 (285 + 1).

```bash
git add addons/gtml/examples/showcase/inventory/ tests/unit/test_renderer_smoke.gd
git commit -m "feat(samples): inventory showcase (v0.7 bindings end-to-end)

5th showcase sample at addons/gtml/examples/showcase/inventory/.
Parchment palette (warm cream + ink + gold accent) — first warm/light
sample to balance the dark Atlas/Forge/Kitchen set.

Exercises every v0.7 directive:
  - {{ }} interpolation throughout (gold, item names, qty, detail panel)
  - :class object syntax for active filter button
  - :disabled for the Use button
  - v-for for item grid and hotbar slots (with indexed form for hotbar)
  - v-if for the empty-state message
  - v-show for the detail panel
  - v-model for the search input
  - @click(item) for item selection
  - @click(filter_name) for filter buttons
  - Bare @click for the Use button

This is the FIRST showcase with a real GDScript companion (demo.gd) —
all prior samples are pure HTML+CSS. The script demonstrates the actual
game-integration pattern: state.set_state for initial state,
state_changed signal for derived state (filtering), item_clicked
signal for per-element actions.

Adds 1 smoke test for the showcase loader."
```

---

## Task 10: User-facing docs

**Files:**
- Create: `docs/bindings.md`
- Modify: `docs/getting-started.md` (link)

- [ ] **Step 10.1: Write the docs page**

Create `docs/bindings.md`:

```markdown
# Reactive bindings (v0.7+)

GTML supports Vue-style reactive bindings so dynamic UIs (HUDs,
inventories, leaderboards, dialog trees) don't require per-element
GDScript glue. You declare the data flow in HTML; your game code only
updates state.

## The 30-second example

```html
<h1>Welcome, {{ player.name }}!</h1>
<ul>
  <li v-for="item in inventory" @click="select(item)">
    <img :src="item.icon">
    <span>{{ item.name }}</span>
    <span v-show="item.qty > 1">×{{ item.qty }}</span>
  </li>
</ul>
<button :disabled="!selected_item">Use</button>
```

```gdscript
@onready var view: GmlView = $GmlView

func _ready() -> void:
    view.state.set("player.name", "Ada")
    view.state.set("inventory", load_inventory())
    view.state.set("selected_item", null)
    view.item_clicked.connect(_on_item_clicked)

func _on_item_clicked(handler: String, args: Array) -> void:
    if handler == "select":
        view.state.set("selected_item", args[0])
```

## The state object

Every `GmlView` has a `state: GmlState` field. Read with `view.state.get(key)`, write with `view.state.set(key, value)`. State persists across HTML/CSS hot-reloads.

```gdscript
view.state.set("score", 42)
view.state.set("player.health", 85)        # dotted paths are keys
view.state.set_state({"a": 1, "b": 2})     # batch update
print(view.state.get("score"))             # 42
```

`set()` short-circuits if the new value equals the old one, so re-renders only fire when values actually change.

## Directive reference

### `{{ expr }}` — text interpolation

```html
<h1>Welcome, {{ name }}!</h1>
<span>HP: {{ player.health }}/{{ player.max_health }}</span>
```

Substitutes at render and on every change to a referenced state key. Works in any text node.

### `:attr="key"` — attribute binding (v-bind shorthand)

```html
<button :disabled="locked">Save</button>
<input :value="name">
<img :src="icon_path">
<a :href="link_url">link</a>
```

Reads the key from state on render and on every change. Supported targets in v0.7: `disabled`, `value`, `src`, `href`. Unknown targets emit a warning.

### `:class="..."` — class binding

Three forms:

```html
<!-- Bare key: state.get("dyn") is a string -->
<div :class="dyn">

<!-- Object: keys are class names, values must be truthy to apply -->
<div :class="{ active: is_active, dim: !is_active }">

<!-- Array: mix literals + dynamic -->
<div :class="['static', dynamic_class_name]">
```

**Limitation in v0.7**: `:class` stores the dynamic class list on the control's `dynamic_classes` meta but does NOT re-resolve CSS rules. Styles declared on classes present at build time work normally; dynamic class addition does not pull in new styles. Workaround: declare all possible classes at build time and use `v-show` / `v-if` to swap.

### `v-if="expr"` — conditional rendering

```html
<div v-if="show_panel">...</div>
<div v-if="!loading">...</div>
```

When the expression is falsy, the element (and all its children) is omitted from the tree. On state change, the parent rebuilds.

### `v-show="expr"` — conditional visibility

```html
<div v-show="show_panel">...</div>
```

Element stays in the tree; `visible` flips. Cheaper than `v-if` for elements that toggle frequently.

### `v-for="item in items"` — list rendering

```html
<ul>
  <li v-for="entry in inventory">{{ entry.name }}</li>
</ul>
```

With index:

```html
<li v-for="entry, i in inventory">{{ i }}: {{ entry.name }}</li>
```

On state change to the bound array, all children of the v-for parent are torn down and rebuilt. For typical game inventories (<100 items) this is fast enough. Keyed reconciliation (`:key="entry.id"`) is planned for a future release.

### `v-model="key"` — two-way input binding

```html
<input v-model="search">                          <!-- LineEdit -->
<input type="checkbox" v-model="opt_in">          <!-- CheckBox -->
<input type="range" v-model="volume">             <!-- HSlider -->
<select v-model="size">...</select>               <!-- OptionButton -->
```

State changes update the control; user edits update state. The state-to-control direction is guarded by an equality check so the control's `*_changed` signal can't feed back into state.

### `@event="handler(args)"` — events with arguments

```html
<li v-for="item in items" @click="select(item)">...</li>
<button @click="confirm('save', form_data)">Save</button>
```

Fires `view.item_clicked(handler: String, args: Array)`. Args are re-evaluated at click time so they reflect current state. Bare `@click="handler"` (no parens) continues to fire `button_clicked(handler)` as in earlier versions.

## Expression grammar

`{{ ... }}`, `:attr="..."`, `v-if="..."`, `v-show="..."`, `v-model="..."` accept a path (with optional `!` negation):

- `key`
- `nested.key.path`
- `!key`
- `!nested.key`

`:class` and `@event` additionally accept object literals, array literals, and call expressions. Full grammar:

```
Expr     := Path | NegPath | ObjectLit | ArrayLit | CallExpr | StringLit
Path     := Ident ('.' Ident)*
NegPath  := '!' Path
ObjectLit:= '{' (Ident ':' Expr (',' Ident ':' Expr)*)? '}'
ArrayLit := '[' (Expr (',' Expr)*)? ']'
CallExpr := Ident '(' (Expr (',' Expr)*)? ')'
StringLit:= "'…'" | '"…"'
```

**Not supported**: arithmetic, comparison, string concat, ternaries. If you need a computed value, compute it in GDScript and `view.state.set("is_complex", ...)`.

## Loop scope

Inside a `v-for`, the loop variable shadows global state on key collision:

```html
<li v-for="item in items">{{ item.name }}</li>
```

`item.name` reads from the loop variable, not from a global `item` key.

## See also

- [Getting started](getting-started.md)
- [Forms & inputs](forms-and-inputs.md) — for non-binding input patterns
- The `inventory/` showcase sample demonstrates every directive end-to-end.
```

- [ ] **Step 10.2: Link from getting-started.md**

In `docs/getting-started.md`, find the Next Steps list and add (near the top):

```markdown
- [Reactive bindings](bindings.md) - Vue-style {{ }}, :attr, v-for, v-if, v-model
```

- [ ] **Step 10.3: Commit**

```bash
git add docs/bindings.md docs/getting-started.md
git commit -m "docs: v0.7 bindings reference page

New docs/bindings.md covers the full v0.7 directive set with a
30-second example and per-directive sections: {{ }}, :attr, :class
(including the no-re-resolve limitation), v-if, v-show, v-for (with
indexed form), v-model, @event(args). Documents the expression
grammar boundary and points to the inventory sample.

Linked from docs/getting-started.md Next Steps."
```

---

## Task 11: Version bump + CHANGELOG + PR

**Files:**
- Modify: `addons/gtml/plugin.cfg`
- Modify: `CHANGELOG.md`

- [ ] **Step 11.1: Bump version**

Edit `addons/gtml/plugin.cfg`. Change `version="0.6.0"` to `version="0.7.0"`.

- [ ] **Step 11.2: Write CHANGELOG entry**

Insert at the top of `CHANGELOG.md`, after the `# Changelog` line and BEFORE the existing `## 0.6.0` section:

```markdown
## 0.7.0

### Features — Reactive bindings

GTML graduates from "menu builder" to "real UI framework" with Vue-style
reactive bindings. Dynamic content (HUDs, inventories, leaderboards,
dialog trees) is now feasible without per-element GDScript glue.

- **`GmlView.state`** — a `GmlState` instance per view. `state.set(key,
  value)` writes; `state.get(key)` reads; `state.set_state({...})`
  batches. `state_changed(key, new, old)` signal fires per changed key.
- **`{{ expr }}` text interpolation** — substitutes at render and on
  every change to a referenced state key.
- **`:attr="expr"` one-way attribute binding** — supported targets:
  `disabled`, `value`, `src`, `href`. (Shorthand for `v-bind:attr`.)
- **`:class="..."` class binding** — bare key, object syntax
  `{ name: cond_key }`, and array syntax `['static', dyn_key]`.
  Limitation: stores classes on `dynamic_classes` meta but does NOT
  re-resolve CSS; declare possible classes at build time.
- **`v-if="expr"` / `v-show="expr"`** — conditional rendering /
  visibility.
- **`v-for="item in items"` list rendering** — also `v-for="item, i in
  items"` for indexed form. Rebuilds on collection change (no keyed
  reconciliation in v0.7).
- **`v-model="key"` two-way input binding** — `LineEdit`, `TextEdit`,
  `CheckBox` (non-group), `HSlider`, `OptionButton`. Equality-guarded so
  state ↔ control updates don't feedback-loop.
- **`@event="handler(args)"` events with arguments** — fires new
  `view.item_clicked(handler: String, args: Array)` signal. Args
  re-evaluated at click time. Bare `@event="handler"` keeps firing
  `button_clicked`.

### Architecture

Five new pure-data engines under `addons/gtml/src/binding/`:

- `GmlState.gd` — reactive key→value store, no-op skip on equal writes
- `GmlBindingExpr.gd` — mini-expression parser (paths, `!`, object/array
  literals, call exprs, string literals; no arithmetic / comparison)
- `GmlBindingParser.gd` — scans HTML for `{{ }}` + classifies attrs
- `GmlBindingRegistry.gd` — per-view `{key → [bindings]}` reverse index,
  prunes freed-control bindings
- `GmlBindingApplier.gd` — evaluates AST + writes to controls

`GmlRenderer._build_node` gained three hooks: v-for (highest priority,
takes over and clones), v-if (short-circuit return null), and post-build
binding registration. `GmlHtmlParser` now accepts `:` as a first
character of attribute names so `<div :class="x">` parses.

### Showcase

New 5th sample: `addons/gtml/examples/showcase/inventory/` — pause-menu
inventory overlay with filterable item grid, detail panel, search, and
hotbar. **First sample with a real `demo.gd` companion script** —
demonstrates the actual game-integration pattern (`state.set_state` for
initial state, `state_changed` for derived state, `item_clicked` for
per-element actions).

### Tests

60+ new tests covering state, expression parser, binding parser,
registry, applier, and end-to-end integration through `GmlView`. Test
count: 223 → ~286.

### Deferred / not yet supported

- Arithmetic / comparison / ternary in expressions (compute in GDScript)
- Keyed reconciliation (`:key`) for `v-for`
- Cross-view shared state / global store
- Watchers / lifecycle hooks beyond `state_changed`
- Computed properties / refs
- Dynamic CSS re-resolution when `:class` changes
- `v-bind:[dynamic-attr]` (dynamic attr name binding)
```

- [ ] **Step 11.3: Run full suite**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing"
```

Expected: ~286/286, 0 failures.

- [ ] **Step 11.4: Commit**

```bash
git add addons/gtml/plugin.cfg CHANGELOG.md
git commit -m "chore(v0.7.0): version bump + CHANGELOG

Documents the reactive bindings feature set (state model, all
directives, the inventory showcase) and notes the deferred items
(no expression arithmetic, no v-for keyed reconciliation, no dynamic
:class CSS re-resolution)."
```

- [ ] **Step 11.5: Push + open PR**

```bash
git push -u origin feat/v0.7-data-binding 2>&1 | tail -3
gh pr create --base master --title "v0.7: Vue-style reactive bindings (state, {{ }}, v-for, v-if, v-show, v-model, @event(args))" --body "$(cat <<'EOF'
## Summary

GTML graduates from "menu builder" to "real UI framework". Vue-style reactive bindings make dynamic UIs feasible without per-element GDScript glue.

## What's new

| Feature | Form |
|---|---|
| **State** | \`view.state.set(key, value)\` / \`get(key)\` / \`set_state({...})\` |
| **Text interpolation** | \`{{ key }}\` / \`{{ player.health }}\` |
| **Attribute binding** | \`:disabled="locked"\` / \`:src="icon"\` / \`:value="name"\` / \`:href="url"\` |
| **Class binding** | \`:class="dyn"\` / \`:class="{ active: is_on }"\` / \`:class="['static', dyn]"\` |
| **Conditional** | \`v-if="show"\` (omit) / \`v-show="show"\` (toggle visible) |
| **List rendering** | \`v-for="item in items"\` / \`v-for="item, i in items"\` |
| **Two-way input** | \`v-model="email"\` |
| **Event with args** | \`@click="select(item, i)"\` → \`item_clicked(handler, args)\` |

## Architecture

5 new pure-data engines under \`addons/gtml/src/binding/\`. \`GmlRenderer\` gains 3 hooks (v-for, v-if, post-build registration). \`GmlHtmlParser\` accepts \`:\` as first-char of attr names.

## Showcase

New 5th sample at \`addons/gtml/examples/showcase/inventory/\` — parchment-themed pause-menu inventory with filtering, detail panel, hotbar. **First sample with a real demo.gd** demonstrating the game-integration pattern.

## Stats

| | |
|---|---|
| Tests | 286+ (was 223) |
| New engine LOC | ~810 |
| Plugin version | 0.6.0 → 0.7.0 |

## Limitations / deferred

- No arithmetic / comparison in expressions — compute in GDScript and \`state.set(...)\`
- \`:class\` updates the meta but does NOT re-resolve CSS rules at runtime
- \`v-for\` rebuilds on collection change (no keyed reconciliation yet)
- No cross-view shared state / global store
- No watchers / lifecycle hooks beyond \`state_changed\`

## Test plan

- [ ] \`godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json\` → 286+/286+ green
- [ ] Open \`addons/gtml/examples/showcase/inventory/demo.tscn\` and Play. Filter buttons toggle. Search updates the grid live. Clicking an item populates the detail panel. The Use button enables/disables on selection. Hotbar shows 4 slot numbers.
- [ ] Spot-check existing samples still render (atlas, atelier, forge, kitchen) — none should regress.
EOF
)" 2>&1 | tail -3
```

---

## Self-Review

**Spec coverage check** (against `docs/superpowers/specs/2026-05-26-data-binding-design.md`):

- §1 State model + public API → Task 1 (GmlState) ✓
- §2 Directive table → covered across Tasks 3 (parser classification), 4 (text+simple attrs), 5 (:class), 6 (v-if+v-show), 7 (v-for), 8 (v-model+@event args) ✓
- §3 Render integration + reactivity → Task 6 (renderer hooks), Task 7 (v-for hook), Task 8 (v-model + @event) ✓
- §4 Inventory sample → Task 9 ✓
- §5 Testing → tests in every task; integration tests file consolidated in Tasks 6/7/8 ✓
- File layout → matches spec exactly ✓
- Phasing → spec listed 12 phases; this plan has 11 tasks (combined scaffold + GmlState into Task 1, since they're trivially co-dependent). All deliverables covered.

**Placeholder scan:** no TBDs, no "implement later", every code step has actual code, every test step has actual assertions.

**Type consistency:** GmlState API (`set/get/has/set_state/keys`) matches across Tasks 1, 4, 7, 8. GmlBindingRegistry API (`register/fire/fire_batch/clear/binding_count`) matches across Tasks 3 and the integration test. AST shape `{type, parts/inner/entries/items/name/args/value}` consistent. Binding shape `{deps, apply, control_ref}` consistent. Scope parameter optional (default `{}`) added in Task 7 to all register_* functions; renderer call sites updated.

**Known plan-bug heuristic** (from prior v0.6 patterns): the test snippets use `assert_eq(captured[0], ["score", 20, 10])` and `assert_eq(spans[0]["value"], "Hello, ")` — exact string matches; double-check for trailing-space + escape issues during execution. The implementer subagent should run failing-first to catch these before implementation.
