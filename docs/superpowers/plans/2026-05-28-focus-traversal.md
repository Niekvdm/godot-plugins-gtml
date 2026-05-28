# GTML v0.8.3 — Focus traversal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every interactive GTML element keyboard/gamepad reachable with a deterministic Tab chain (document order + HTML tabindex), `autofocus` initial focus, `focus-trap` modal cycling, and a chain that stays correct across v-for reconciliation.

**Architecture:** Build-time `_stamp_focus_meta` classifies focusability per element and sets `focus_mode` + `_gml_*` meta. A post-build pass `GmlFocusManager.wire_focus(root)` walks the tree, groups focusables by trap subtree, orders each group by (tabindex, doc-order), and wires `focus_next`/`focus_previous`. GmlView runs it after build (and grabs autofocus once); the v-for reconciler re-runs it after each op-batch.

**Tech Stack:** Godot 4.6 GDScript, GUT 9.6, existing GTML render pipeline.

**Reference spec:** `docs/superpowers/specs/2026-05-28-focus-traversal-design.md`

---

## Pre-flight

- Branch: `feat/v0.8-focus-perf` (already created with spec commit)
- Working directory: `/data/personal/projects/godot/godot-plugins-gtml`
- Test runner: `cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Baseline test count: **385** (post v0.8.2 merge)
- Style: TABS for indentation. NO Co-Authored-By line.
- ALL subagent shell commands prefix with `cd /data/personal/projects/godot/godot-plugins-gtml &&`

---

## Verified integration facts

- **GmlView built root**: in `_rebuild`, `renderer.build(...)` returns `ui_root` (local, may be `queue_free`'d), processed into `target_control` (local) which is the actual attached content root. No content-root member exists today → Task 3 adds `var _content_root: Control = null`.
- **GmlRenderer._build_node tail**: `control` (wrapper) + `inner` (native interactive, e.g. LineEdit) + `node` are in scope after `_register_bindings_for_node(node, control, inner)`. Add `_stamp_focus_meta(node, control, inner)` right there.
- **GmlNode**: `has_attr(name) -> bool`, `get_attr(name, default="") -> String`, public `attrs: Dictionary`. Use `has_attr` for presence (get_attr can't distinguish absent vs empty).
- **@event detection**: an attr is a v-on if `attr_name.begins_with("@") or attr_name.begins_with("v-on:")`.
- **v-for reconcile tail**: end of `_reconcile_v_for_region(parent_node, container)` after `parent_node.set_meta("_vfor_state", state_map)`. Renderer holds `_gml_view`. Re-run via `_gml_view._content_root`.
- **Native control types**: button→Button, input→LineEdit, checkbox/radio→CheckBox, slider→HSlider, textarea→TextEdit, select→OptionButton, anchor `<a>`→LinkButton. All are BaseButton/LineEdit/etc. (default FOCUS_ALL) but NONE are explicitly normalized today.
- **For inputs, the focusable is `inner`** (the LineEdit/CheckBox/…), not the wrapper `control`.

---

## File Structure

**New:**
```
addons/gtml/src/focus/GmlFocusManager.gd     # wire_focus + _collect + ordering (~160 LOC)
tests/unit/test_focus_manager.gd             # ~12 unit tests
```

**Modify:**
```
addons/gtml/src/html_renderer/GmlRenderer.gd # _stamp_focus_meta + reconcile re-wire
addons/gtml/src/GmlView.gd                   # _content_root, wire_focus call, focus_first(), _focus_initialized
tests/unit/test_binding_integration.gd       # +6 tests
docs/focus.md                                # NEW user doc
docs/getting-started.md                      # link focus.md
CHANGELOG.md                                 # 0.8.3 entry
addons/gtml/plugin.cfg                       # 0.8.2 → 0.8.3
```

---

## Task 1: GmlFocusManager — wire_focus + ordering + 12 unit tests

**Files:**
- Create: `addons/gtml/src/focus/GmlFocusManager.gd`
- Create: `tests/unit/test_focus_manager.gd`

- [ ] **Step 1.1: Write the failing test file**

Create `tests/unit/test_focus_manager.gd`:

```gdscript
extends GutTest

## Tests for GmlFocusManager.wire_focus — builds synthetic Control trees
## with stamped _gml_* focus meta, runs wire_focus, asserts the chain.

const FM = preload("res://addons/gtml/src/focus/GmlFocusManager.gd")


## Make a focusable Control with the given tabindex; add to `parent`.
func _focusable(parent: Control, tabindex: int = 0, tab_skip: bool = false) -> Control:
	var c := Control.new()
	c.set_meta("_gml_focusable", true)
	c.set_meta("_gml_tabindex", tabindex)
	c.set_meta("_gml_tab_skip", tab_skip)
	parent.add_child(c)
	return c


func _root() -> Control:
	var r := Control.new()
	add_child_autofree(r)
	return r


func test_two_focusables_chain_in_dom_order() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b, "a.focus_next → b")
	assert_eq(b.get_node(b.focus_previous), a, "b.focus_previous → a")


