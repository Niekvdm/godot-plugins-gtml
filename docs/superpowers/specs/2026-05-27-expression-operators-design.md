# GTML v0.8 — Expression operators (arithmetic, comparison, logical, ternary, indexing)

**Date:** 2026-05-27
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.8.0 (first of four v0.8 production-readiness PRs)

## Summary

v0.7 ships Vue-style binding directives but bans every operator in
expressions: no `+`, no `>`, no `&&`, no `?:`. The only escape hatch is
to precompute every derived value in GDScript and `state.set` it back
in:

```gdscript
# v0.7 — needed for the simplest "is selected" check
view.state.set("is_filter_all", _current_filter == "all")
view.state.set("is_filter_weapon", _current_filter == "weapon")
view.state.set("is_filter_potion", _current_filter == "potion")
```

The inventory showcase needs three precomputed booleans just to drive
three filter buttons' `active` class. This scales badly — every
predicate becomes a `state_changed` handler that synthesises more
state.

v0.8 lifts that tax. Expression bindings get full operator support so
authors can write:

```html
<button :class="{ active: filter == 'all' }">All</button>
<div :class="{ low: hp < max_hp * 0.25 }">
<span v-if="qty > 1">x{{ qty }}</span>
<li v-for="item, i in items" @click="select(items[i])">
<p>{{ has_save ? 'Continue' : 'New Game' }}</p>
```

## Goals

- Bring expression power to parity with Vue (minus method calls / free
  function calls — those remain out of scope).
- Stay strict on type coercion so silent string/number bugs don't
  appear at runtime.
- Keep the static dependency-collection model unchanged so the registry
  still wakes bindings on the right keys without runtime tracking.
- Preserve every v0.7 binding test as-is.

## Non-goals

- Free function calls (`Math.floor(x)`, `str(x)`). Only the existing
  `@event="handler(args)"` form remains a "call".
- Method calls on values (`name.length()`, `items.size()`). Authors
  precompute these in GDScript.
- Loose / JS-style coercion. `5 + '5'` is an error, not `'55'`.
- Watchers / computed properties. Bindings re-eval on dep change; that
  IS the computed mechanism.
- Implicit string concat for `:attr="'HP: ' + hp"`. Strict means `+`
  refuses cross-type. Authors precompute combined strings.

## Architecture

One file changes substantively: `GmlBindingExpr.gd`. The parser grows
from ~210 to ~330 LOC; the AST gains five node types; the evaluator
in `GmlBindingApplier.gd` grows by ~60 LOC for the new operators.

```
addons/gtml/src/binding/
  GmlBindingExpr.gd        # MODIFY — recursive-descent levels added
  GmlBindingApplier.gd     # MODIFY — eval branches for new nodes
                           #          + _on_warning logger injection point
tests/unit/
  test_binding_expr.gd     # MODIFY — +25 tests (precedence, types, indexing)
  test_binding_applier.gd  # MODIFY — +20 tests (operator semantics)
  test_binding_integration.gd # MODIFY — +5 tests (operators in :class, v-if)
```

No new files. No renderer changes. No HTML parser changes. No spec
deviation that touches `GmlState`, `GmlBindingParser`, or
`GmlBindingRegistry`.

## §1 — Grammar (recursive descent, layered)