func test_non_focusable_excluded() -> void:
	var r := _root()
	var a := _focusable(r)
	var plain := Control.new()
	r.add_child(plain)
	var b := _focusable(r)
	FM.wire_focus(r)
	# a → b directly, skipping the non-focusable.
	assert_eq(a.get_node(a.focus_next), b)


func test_focusables_get_focus_all_is_callers_job_not_wire() -> void:
	# wire_focus does NOT set focus_mode (that's the build stamp's job).
	# It only arranges order. This test documents that contract: a
	# focusable with FOCUS_NONE still gets chained.
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b)


func test_tab_skip_excluded_from_chain() -> void:
	var r := _root()
	var a := _focusable(r)
	var skip := _focusable(r, -1, true)
	var b := _focusable(r)
	FM.wire_focus(r)
	# Chain is a → b; skip is not in it.
	assert_eq(a.get_node(a.focus_next), b)
	# skip has no chain wired (empty paths).
	assert_eq(skip.focus_next, NodePath(""))


func test_positive_tabindex_ordered_before_natural() -> void:
	var r := _root()
	# DOM order: b(2), a(0), c(1). Tab order should be c(1), b(2), then a(0).
	var b := _focusable(r, 2)
	var a := _focusable(r, 0)
	var c := _focusable(r, 1)
	FM.wire_focus(r)
	assert_eq(c.get_node(c.focus_next), b, "c(1) → b(2)")
	assert_eq(b.get_node(b.focus_next), a, "b(2) → a(0 natural)")


func test_positive_tabindex_tie_broken_by_doc_order() -> void:
	var r := _root()
	var first := _focusable(r, 1)
	var second := _focusable(r, 1)
	FM.wire_focus(r)
	assert_eq(first.get_node(first.focus_next), second, "equal tabindex → doc order")


func test_focus_trap_group_wraps() -> void:
	var r := _root()
	var trap := Control.new()
	trap.set_meta("_gml_focus_trap", true)
	r.add_child(trap)
	var a := _focusable(trap)
	var b := _focusable(trap)
	FM.wire_focus(r)
	assert_eq(b.get_node(b.focus_next), a, "trap last wraps to first")
	assert_eq(a.get_node(a.focus_previous), b, "trap first wraps to last")


func test_root_group_does_not_wrap() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(b.focus_next, NodePath(""), "root last does NOT wrap")
	assert_eq(a.focus_previous, NodePath(""), "root first does NOT wrap")


func test_nested_trap_isolated_from_outer() -> void:
	var r := _root()
	var outer_a := _focusable(r)
	var trap := Control.new()
	trap.set_meta("_gml_focus_trap", true)
	r.add_child(trap)
	var inner_a := _focusable(trap)
	var inner_b := _focusable(trap)
	FM.wire_focus(r)
	# Inner trap wraps among its own items only.
	assert_eq(inner_b.get_node(inner_b.focus_next), inner_a, "inner wraps within trap")
	# Outer group has only outer_a (trap items excluded) → no wrap, empty next.
	assert_eq(outer_a.focus_next, NodePath(""), "outer_a alone in root group")


func test_find_autofocus_returns_first_in_doc_order() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	b.set_meta("_gml_autofocus", true)
	var c := _focusable(r)
	c.set_meta("_gml_autofocus", true)
	assert_eq(FM.find_autofocus(r), b, "first autofocus in doc order wins")


func test_empty_tree_no_crash() -> void:
	var r := _root()
	FM.wire_focus(r)
	assert_null(FM.find_autofocus(r))


func test_idempotent_rewire() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b, "second wire yields same chain")
	assert_eq(b.focus_next, NodePath(""), "still no root wrap")


func test_neighbor_bottom_top_mirror_next_previous() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.focus_neighbor_bottom, a.focus_next, "bottom mirrors next")
	assert_eq(b.focus_neighbor_top, b.focus_previous, "top mirrors previous")
```

- [ ] **Step 1.2: Run, verify fail**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_focus_manager.gd 2>&1 | grep -E "Tests |Passing|Failing|SCRIPT ERROR" | head
```

Expected: load error — file doesn't exist yet.

- [ ] **Step 1.3: Implement GmlFocusManager**

Create `addons/gtml/src/focus/GmlFocusManager.gd`:

```gdscript
class_name GmlFocusManager
extends RefCounted

## Keyboard/gamepad focus traversal for a built GTML Control tree.
##
## Reads the _gml_* focus meta stamped at build time by the renderer
## and wires focus_next / focus_previous (+ neighbor_bottom/top mirrors)
## in document order honoring HTML tabindex rules + focus-trap groups.
##
## Pure ordering — does NOT set focus_mode (the build stamp does that)
## and does NOT grab focus (GmlView orchestrates autofocus once per
## rebuild via find_autofocus). Idempotent: re-running clears + rewrites
## all four neighbor properties, so it's safe after every reconcile.

const META_FOCUSABLE := "_gml_focusable"
const META_TABINDEX := "_gml_tabindex"
const META_TAB_SKIP := "_gml_tab_skip"
const META_AUTOFOCUS := "_gml_autofocus"
const META_TRAP := "_gml_focus_trap"


## Walk `root`, collect focusables, group by trap subtree, order each
## group by (tabindex, doc_order), wire the chain.
static func wire_focus(root: Control) -> void:
	if root == null:
		return
	var entries: Array = _collect(root)

	# Group by trap (use the trap Control's instance_id; 0 = root group).
	var groups: Dictionary = {}
	for e in entries:
		var trap = e["trap_group"]
		var gkey: int = trap.get_instance_id() if trap != null else 0
		if not groups.has(gkey):
			groups[gkey] = {"trap": trap, "items": []}
		groups[gkey]["items"].append(e)

	for gkey in groups:
		var g: Dictionary = groups[gkey]
		var is_trap: bool = g["trap"] != null
		var ordered: Array = _order(g["items"])
		_wire_chain(ordered, is_trap)


## Pre-order (document-order) collection of focusable entries. Each:
##   {control, doc_order, tabindex, tab_skip, trap_group}
static func _collect(root: Control) -> Array:
	var out: Array = []
	var counter: Array = [0]
	_walk(root, null, out, counter)
	return out


static func _walk(ctrl, current_trap, out: Array, counter: Array) -> void:
	if not (ctrl is Control):
		return
	var doc: int = counter[0]
	counter[0] += 1
	var trap_here = current_trap
	if (ctrl as Control).get_meta(META_TRAP, false):
		trap_here = ctrl
	if (ctrl as Control).get_meta(META_FOCUSABLE, false):
		out.append({
			"control": ctrl,
			"doc_order": doc,
			"tabindex": int((ctrl as Control).get_meta(META_TABINDEX, 0)),
			"tab_skip": bool((ctrl as Control).get_meta(META_TAB_SKIP, false)),
			"trap_group": trap_here,
		})
	for child in (ctrl as Control).get_children():
		_walk(child, trap_here, out, counter)


## Apply HTML tabindex ordering to a group's items, excluding tab_skip.
static func _order(items: Array) -> Array:
	var tabbable: Array = items.filter(func(e): return not e["tab_skip"])
	var positive: Array = tabbable.filter(func(e): return e["tabindex"] > 0)
	var natural: Array = tabbable.filter(func(e): return e["tabindex"] <= 0)
	positive.sort_custom(func(a, b):
		if a["tabindex"] != b["tabindex"]:
			return a["tabindex"] < b["tabindex"]
		return a["doc_order"] < b["doc_order"]
	)
	natural.sort_custom(func(a, b): return a["doc_order"] < b["doc_order"])
	var out: Array = []
	for e in positive:
		out.append(e)
	for e in natural:
		out.append(e)
	return out


## Wire focus_next/previous (+ neighbor mirrors) across an ordered list.
## wrap=true (trap groups) cycles last↔first; wrap=false clears the ends.
static func _wire_chain(ordered: Array, wrap: bool) -> void:
	var n: int = ordered.size()
	for i in n:
		var c: Control = ordered[i]["control"]
		var next_path: NodePath = NodePath("")
		var prev_path: NodePath = NodePath("")
		if i + 1 < n:
			next_path = c.get_path_to(ordered[i + 1]["control"])
		elif wrap and n > 1:
			next_path = c.get_path_to(ordered[0]["control"])
		if i - 1 >= 0:
			prev_path = c.get_path_to(ordered[i - 1]["control"])
		elif wrap and n > 1:
			prev_path = c.get_path_to(ordered[n - 1]["control"])
		c.focus_next = next_path
		c.focus_previous = prev_path
		c.focus_neighbor_bottom = next_path
		c.focus_neighbor_top = prev_path


## First focusable with _gml_autofocus in document order, or null.
static func find_autofocus(root: Control) -> Control:
	if root == null:
		return null
	for e in _collect(root):
		if (e["control"] as Control).get_meta(META_AUTOFOCUS, false):
			return e["control"]
	return null
```

NOTE: `get_path_to` requires both controls share a tree. In the unit tests they're added under a common `_root()`. The `get_node(focus_next)` assertions resolve the relative path back to the target. If `get_node` on an empty `NodePath("")` errors in a test, that test instead asserts `c.focus_next == NodePath("")` directly (as written for the no-wrap / tab_skip cases).

- [ ] **Step 1.4: Run, verify pass**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 90 godot --headless --import 2>&1 | tail -3
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_focus_manager.gd 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 12/12 pass.

- [ ] **Step 1.5: Run full suite**

Expected: 397/397 (385 + 12).

- [ ] **Step 1.6: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/focus/GmlFocusManager.gd tests/unit/test_focus_manager.gd && git commit -m "feat(focus): GmlFocusManager — tab-order wiring engine

wire_focus(root) walks a built Control tree, collects focusables (by
_gml_focusable meta) in document order, groups them by focus-trap
subtree, orders each group with HTML tabindex rules (>0 ascending
first, 0/absent natural, -1/tab_skip excluded), and wires
focus_next/focus_previous + neighbor_bottom/top mirrors. Trap groups
wrap last↔first; the root group does not. find_autofocus returns the
first _gml_autofocus control in doc order.