Precedence levels (lowest → highest):

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
NumberLit   := [0-9]+ ('.' [0-9]+)?
Ident       := [a-zA-Z_][a-zA-Z0-9_]*
```

Each non-terminal becomes a method on the existing `_Parser` class:
`_parse_ternary`, `_parse_logical_or`, etc. Methods return tagged
Dictionaries (same AST shape as v0.7 plus new tags).

The `_parse_postfix` chain folds existing v0.7 cases:

- `Ident` followed by `(`: emit `{type: "call", name, args}` (unchanged
  back-compat path for `@event` detection).
- `Ident` followed by zero or more `.Ident`: emit `{type: "path", parts}`
  (the v0.7 path syntax).
- Either case followed by `[expr]`: wraps in `{type: "index", target,
  index}`.

`_parse_unary` emits `{type: "neg", inner}` ONLY when the operator is
`!` and the inner is exactly a `path` (back-compat with v0.7 tests
that pattern-match on `neg`). All other unary cases (including `!`
on non-path operands) emit `{type: "unary", op, inner}`.

## §2 — AST node additions

Existing v0.7 nodes unchanged: `path`, `neg`, `object`, `array`,
`call`, `string`, `error`.

New nodes:

```
{type: "number",  value: float}
{type: "binop",   op: String, left: Dict, right: Dict}
{type: "unary",   op: String, inner: Dict}
{type: "ternary", cond: Dict, then: Dict, else_: Dict}
{type: "index",   target: Dict, index: Dict}
```

`op` for `binop`: one of `+ - * / % > < >= <= == != && ||`.
`op` for `unary`: one of `! -`.

The AST key `else_` (trailing underscore) avoids the GDScript reserved
word `else`. Source text never types `else`; the ternary syntax is
`cond ? then : else_branch`.

## §3 — Evaluator semantics (strict GDScript-style)

All operators reject type mismatches with `null` + `push_warning`
(through the injectable logger from §5).

| Op | Rule |
|---|---|
| `+` | num+num→num. str+str→str. Else null+warn. (Cross-type concat is NOT auto.) |
| `-` `*` `/` `%` | num+num only. Else null+warn. `%` is int-modulo via `posmod`; floats coerce to int. |
| `>` `<` `>=` `<=` | num+num OR str+str (lex compare). Else null+warn. |
| `==` `!=` | Cross-type allowed (no warn). Uses `_values_equal` — same as `GmlState`. |
| `&&` `\|\|` | Short-circuit. Left first; if `_truthy(left)` matches op's continue condition, eval right. Return value is the LAST evaluated operand (not coerced to bool). Matches Vue / JS. |
| `!` unary | `not _truthy(inner)` — already implemented as `neg` in v0.7. |
| `-` unary | `-num` only. Else null+warn. |
| ternary | `_truthy(cond) ? eval(then) : eval(else_)`. |
| `index` | Array+int→element. Dict+any→keyed lookup. OOB / missing → null (no warn). |
| `number` | Literal pass-through. |

**Division by zero**: `n / 0` and `n % 0` return null + warn (no INF /
NaN propagation).

**Equality cross-type exception**: `selected_item == null` is the
single most common conditional pattern. Warning on cross-type equality
would create noise on every clone of a v-for that conditionally
renders a detail panel. So `==` and `!=` skip the type-mismatch warn.

## §4 — Static dependency collection

`_collect_expr_deps` in `GmlBindingApplier.gd` gains five branches:

```
"binop":   walk left + right
"unary":   walk inner
"ternary": walk cond + then + else_     # over-approximate
"index":   walk target + index
"number":  no deps
```

Ternary over-approximation: `cond ? a : b` registers deps on
`[cond, a, b]` even though only one branch is read at any time.
Accepted tradeoff (user decision §Q4) — dynamic dep tracking would
require threading mutable state through the eval recursion, with
no measurable benefit for game-UI workloads.

Dedup unchanged: the `out` array does `if not (key in out)`.

## §5 — Warning logger injection point

To make tests assert "this expression emitted a type warning"
deterministically (Godot's `push_warning` is not capturable from GUT
out of the box), `GmlBindingApplier` exposes:

```gdscript
class_name GmlBindingApplier extends RefCounted

static var _on_warning: Callable = Callable()    # default: empty

static func _warn(message: String) -> void:
    if _on_warning.is_valid():
        _on_warning.call(message)
    else:
        push_warning(message)
```

All internal `push_warning(...)` calls in `GmlBindingApplier` route
through `_warn(...)`. Tests assign `_on_warning` to a capturing
lambda at setup and inspect the captured list. `setup` / `teardown`
in `test_binding_applier.gd` resets the static back to `Callable()`
so tests stay isolated.

This logger touches ONLY `GmlBindingApplier`'s own warnings. Other
modules' `push_warning` calls are unaffected.

## §6 — Backward compatibility

- **v0.7 AST shapes preserved** for inputs that match v0.7 grammar
  exactly. `parse("score")` still returns `{type:"path", parts:["score"]}`.
  `parse("!loading")` still returns `{type:"neg", inner:{type:"path", parts:["loading"]}}`.
  `parse("select(item)")` still returns `{type:"call", name:"select", args:[...]}`.
- **All 14 v0.7 `test_binding_expr.gd` tests pass unchanged.**
- **All 10 v0.7 `test_binding_applier.gd` tests pass unchanged.**
- **Hyphen in identifiers dropped.** Grep over the codebase confirmed
  every existing state key and loop var uses `_` or camelCase. No
  migration step needed; documented in `CHANGELOG.md` as a
  backward-incompatible change in expression syntax (state keys
  themselves still accept any string via `state.set`).
- **Reserved word `else`**: source text never uses it; only the AST
  key is `else_`. No parser-level reserved word handling needed.

## §7 — Testing plan

| File | Existing | Added | Total |
|---|---|---|---|
| `test_binding_expr.gd` | 14 | +25 | 39 |
| `test_binding_applier.gd` | 14 | +20 | 34 |
| `test_binding_integration.gd` | 10 | +5 | 15 |

Grand total: 286 baseline → **336** after v0.8.0.

### Parser tests (+25)

Precedence (5): `2+3*4=14`, `(2+3)*4=20`, `!a && b`, `a || b && c`,
`a == b || c == d`.

Associativity (3): `a-b-c → ((a-b)-c)`, `a+b+c`, ternary right-assoc
`a ? b : c ? d : e → a ? b : (c ? d : e)`.

Unary (3): `-x`, `-(a+b)`, `!a.b → neg{path[a,b]}` (back-compat
shape), `!(a && b) → unary{!, binop{...}}` (new shape).

Indexing (4): `items[0]`, `items[i]`, `items[0].name`,
`items[i].tags[0]`.

Numbers (3): `0`, `42`, `3.14`, mixed `2 + 0.5`.

Parens (2): `(a)`, `(a + b) * c`.

Back-compat shape preservation (5): `score`, `player.health`,
`!loading`, `select(item)`, `{ active: is_on }` — all return v0.7 AST
shapes unchanged.

### Applier tests (+20)

Arithmetic (5): `2+3=5`, `10-3=7`, `4*5=20`, `20/4=5`, `10%3=1`,
`5+'x' → null + warn captured`, `5/0 → null + warn`.

Comparison (5): `5>3=true`, `3>5=false`, `5>=5=true`,
`'a'<'b'=true`, `null > 5 → null + warn`.

Equality (4): `1==1=true`, `1!=2=true`, `null==null=true`,
`selected_item == null` (no warn even when types differ).

Logical (3): `0 && side → side not evaled`, `1 || side → side not
evaled`, `1 && 2 = 2`.

Ternary (2): `true ? 'a' : 'b' = 'a'`, false branch.

Indexing (1): `array[2]`, `dict['key']`, `array[100] → null (no warn)`.

### Integration tests (+5)

- `<div v-if="hp > 0">alive</div>` — state-set `hp=0` removes element.
- `<span>{{ items[selected_index].name }}</span>` — changing
  `selected_index` re-renders.
- `<div :class="{ low: hp < 25 }">` — toggles on `hp` change.
- `<li @click="select(items[i])">` — clicking emits item_clicked with
  correct per-clone index.
- `:class="['badge', is_rare ? 'rare' : 'common']"` — flips on `is_rare`
  change.

## §8 — Phasing

Single bundled PR. Tasks:

1. Logger injection (`_on_warning`) in `GmlBindingApplier` (1 test)
2. AST + parser scaffold: number literals, parens, unary, postfix-index (~6 tests)
3. Arithmetic operators + applier eval (~7 tests)
4. Comparison + equality (~6 tests)
5. Logical + ternary (~5 tests)
6. Integration tests + sample tweak (5 tests + simplify inventory demo.gd to drop precomputed booleans where operators now suffice)
7. Docs update + `CHANGELOG.md` 0.8.0 entry
8. Version bump

## Out of scope (deferred)

- Free function calls (`Math.floor`, `str`).
- Method calls / property reads beyond dotted paths + array indexing.
- Float modulo (`fposmod` semantics) — `%` coerces to int.
- Bitwise operators (`& | ^ << >>`).
- Optional chaining (`?.`).
- Nullish coalescing (`??`).
- Spread / rest.

## Known unknowns

- **Parser perf on deeply nested expressions.** Hand-rolled recursive
  descent is O(n) but stack depth grows with nesting. v0.8 ships without
  a depth limit; if abuse happens, add one.
- **Operator precedence "felt right" by Vue users.** This spec matches
  JS/Vue convention. If an author writes `a + b * c` expecting
  left-to-right reading, they get JS semantics (`a + (b * c)`). Document
  prominently in `docs/bindings.md`.
- **Index out-of-bounds silent null.** Decided against warning because
  v-for clones can transiently index `items[i]` where `i` is the loop
  index for an item that's about to be removed during reconciliation
  (relevant when v0.8.1 ships :key support). Worth re-evaluating then.