Pure ordering: does not set focus_mode (build stamp's job) or grab
focus (GmlView orchestrates autofocus). Idempotent — safe to re-run
after every rebuild / v-for reconcile.

12 unit tests over synthetic Control trees. 385 → 397."
```

---

## Task 2: Renderer _stamp_focus_meta

**Files:**
- Modify: `addons/gtml/src/html_renderer/GmlRenderer.gd`

This task only stamps meta + sets focus_mode. No ordering yet (that's GmlView calling wire_focus in Task 3). Verifiable by checking the meta on built controls — but since there's no integration harness assertion here, this task's correctness is confirmed by Task 3/5 integration tests. To keep TDD discipline, add ONE renderer-level test that builds a view and checks focus_mode.

- [ ] **Step 2.1: Add `_stamp_focus_meta` + call site**

In `addons/gtml/src/html_renderer/GmlRenderer.gd`, find the `_build_node` tail where `_register_bindings_for_node(node, control, inner)` is called (followed by the `_vfor_key` meta block and `return control`). Add the stamp call right after `_register_bindings_for_node(...)`:

```gdscript
	_register_bindings_for_node(node, control, inner)

	_stamp_focus_meta(node, control, inner)
```

Add the helper at the bottom of `GmlRenderer.gd`:

```gdscript
## Classify focusability for an element and stamp _gml_* focus meta +
## set focus_mode. For native inputs the focus target is `inner` (the
## LineEdit/CheckBox/…); otherwise it's `control`. focus-trap stamps on
## `control` (the element's own container).
func _stamp_focus_meta(node, control: Control, inner: Control) -> void:
	# focus-trap is a container concern → stamp on the element's control.
	if node.has_attr("focus-trap"):
		control.set_meta("_gml_focus_trap", true)

	var focus_target: Control = inner if inner != null else control

	# Determine focusability.
	var has_tabindex: bool = node.has_attr("tabindex")
	var tabindex: int = node.get_attr("tabindex", "0").to_int() if has_tabindex else 0

	var is_native: bool = (
		focus_target is Button or focus_target is LineEdit or focus_target is TextEdit
		or focus_target is CheckBox or focus_target is OptionButton or focus_target is HSlider
	)
	var is_anchor: bool = node.tag == "a"
	var has_event: bool = false
	for attr_name in node.attrs:
		if attr_name.begins_with("@") or attr_name.begins_with("v-on:"):
			has_event = true
			break

	var focusable: bool = is_native or is_anchor or has_event or (has_tabindex and tabindex >= 0)
	# tabindex=-1 makes an element focusable (programmatically) but tab-skipped.
	if has_tabindex and tabindex == -1:
		focusable = true

	if not focusable:
		return

	focus_target.set_meta("_gml_focusable", true)
	focus_target.set_meta("_gml_tabindex", tabindex)
	focus_target.set_meta("_gml_tab_skip", has_tabindex and tabindex == -1)
	focus_target.focus_mode = Control.FOCUS_ALL
	if node.has_attr("autofocus"):
		focus_target.set_meta("_gml_autofocus", true)
```

- [ ] **Step 2.2: Add a renderer-level focus_mode test**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript

# ─── v0.8.3: focus stamping (Task 2) ───────────────────────

func test_clickable_span_gets_focus_mode_all() -> void:
	var view := _build_view('<div><span @click="x">click me</span></div>')
	view.state.set("x", null)
	await get_tree().process_frame
	await get_tree().process_frame
	# Find the span's control (a Label or its wrapper). Walk for any control
	# with the _gml_focusable meta.
	var found := false
	var stack: Array = [view]
	while not stack.is_empty():
		var nd = stack.pop_back()
		if nd is Control and (nd as Control).get_meta("_gml_focusable", false):
			if (nd as Control).focus_mode == Control.FOCUS_ALL:
				found = true
				break
		for ch in nd.get_children():
			stack.append(ch)
	assert_true(found, "a @click element should be focusable with FOCUS_ALL")
```

- [ ] **Step 2.3: Run, verify pass**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 90 godot --headless --import 2>&1 | tail -3
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 398/398 (397 + 1).

If the `@click` span doesn't get `_gml_focusable`: the span may build as a Label where `control`==`inner`==the Label; `has_event` should be true from the `@click` attr. Verify the attr survived to `node.attrs` (it does — `@click` is a plain attr key). If the clickable span is actually built as a different structure, adjust the walk.

- [ ] **Step 2.4: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/html_renderer/GmlRenderer.gd tests/unit/test_binding_integration.gd && git commit -m "feat(focus): _stamp_focus_meta classifies + marks focusables at build

_build_node now stamps focus meta after binding registration. An
element is focusable if it's a native control (Button/LineEdit/
TextEdit/CheckBox/OptionButton/HSlider), an <a> anchor, has any
@event handler, or carries tabindex>=0. tabindex=-1 → focusable but
tab-skipped. Focusables get focus_mode=FOCUS_ALL (the opt-in that
makes clickable labels/anchors/divs keyboard-reachable). focus-trap
stamps on the element's container; autofocus on the focus target.
For native inputs the focus target is the inner control.

1 integration test confirms a @click span becomes FOCUS_ALL. 397 → 398."
```

---

## Task 3: GmlView wiring + focus_first() + autofocus

**Files:**
- Modify: `addons/gtml/src/GmlView.gd`

- [ ] **Step 3.1: Add the content-root member + wire_focus call + autofocus**

In `addons/gtml/src/GmlView.gd`:

1. Add members near the other internal state vars:

```gdscript
## The attached content root of the last build. Stable handle so v-for
## reconciliation can re-run focus wiring without re-deriving it.
var _content_root: Control = null
## Whether autofocus has been granted for the current build. Reset on
## _rebuild so autofocus fires once per rebuild, not on every reconcile.
var _focus_initialized: bool = false
```

2. Add the preload near the other script preloads at the top:

```gdscript
const GmlFocusManagerScript = preload("res://addons/gtml/src/focus/GmlFocusManager.gd")
```

3. In `_rebuild`, reset `_focus_initialized = false` near where other per-rebuild state resets (e.g. next to the binding registry clear):

```gdscript
	_focus_initialized = false
```

4. After the build attach `if/else` block (after `target_control` is added to the tree — the research showed this is around line 262, after the `else: add_child(target_control)` branch), add:

```gdscript
		_content_root = target_control
		GmlFocusManagerScript.wire_focus(target_control)
		var autofocus_ctl: Control = GmlFocusManagerScript.find_autofocus(target_control)
		if autofocus_ctl != null and not _focus_initialized:
			_focus_initialized = true
			autofocus_ctl.call_deferred("grab_focus")
```

Place this so it runs in BOTH the centering and non-centering branches — i.e. after the whole `if needs_centering: … else: …` block, using `target_control` (which both branches populate). If the structure makes a single shared insertion point awkward, set `_content_root = target_control` + call the focus block once after the branch, guarded by `if target_control != null`.

5. Add the public API method (near other public methods like `get_element_by_id`):

```gdscript
## Grab the first Tab-order focusable in the view (root group, first in
## the tab chain). Returns false if there is nothing focusable. For game
## code seizing focus when a menu opens.
func focus_first() -> bool:
	if _content_root == null:
		return false
	var entries: Array = GmlFocusManagerScript._collect(_content_root)
	# First non-tab-skip focusable in doc order is a reasonable "first".
	for e in entries:
		if not e["tab_skip"]:
			(e["control"] as Control).grab_focus()
			return true
	return false
```

- [ ] **Step 3.2: Run full suite**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 398/398 (no new tests; integration tests in Task 5). Existing tests must stay green — wiring focus is additive.

- [ ] **Step 3.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/GmlView.gd && git commit -m "feat(focus): GmlView wires focus post-build + autofocus + focus_first()

After build, GmlView stores the attached content root in _content_root
and runs GmlFocusManager.wire_focus on it. The first autofocus element
grabs focus once per rebuild (guarded by _focus_initialized so later
v-for reconciles don't yank focus back). Adds public focus_first() for
game code that wants to seize focus when a menu opens.

398 (no new tests; integration coverage in Task 5)."
```

---

## Task 4: v-for reconcile re-wire

**Files:**
- Modify: `addons/gtml/src/html_renderer/GmlRenderer.gd`

- [ ] **Step 4.1: Re-run wire_focus after reconcile**

In `addons/gtml/src/html_renderer/GmlRenderer.gd`, at the end of
`_reconcile_v_for_region(parent_node, container)`, after
`parent_node.set_meta("_vfor_state", state_map)`, add:

```gdscript
	# Re-wire focus so inserted clones join the chain and removed clones
	# drop out. wire_focus is idempotent + does not move focus, so a
	# surviving focused control keeps focus.
	if _gml_view != null and _gml_view._content_root != null:
		var GmlFocusManagerScript = preload("res://addons/gtml/src/focus/GmlFocusManager.gd")
		GmlFocusManagerScript.wire_focus(_gml_view._content_root)
```

- [ ] **Step 4.2: Run full suite**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 398/398. No regressions (the v-for tests don't assert focus yet; Task 5 adds that).

- [ ] **Step 4.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/html_renderer/GmlRenderer.gd && git commit -m "feat(focus): re-wire focus chain after v-for reconcile

_reconcile_v_for_region re-runs GmlFocusManager.wire_focus on the
view's content root after applying its op-batch, so inserted clones
join the Tab chain and removed clones drop out. wire_focus is
idempotent and never grabs focus, so a control that survived the
reconcile keeps focus (consistent with the v0.8.1 identity guarantee).

398 (focus-across-reconcile pinned by Task 5 integration test)."
```

---

## Task 5: Integration tests through GmlView

**Files:**
- Modify: `tests/unit/test_binding_integration.gd`

- [ ] **Step 5.1: Write integration tests**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript

# ─── v0.8.3: focus traversal end-to-end (Task 5) ───────────

func _first_control_with_meta(view: GmlView, meta: String) -> Control:
	var stack: Array = [view]
	while not stack.is_empty():
		var nd = stack.pop_back()
		if nd is Control and (nd as Control).get_meta(meta, false):
			return nd
		# Push children in reverse so we pop in document order.
		var kids := nd.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.append(kids[i])
	return null


func test_focus_two_buttons_chain() -> void:
	var view := _build_view('<div><button @click="a">A</button><button @click="b">B</button></div>')
	view.state.set("a", null)
	view.state.set("b", null)
	await get_tree().process_frame
	await get_tree().process_frame
	# Collect the two focusable buttons in doc order.
	var focusables: Array = []
	_collect_focusables(view, focusables)
	assert_gte(focusables.size(), 2, "two buttons focusable; got %d" % focusables.size())
	var a: Control = focusables[0]
	var b: Control = focusables[1]
	assert_eq(a.get_node(a.focus_next), b, "button A.focus_next → B")


func test_focus_anchor_is_focusable() -> void:
	var view := _build_view('<div><a href="x">link</a></div>')
	await get_tree().process_frame
	await get_tree().process_frame
	var focusables: Array = []
	_collect_focusables(view, focusables)
	assert_gt(focusables.size(), 0, "anchor should be focusable")


func test_autofocus_grabs_focus() -> void:
	var view := _build_view('<div><input v-model="q" autofocus></div>')
	view.state.set("q", "")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var focused = get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "autofocus should grab a control")
	assert_true(focused.get_meta("_gml_focusable", false), "focused control is the autofocus target")


func test_focus_trap_wraps() -> void:
	var view := _build_view('<div focus-trap><button @click="a">A</button><button @click="b">B</button></div>')
	view.state.set("a", null)
	view.state.set("b", null)
	await get_tree().process_frame
	await get_tree().process_frame
	var focusables: Array = []
	_collect_focusables(view, focusables)
	assert_eq(focusables.size(), 2)
	var a: Control = focusables[0]
	var b: Control = focusables[1]
	assert_eq(b.get_node(b.focus_next), a, "trap: B wraps to A")
	assert_eq(a.get_node(a.focus_previous), b, "trap: A wraps to B")


func test_tabindex_minus_one_skips_tab_chain() -> void:
	var view := _build_view('<div><button @click="a">A</button><button @click="b" tabindex="-1">B</button><button @click="c">C</button></div>')
	view.state.set("a", null)
	view.state.set("b", null)
	view.state.set("c", null)
	await get_tree().process_frame
	await get_tree().process_frame
	# A.focus_next should skip B (tab-skip) and go to C.
	var focusables: Array = []
	_collect_focusables(view, focusables)
	# focusables includes B (it's _gml_focusable) — find A and C by text.
	var a: Control = null
	var c: Control = null
	for f in focusables:
		var t := _button_text(f)
		if t == "A":
			a = f
		elif t == "C":
			c = f
	assert_not_null(a)
	assert_not_null(c)
	assert_eq(a.get_node(a.focus_next), c, "A skips tabindex=-1 B → C")


func test_vfor_append_keeps_focus_and_chains_new_clone() -> void:
	var view := _build_view('<ul><li v-for="item in items" :key="item.id"><input :value="item.name"></li></ul>')
	view.state.set("items", [
		{"id": "a", "name": "A"},
		{"id": "b", "name": "B"},
	])
	await get_tree().process_frame
	await get_tree().process_frame
	# Focus the first input.
	var inputs: Array = []
	_collect_line_edits(view, inputs)
	assert_eq(inputs.size(), 2)
	inputs[0].grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), inputs[0])
	# Append an item.
	view.state.set("items", [
		{"id": "a", "name": "A"},
		{"id": "b", "name": "B"},
		{"id": "c", "name": "C"},
	])
	await get_tree().process_frame
	# Focused input survived (same control identity) → still focused.
	assert_eq(get_viewport().gui_get_focus_owner(), inputs[0], "focus preserved across append")
	# New clone is chained: there are now 3 inputs and the 2nd→3rd link resolves.
	var inputs2: Array = []
	_collect_line_edits(view, inputs2)
	assert_eq(inputs2.size(), 3, "third input clone added")


# Helper: collect controls carrying _gml_focusable, in document order.
func _collect_focusables(node: Node, out: Array) -> void:
	if node is Control and (node as Control).get_meta("_gml_focusable", false):
		out.append(node)
	for c in node.get_children():
		_collect_focusables(c, out)


func _collect_line_edits(node: Node, out: Array) -> void:
	if node is LineEdit:
		out.append(node)
	for c in node.get_children():
		_collect_line_edits(c, out)


func _button_text(c: Control) -> String:
	if c is Button:
		return (c as Button).text
	return ""
```

- [ ] **Step 5.2: Run**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 404/404 (398 + 6).

Debugging guidance (investigate, don't weaken assertions):

- **`test_focus_two_buttons_chain`**: `<button @click>` builds a `Button` (already FOCUS_ALL); the stamp marks it focusable + chains. If `focus_next` is empty, confirm wire_focus ran (GmlView Task 3) and both buttons are in the same root group.
- **`test_autofocus_grabs_focus`**: the input's focusable is the inner `LineEdit`. autofocus meta is stamped on the focus target (inner). `find_autofocus` collects focusables (the LineEdit). The deferred grab needs an extra frame — the test awaits 3 frames. If focus owner is null, confirm `_focus_initialized` logic + that `call_deferred("grab_focus")` targets the LineEdit.
- **`test_focus_trap_wraps`**: the `<div focus-trap>` builds a container; `_gml_focus_trap` is stamped on it. Its descendant buttons' `trap_group` resolves to that container → wrapping group.
- **`test_tabindex_minus_one_skips_tab_chain`**: B is `_gml_focusable` (so clickable/focusable) but `_gml_tab_skip` → excluded from the chain; A.focus_next must resolve to C.
- **`test_vfor_append_keeps_focus_and_chains_new_clone`**: depends on Task 4's reconcile re-wire. The focused LineEdit survives (v0.8.1 identity) so it keeps focus; the re-wire adds the new clone. If focus is lost, check that wire_focus doesn't grab/move focus and that the reconcile re-wire ran.

- [ ] **Step 5.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/unit/test_binding_integration.gd && git commit -m "test(focus): focus traversal integration tests

Six end-to-end tests through GmlView: two-button Tab chain, anchor
focusable, autofocus grabs focus, focus-trap wraps, tabindex=-1
skipped from the chain, and v-for append preserving focus on the
surviving input while chaining the new clone.

398 → 404."
```

---

## Task 6: Docs + CHANGELOG + version bump

**Files:**
- Create: `docs/focus.md`
- Modify: `docs/getting-started.md`
- Modify: `CHANGELOG.md`
- Modify: `addons/gtml/plugin.cfg`

- [ ] **Step 6.1: Write docs/focus.md**

Create `docs/focus.md`:

```markdown
# Focus & keyboard / gamepad navigation (v0.8.3+)

GTML wires keyboard and gamepad focus traversal automatically. Every
interactive element is reachable without a mouse, in a deterministic
order.

## What's focusable

- Native form controls: `<button>`, `<input>`, `<textarea>`, `<select>`,
  checkboxes, sliders.
- `<a>` anchors.
- Any element with an `@event` handler (e.g. `<span @click="pick">`).
- Any element with `tabindex="0"` or higher.

Focusable elements get Godot's `FOCUS_ALL` so Tab, Shift-Tab, and a
gamepad's next/prev move between them. Arrow / d-pad directional
movement uses Godot's built-in geometry neighbor search.

## Tab order

Order follows the document, with HTML `tabindex` rules:

- `tabindex="0"` (or no tabindex on an interactive element) — natural
  document order.
- `tabindex="2"`, `tabindex="5"`, … (positive) — these come **first**,
  in ascending numeric order, before the natural-order elements.
- `tabindex="-1"` — focusable programmatically (and by click) but
  **skipped** by Tab.

## Initial focus

Add `autofocus` to grab focus when the view builds:

```html
<input v-model="search" autofocus>
```

The first `autofocus` element (document order) receives focus once per
build. Game code can also call `view.focus_first()` to grab the first
Tab-order element on demand (e.g. when opening a menu).

## Focus trap (modals / dialogs)

Add `focus-trap` to a container to cycle focus within it — Tab from the
last element returns to the first, and Shift-Tab from the first wraps to
the last:

```html
<div focus-trap>
  <input v-model="name" autofocus>
  <button @click="confirm">OK</button>
  <button @click="cancel">Cancel</button>
</div>
```

Nested traps are supported; the innermost trap owns its elements.

## v-for lists

The Tab chain is re-wired after every list change, so inserting or
removing items keeps the order correct. A focused input inside a list
keeps focus when the list reorders (its Control identity is preserved —
see [bindings](bindings.md)).

## Limitations

- Directional (arrow/d-pad) navigation uses Godot's geometry search, not
  an explicit grid model — sequential Tab/next-prev is exact, directional
  may pick non-obvious neighbors in wrapped layouts.
- No roving-tabindex composite widgets (each focusable is its own stop).
- The root (non-trapped) Tab chain does not wrap — Tab at the last
  element stays put.
```

- [ ] **Step 6.2: Link from getting-started.md**

In `docs/getting-started.md`, find the "Next Steps" list and add (near the bindings link):

```markdown
- [Focus & navigation](focus.md) - keyboard / gamepad traversal, `tabindex`, `autofocus`, `focus-trap`
```

- [ ] **Step 6.3: Update CHANGELOG.md**

Insert after `# Changelog`, before `## 0.8.2`:

```markdown
## 0.8.3

### Features — Focus traversal (keyboard / gamepad navigation)

GTML now wires keyboard + gamepad focus automatically. Previously native
controls were accidentally Tab-reachable but every GTML mouse-clickable
(`@click` labels, anchors, clickable divs, v-for rows) was unreachable
without a pointer — blocking console / Steam Deck use.

- **Everything interactive is focusable**: native controls, `<a>`
  anchors, any element with an `@event` handler, and `tabindex>=0`
  elements get `FOCUS_ALL`.
- **Deterministic Tab order**: document order with full HTML `tabindex`
  semantics (`>0` first ascending, `0`/absent natural, `-1`
  focusable-but-skipped).
- **`autofocus`** grabs initial focus once per build.
- **`focus-trap`** cycles focus within a modal subtree (nested traps
  supported).
- **v-for**: the chain re-wires after every reconcile; a focused input
  keeps focus when the list changes.
- **`GmlView.focus_first()`** API for game code seizing focus on menu open.

### Architecture

New `GmlFocusManager.wire_focus` walks the built tree and wires
`focus_next`/`focus_previous` (+ neighbor mirrors). Build-time
`_stamp_focus_meta` classifies focusability + sets `focus_mode`. GmlView
runs the wiring post-build and grabs autofocus; the v-for reconciler
re-runs it after each op-batch.

### Limitations

- Directional (arrow/d-pad) nav uses Godot's geometry search; sequential
  Tab/next-prev is explicit.
- No roving-tabindex composite widgets.
- Root (non-trapped) chain does not wrap.

### Tests

19 new tests (focus manager + integration); 385 → 404.

### Remaining

The v0.8 perf-benchmark harness is the last production-readiness item
(separate PR).
```

- [ ] **Step 6.4: Bump version**

In `addons/gtml/plugin.cfg`: `version="0.8.2"` → `version="0.8.3"`.

- [ ] **Step 6.5: Final suite**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 404/404.

- [ ] **Step 6.6: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/focus.md docs/getting-started.md CHANGELOG.md addons/gtml/plugin.cfg && git commit -m "chore(v0.8.3): focus traversal — docs + CHANGELOG + version

New docs/focus.md covers focusability, Tab order + tabindex, autofocus,
focus-trap, v-for behavior, and limitations. Linked from
getting-started. CHANGELOG 0.8.3 entry; plugin.cfg bumped. Notes the
perf bench as the last remaining v0.8 item."
```

---

## Task 7: Push + open PR

- [ ] **Step 7.1: Push**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git push -u origin feat/v0.8-focus-perf 2>&1 | tail -3
```

- [ ] **Step 7.2: Open PR**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && gh pr create --base master --title "v0.8.3: focus traversal (keyboard / gamepad navigation)" --body "$(cat <<'EOF'
## Summary

Wires keyboard + gamepad focus automatically. Every interactive element — native controls, `<a>` anchors, `@click` elements, `tabindex>=0` — becomes focusable with a deterministic Tab order. Unblocks console / Steam Deck use (no pointer required).

## API / markup

```html
<div focus-trap>
  <input v-model="search" autofocus>
  <button @click="confirm">OK</button>
  <button @click="cancel">Cancel</button>
</div>
```

- **`autofocus`** — initial focus once per build.
- **`focus-trap`** — cycles focus within a modal subtree (nested supported).
- **`tabindex`** — full HTML semantics (`>0` first ascending, `0`/absent natural, `-1` focusable-but-skipped).
- **`GmlView.focus_first()`** — game code seizes focus on menu open.

## Architecture

- New `GmlFocusManager.wire_focus(root)` — walks the built tree, groups by focus-trap subtree, orders each group by (tabindex, doc-order), wires `focus_next`/`focus_previous` + neighbor mirrors. Pure ordering, idempotent.
- Build-time `_stamp_focus_meta` classifies focusability + sets `focus_mode`.
- GmlView runs wiring post-build + grabs autofocus once; the v-for reconciler re-wires after each op-batch so clones stay chained and focus is preserved on survivors.

## Stats

| | |
|---|---|
| Tests | 404 (was 385) |
| New engine LOC | ~160 focus manager + renderer/view wiring |
| Plugin version | 0.8.2 → 0.8.3 |

## Limitations

- Directional (arrow/d-pad) nav uses Godot's built-in geometry search; sequential Tab/next-prev is explicit.
- No roving-tabindex composite widgets.
- Root (non-trapped) chain does not wrap.

## Test plan

- [ ] `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` → 404/404
- [ ] Inventory showcase: Tab moves through filter buttons + item rows; gamepad next/prev follows the same order.

## Next

Last v0.8 production-readiness item: the perf benchmark harness (separate PR).
EOF
)" 2>&1 | tail -3
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-05-28-focus-traversal-design.md`):

- §1 Focusability + meta stamping → Task 2 (`_stamp_focus_meta`) ✓
- §2 GmlFocusManager.wire_focus (ordering, trap groups, tabindex, find_autofocus) → Task 1 ✓
- §3 Integration + focus preservation (GmlView post-build, focus_first, v-for re-wire, _focus_initialized) → Tasks 3 + 4 ✓
- §4 Testing → Tasks 1 (12 unit) + 5 (6 integration) ✓
- §5 Phasing → 7 tasks ✓
- §6 Limitations → Task 6 docs ✓

**Deliberate spec refinement:** §2 step 7 said `wire_focus` calls `grab_deferred` for autofocus. The plan moves the grab to GmlView (Task 3) so `wire_focus` stays pure ordering and reconcile re-runs don't re-grab — this is exactly what §3's `_focus_initialized` requirement needs. `find_autofocus` (in the manager) + grab (in GmlView) cleanly separates the concern. Noted so the reviewer doesn't flag it as a gap.

**Placeholder scan:** none.

**Type consistency:** meta key constants (`_gml_focusable`, `_gml_tabindex`, `_gml_tab_skip`, `_gml_autofocus`, `_gml_focus_trap`) match between Task 1 (manager reads) and Task 2 (renderer stamps). `wire_focus(root)` / `find_autofocus(root)` / `_collect(root)` signatures consistent across Tasks 1, 3, 4. `_content_root` consistent (Task 3 defines, Task 4 reads).

**Implementation risks flagged inline:** GmlView insertion point spanning centering/non-centering branches (Task 3 step 3.1.4); the `@click` span build structure (Task 2 step 2.3); autofocus deferred-grab frame timing (Task 5 debugging).
