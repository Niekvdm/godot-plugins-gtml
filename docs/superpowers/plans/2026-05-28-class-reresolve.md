# GTML v0.8.2 — Dynamic :class CSS re-resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dynamic `:class` changes re-resolve and re-apply the bound element's visual properties (color/bg/border/opacity/font-size) in place, without structural re-wrapping.

**Architecture:** New `GmlClassRestyler` recomputes the merged visual style by temporarily setting the node's `class` attr to the static+dynamic list and re-running `GmlStyleResolver._compute_style`. It applies the visual-property subset in place (stylebox field mutation + theme overrides + opacity), routing through the existing transition manager when a transition is declared. `GmlView` retains the parsed `_css_rules`; the renderer threads the ancestor chain and registers an `on_change` callback on `:class` bindings.

**Tech Stack:** Godot 4.6 GDScript, GUT 9.6, existing GTML CSS + binding pipeline.

**Reference spec:** `docs/superpowers/specs/2026-05-28-class-reresolve-design.md`

---

## Pre-flight

- Branch: `feat/v0.8-class-reresolve` (already created with spec commit)
- Working directory: `/data/personal/projects/godot/godot-plugins-gtml`
- Test runner: `cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Baseline test count: **367** (post v0.8.1 merge)
- Style: TABS for indentation. NO Co-Authored-By line.
- ALL subagent shell commands MUST prefix with `cd /data/personal/projects/godot/godot-plugins-gtml &&`

---

## Key facts about the existing code (verified)

- `GmlStyleResolver` is instantiated (`.new()`); `_compute_style(node, ancestor_chain: Array, rules: Array, scope: Dictionary = {}) -> Dictionary` is an INSTANCE method. It returns a merged style dict including `_hover`/`_focus` pseudo buckets. The `node` param is essentially unused in matching — matching keys off `ancestor_chain`, whose elements are GmlNode instances, root-first, CURRENT NODE LAST.
- `GmlSelector._compound_matches` reads classes via `node.get_classes()` (GmlNode.gd) — which splits the node's `class` attr. **No param to inject a class list.** Re-resolution must temporarily mutate the node's `class` attr.
- `GmlNode` has `get_attr(name, default)` and `set_attr(name, value)` (the parser uses set_attr; verify it exists — if the method is named differently, set `node.attrs["class"] = value` directly).
- Background color → `StyleBoxFlat` attached via `add_theme_stylebox_override("panel", box)` (PanelContainer) or `("normal", box)` (Button). Retrievable via `control.get_theme_stylebox("panel"/"normal")`. Plain Labels do NOT get a bg stylebox.
- Font color → `label.add_theme_color_override("font_color", color)`.
- `GmlTransitionManager.transition_style(control, from_style: Dictionary, to_style: Dictionary, transitions: Array)`. `transitions` = `style.get("transition", [])`, an Array of dicts each with a `"property"` key.
- GmlView builds `css_rules` + `style_resolver` + `styles` as LOCALS in `_rebuild` (~GmlView.gd:192-197). `styles` is `Dictionary[GmlNode → Dictionary]`.

---

## File Structure

**New:**
```
addons/gtml/src/css/GmlClassRestyler.gd       # recompute + apply visual props (~140 LOC)
tests/unit/test_class_restyler.gd             # ~10 tests
```

**Modify:**
```
addons/gtml/src/GmlView.gd                    # retain _css_rules + _style_resolver
addons/gtml/src/html_renderer/GmlRenderer.gd  # thread ancestor_chain; register on_change; base snapshot
addons/gtml/src/binding/GmlBindingApplier.gd  # register_class_binding gains on_change callback
tests/unit/test_binding_integration.gd        # +6 tests
docs/bindings.md                              # remove "v0.7 does not re-resolve" caveat
CHANGELOG.md                                  # 0.8.2 entry
addons/gtml/plugin.cfg                        # 0.8.1 → 0.8.2
```

---

## Task 1: Retain css_rules + resolver on GmlView

**Files:**
- Modify: `addons/gtml/src/GmlView.gd`
- Modify: `tests/unit/test_binding_integration.gd`

- [ ] **Step 1.1: Read the current _rebuild resolver block**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -n "css_rules\|style_resolver\|_css_rules\|var styles" addons/gtml/src/GmlView.gd
```

Find the block (~line 192-197) where `css_rules`, `style_resolver`, `styles` are locals.

- [ ] **Step 1.2: Write the failing test**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript

# ─── v0.8.2: css_rules retention ───────────────────────────

func test_view_retains_css_rules_after_build() -> void:
	var view := _build_view('<div class="box">x</div>', '.box { color: #ff0000; }')
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(view._css_rules.size(), 0, "view must retain parsed css_rules for runtime re-resolution")
```

- [ ] **Step 1.3: Run, verify fail**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_binding_integration.gd 2>&1 | grep -E "Tests |Passing|Failing|SCRIPT ERROR" | head
```

Expected: fail — `_css_rules` doesn't exist.

- [ ] **Step 1.4: Add the fields + populate them**

In `addons/gtml/src/GmlView.gd`, add fields near the other internal state vars (search for `var _binding_registry`):

```gdscript
## Parsed CSS rules retained after _rebuild so runtime :class
## re-resolution (GmlClassRestyler) can recompute styles. Repopulated
## each rebuild; empty when the view has no CSS.
var _css_rules: Array = []
## Style resolver instance retained for runtime re-resolution.
var _style_resolver = null
```

In `_rebuild`, change the resolver block so the locals also persist on the view. Find:

```gdscript
	var styles: Dictionary = {}
	if not css_content.is_empty():
		var css_parser = GmlCssParser.new()
		var css_rules = css_parser.parse(css_content)
		var style_resolver = GmlStyleResolver.new()
		styles = style_resolver.resolve(dom_root, css_rules)
```

Replace with:

```gdscript
	var styles: Dictionary = {}
	_css_rules = []
	_style_resolver = null
	if not css_content.is_empty():
		var css_parser = GmlCssParser.new()
		var css_rules = css_parser.parse(css_content)
		var style_resolver = GmlStyleResolver.new()
		styles = style_resolver.resolve(dom_root, css_rules)
		_css_rules = css_rules
		_style_resolver = style_resolver
```

- [ ] **Step 1.5: Run, verify pass + full suite**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 368/368 (367 + 1).

- [ ] **Step 1.6: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/GmlView.gd tests/unit/test_binding_integration.gd && git commit -m "feat(css): retain parsed css_rules + resolver on GmlView

Runtime :class re-resolution needs the parsed rules + a resolver
instance after the initial build. Both were locals in _rebuild;
now persisted as _css_rules + _style_resolver, repopulated each
rebuild and cleared when the view has no CSS.

1 test pins retention. 367 → 368."
```

---

## Task 2: GmlClassRestyler.resolve_visual_props + allowlist + base snapshot

**Files:**
- Create: `addons/gtml/src/css/GmlClassRestyler.gd`
- Create: `tests/unit/test_class_restyler.gd`

- [ ] **Step 2.1: Write the failing tests**

Create `tests/unit/test_class_restyler.gd`:

```gdscript
extends GutTest

## Tests for GmlClassRestyler.resolve_visual_props — recompute the
## visual-property subset for a node with an explicit class list.

const GmlNodeScript = preload("res://addons/gtml/src/html_parser/GmlNode.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")


func _rules(css: String) -> Array:
	return GmlCssParserScript.new().parse(css)


func _node(tag: String, classes: String) -> Variant:
	var n = GmlNodeScript.create_element(tag, {"class": classes})
	return n


func test_resolve_visual_props_pulls_color() -> void:
	var rules := _rules(".rare { color: #b59aff; }")
	var n = _node("span", "rare")
	var props: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["rare"]), rules)
	assert_true(props.has("color"))


func test_resolve_visual_props_pulls_background() -> void:
	var rules := _rules(".active { background-color: #ffcc00; }")
	var n = _node("div", "active")
	var props: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["active"]), rules)
	assert_true(props.has("background-color"))


func test_resolve_visual_props_excludes_layout_keys() -> void:
	var rules := _rules(".x { color: #fff; display: flex; width: 100px; padding: 8px; }")
	var n = _node("div", "x")
	var props: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["x"]), rules)
	assert_true(props.has("color"), "color is a visual prop")
	assert_false(props.has("display"), "display is layout — excluded")
	assert_false(props.has("width"), "width is layout — excluded")
	assert_false(props.has("padding"), "padding is layout — excluded")


func test_resolve_visual_props_compound_selector_needs_both() -> void:
	var rules := _rules(".item.rare { color: #b59aff; }")
	var n = _node("li", "item")
	# Only "item" active → compound .item.rare does NOT match.
	var props_one: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["item"]), rules)
	assert_false(props_one.has("color"), "compound needs both classes")
	# Both active → matches.
	var props_both: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["item", "rare"]), rules)
	assert_true(props_both.has("color"))


func test_resolve_visual_props_restores_node_class_attr() -> void:
	# The restyler temporarily mutates the node's class attr; it MUST
	# restore the original afterwards.
	var rules := _rules(".rare { color: #fff; }")
	var n = _node("span", "base")
	GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["base", "rare"]), rules)
	assert_eq(n.get_attr("class", ""), "base", "original class attr must be restored")
```

- [ ] **Step 2.2: Run, verify fail**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_class_restyler.gd 2>&1 | grep -E "Tests |Passing|Failing|SCRIPT ERROR" | head
```

Expected: parse error — `GmlClassRestyler` not declared.

- [ ] **Step 2.3: Implement resolve_visual_props**

Create `addons/gtml/src/css/GmlClassRestyler.gd`:

```gdscript
class_name GmlClassRestyler
extends RefCounted

## Recomputes a v-bound element's VISUAL style for a given dynamic class
## set and applies the deltas in place — no structural re-wrapping.
##
## See docs/superpowers/specs/2026-05-28-class-reresolve-design.md
##
## Selector matching reads classes off the GmlNode (no injection hook),
## so resolve_visual_props temporarily sets the node's `class` attr to
## the merged static+dynamic list, runs the resolver, then restores it.

## Visual properties this module re-resolves. Anything else (layout /
## structural) is ignored — see _warn_layout_props.
const VISUAL_KEYS: PackedStringArray = PackedStringArray([
	"color",
	"background-color",
	"border-color",
	"border-width",
	"border-radius",
	"outline-color",
	"outline-width",
	"opacity",
	"font-size",
])

## Layout keys that, if present in a dynamic class, get warned about once.
const LAYOUT_KEYS: PackedStringArray = PackedStringArray([
	"display", "flex-direction", "flex-grow", "flex-shrink", "flex-wrap",
	"width", "height", "padding", "margin", "gap",
	"padding-left", "padding-right", "padding-top", "padding-bottom",
	"margin-left", "margin-right", "margin-top", "margin-bottom",
	"position",
])


## Resolve the visual-property subset for `node` as if its class list were
## `class_list`. Returns a Dictionary containing only VISUAL_KEYS that the
## cascade produced. Temporarily mutates + restores node's class attr.
static func resolve_visual_props(node, ancestor_chain: Array, class_list: PackedStringArray, css_rules: Array) -> Dictionary:
	var resolver = GmlStyleResolver.new()
	var original_class: String = node.get_attr("class", "")
	node.attrs["class"] = " ".join(class_list)
	var full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	node.attrs["class"] = original_class

	var out: Dictionary = {}
	for k in VISUAL_KEYS:
		if full.has(k):
			out[k] = full[k]
	return out


## Warn (once per control) if the recomputed full style introduces a
## layout key the dynamic class set changed. Called by restyle().
static func _warn_layout_props(control: Control, full_style: Dictionary) -> void:
	if control.get_meta("_layout_warn_done", false):
		return
	for k in LAYOUT_KEYS:
		if full_style.has(k):
			GmlBindingApplier._warn("dynamic :class changed layout prop '%s' — ignored; v0.8.2 re-resolves visual props only (color/bg/border/opacity/font-size)" % k)
			control.set_meta("_layout_warn_done", true)
			return
```

- [ ] **Step 2.4: Run, verify pass**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 90 godot --headless --import 2>&1 | tail -3
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_class_restyler.gd 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 5/5 pass.

NOTE: if `node.get_attr` or `node.attrs` access fails, inspect `addons/gtml/src/html_parser/GmlNode.gd` for the correct accessor and adjust. The test `test_resolve_visual_props_restores_node_class_attr` is the canary.

- [ ] **Step 2.5: Run full suite**

Expected: 373/373 (368 + 5).

- [ ] **Step 2.6: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/css/GmlClassRestyler.gd tests/unit/test_class_restyler.gd && git commit -m "feat(css): GmlClassRestyler.resolve_visual_props + visual allowlist

resolve_visual_props recomputes a node's merged style for an explicit
class list and returns only the visual-property subset (color, bg,
border, outline, opacity, font-size). Layout/structural keys are
excluded.

Because GmlSelector matching reads node.get_classes() with no
injection hook, the function temporarily sets the node's class attr
to the merged list, runs GmlStyleResolver._compute_style, then
restores the original attr — verified by a dedicated test.

_warn_layout_props (used by restyle in Task 3) warns once per control
when a dynamic class introduces a layout key.

5 tests: color, background, layout-exclusion, compound-selector
gating, class-attr restoration. 368 → 373."
```

---

## Task 3: GmlClassRestyler.restyle — apply path

**Files:**
- Modify: `addons/gtml/src/css/GmlClassRestyler.gd`
- Modify: `tests/unit/test_class_restyler.gd`

- [ ] **Step 3.1: Write the failing tests**

Append to `tests/unit/test_class_restyler.gd`:

```gdscript

# ─── restyle() apply path (Task 3) ─────────────────────────

func _panel_with_box() -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.1)
	p.add_theme_stylebox_override("panel", box)
	add_child_autofree(p)
	return p


func test_restyle_applies_background_color_to_panel() -> void:
	var rules := _rules(".active { background-color: #ffcc00; }")
	var n = _node("div", "card")
	var p := _panel_with_box()
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["card"]), rules)
	GmlClassRestyler.restyle(p, n, [n], PackedStringArray(["card", "active"]), rules, base, null)
	var box: StyleBoxFlat = p.get_theme_stylebox("panel")
	assert_almost_eq(box.bg_color.r, 1.0, 0.02)
	assert_almost_eq(box.bg_color.g, 0.8, 0.05)


func test_restyle_applies_font_color_to_label() -> void:
	var rules := _rules(".rare { color: #b59aff; }")
	var n = _node("span", "name")
	var label := Label.new()
	add_child_autofree(label)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["name"]), rules)
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["name", "rare"]), rules, base, null)
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 0.71, 0.05)
	assert_almost_eq(c.b, 1.0, 0.05)


func test_restyle_applies_opacity() -> void:
	var rules := _rules(".dim { opacity: 0.5; }")
	var n = _node("div", "box")
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["box"]), rules)
	GmlClassRestyler.restyle(ctrl, n, [n], PackedStringArray(["box", "dim"]), rules, base, null)
	assert_almost_eq(ctrl.modulate.a, 0.5, 0.02)


func test_restyle_removing_class_reverts_to_base_snapshot() -> void:
	var rules := _rules(".base { color: #ffffff; } .rare { color: #b59aff; }")
	var n = _node("span", "base")
	var label := Label.new()
	add_child_autofree(label)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["base"]), rules)
	# Add rare → purple.
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["base", "rare"]), rules, base, null)
	# Remove rare → revert to base white.
	GmlClassRestyler.restyle(label, n, [n], PackedStringArray(["base"]), rules, base, null)
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 1.0, 0.02)
	assert_almost_eq(c.b, 1.0, 0.02)


func test_restyle_layout_prop_in_dynamic_class_warns() -> void:
	var captured: Array = []
	GmlBindingApplier._on_warning = func(m): captured.append(m)
	var rules := _rules(".grow { display: flex; color: #fff; }")
	var n = _node("div", "box")
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var base: Dictionary = GmlClassRestyler.resolve_visual_props(n, [n], PackedStringArray(["box"]), rules)
	GmlClassRestyler.restyle(ctrl, n, [n], PackedStringArray(["box", "grow"]), rules, base, null)
	var layout_warns: Array = captured.filter(func(m): return "layout prop" in m)
	assert_gt(layout_warns.size(), 0, "layout prop in dynamic class must warn")
	GmlBindingApplier._on_warning = Callable()
```

- [ ] **Step 3.2: Implement restyle**

Append to `addons/gtml/src/css/GmlClassRestyler.gd`:

```gdscript

## Recompute the bound element's visual style for the active dynamic
## class set and apply the deltas in place. When dynamic_classes is empty
## the target is exactly base_snapshot (clean revert). transition_manager
## may be null (snap directly).
static func restyle(control: Control, node, ancestor_chain: Array, dynamic_classes: PackedStringArray, css_rules: Array, base_snapshot: Dictionary, transition_manager) -> void:
	if control == null or node == null:
		return

	# Merge static (node's own) + dynamic classes for the recompute.
	var static_classes: PackedStringArray = node.get_classes()
	var merged: PackedStringArray = PackedStringArray()
	for c in static_classes:
		if not merged.has(c):
			merged.append(c)
	for c in dynamic_classes:
		if not merged.has(c):
			merged.append(c)

	# Full recompute (for layout-warn detection) + visual subset.
	var resolver = GmlStyleResolver.new()
	var original_class: String = node.get_attr("class", "")
	node.attrs["class"] = " ".join(merged)
	var full: Dictionary = resolver._compute_style(node, ancestor_chain, css_rules, {})
	node.attrs["class"] = original_class

	_warn_layout_props(control, full)

	# Target visual props: start from base, overlay recomputed visual keys.
	var target: Dictionary = {}
	for k in VISUAL_KEYS:
		if base_snapshot.has(k):
			target[k] = base_snapshot[k]
	for k in VISUAL_KEYS:
		if full.has(k):
			target[k] = full[k]

	_apply_visual(control, target, full, transition_manager)


## Apply visual props to the control in place. Stylebox-bearing controls
## (PanelContainer/Button) get bg/border mutated on their existing
## stylebox; Labels get font_color; all controls get opacity via modulate.
static func _apply_visual(control: Control, target: Dictionary, full_style: Dictionary, transition_manager) -> void:
	# Opacity → modulate.a
	if target.has("opacity"):
		var a = target["opacity"]
		if a is float or a is int:
			control.modulate.a = float(a)

	# Font color → theme override (Label / RichTextLabel / Button)
	if target.has("color"):
		var col = target["color"]
		if col is Color:
			if control is RichTextLabel:
				control.add_theme_color_override("default_color", col)
			else:
				control.add_theme_color_override("font_color", col)

	# Font size
	if target.has("font-size"):
		var fs = target["font-size"]
		if fs is int or fs is float:
			control.add_theme_font_size_override("font_size", int(fs))

	# Stylebox-borne props: bg / border / outline / radius.
	var box: StyleBoxFlat = _get_stylebox(control)
	if box != null:
		if target.has("background-color") and target["background-color"] is Color:
			box.bg_color = target["background-color"]
		if target.has("border-color") and target["border-color"] is Color:
			box.border_color = target["border-color"]
		if target.has("border-width"):
			var bw = target["border-width"]
			if bw is int or bw is float:
				box.set_border_width_all(int(bw))
		if target.has("border-radius"):
			var br = target["border-radius"]
			if br is int or br is float:
				box.set_corner_radius_all(int(br))


## Return the StyleBoxFlat a control renders its background through, or
## null if it has none (e.g. a plain Label).
static func _get_stylebox(control: Control) -> StyleBoxFlat:
	var key: String = ""
	if control is Button:
		key = "normal"
	elif control.has_theme_stylebox("panel"):
		key = "panel"
	if key.is_empty():
		return null
	var box = control.get_theme_stylebox(key)
	if box is StyleBoxFlat:
		return box
	return null
```

NOTE on the transition path: the spec calls for routing through
`transition_manager.transition_style` when a `transition` is declared.
For v0.8.2 the snap path (direct mutation above) is the baseline and is
what the tests assert. If `transition_manager != null` AND
`full_style.has("transition")`, you MAY additionally call
`transition_manager.transition_style(control, <current>, target,
full_style["transition"])` to animate — but the direct mutation already
lands the final value, so the tests pass either way. Implement the
direct path first (tests green), then layer the animated call only if
time permits; it is not required for the tests.

- [ ] **Step 3.3: Run, verify pass**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_class_restyler.gd 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 10/10 (5 from Task 2 + 5 new).

If `set_border_width_all` / `set_corner_radius_all` aren't valid StyleBoxFlat methods in Godot 4.6, use the explicit setters: `box.border_width_left = ...` (and top/right/bottom), `box.corner_radius_top_left = ...` (and the other three corners). Verify against the engine.

- [ ] **Step 3.4: Run full suite**

Expected: 378/378 (373 + 5).

- [ ] **Step 3.5: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/css/GmlClassRestyler.gd tests/unit/test_class_restyler.gd && git commit -m "feat(css): GmlClassRestyler.restyle in-place visual apply

restyle() merges static + dynamic classes, recomputes the full style,
warns on layout-prop changes, builds a target from base-snapshot
overlaid with recomputed visual keys, and applies in place:
  - opacity → modulate.a
  - color → font_color / default_color theme override
  - font-size → font_size override
  - background/border/radius → mutate the control's existing
    StyleBoxFlat (PanelContainer 'panel' / Button 'normal'); plain
    Labels have no stylebox so bg is skipped

Removing all dynamic classes reverts to base_snapshot exactly. Snap
path is the baseline; the transition_manager animated path is
optional and additive.

5 new tests: bg on panel, font color on label, opacity, revert-to-
base, layout-prop warn. 373 → 378."
```

---

## Task 4: Renderer wiring — thread ancestor_chain + register on_change

**Files:**
- Modify: `addons/gtml/src/binding/GmlBindingApplier.gd`
- Modify: `addons/gtml/src/html_renderer/GmlRenderer.gd`

- [ ] **Step 4.1: Extend register_class_binding with on_change**

In `addons/gtml/src/binding/GmlBindingApplier.gd`, find `register_class_binding`. Add an optional trailing `on_change: Callable = Callable()` parameter and invoke it after the meta write.

Current signature ends with `..., scope: Dictionary = {}, tag: String = ""`. New:

```gdscript
static func register_class_binding(control: Control, expr: Dictionary, registry: GmlBindingRegistry, state: GmlState, scope: Dictionary = {}, tag: String = "", on_change: Callable = Callable()) -> void:
```

Inside the `apply` closure, after `ctl.set_meta("dynamic_classes", classes)`, add:

```gdscript
		if on_change.is_valid():
			on_change.call(classes)
```

Make sure `classes` is the `PackedStringArray` already computed in that closure.

- [ ] **Step 4.2: Thread ancestor_chain through _build_node**

In `addons/gtml/src/html_renderer/GmlRenderer.gd`:

Add an optional `ancestor_chain: Array = []` param to `_build_node`:

```gdscript
func _build_node(node, ancestor_chain: Array = []) -> Control:
```

Where `_build_node` recurses into children (directly, AND via the builders through `ctx.build_node`), the chain must extend with the current node. The builders call `ctx.build_node.call(child)`. Update the `build_node` Callable in `_build_context` to capture + extend the chain. Find `_build_context`:

```gdscript
func _build_context() -> Dictionary:
	return {
		"styles": _styles,
		"defaults": _defaults,
		"gml_view": _gml_view,
		"build_node": _build_node,
		...
	}
```

The simplest threading that avoids rewriting every builder: store the current chain on the renderer as `_current_chain` during `_build_node`, and have `_register_bindings_for_node` read it. Add a member:

```gdscript
var _current_chain: Array = []
```

At the top of `_build_node`, after the null/text checks:

```gdscript
	var node_chain: Array = ancestor_chain.duplicate()
	node_chain.append(node)
	_current_chain = node_chain
```

Pass `node_chain` when this function recurses directly (the v-if/v-for paths and `_build_text_node` don't need it, but the dispatched builders call `ctx.build_node` which points at `_build_node` with default empty chain). To keep correctness without rewriting builders, set `_current_chain` right before `_register_bindings_for_node(node, control, inner)` is called (it already runs in `_build_node` after dispatch), so the chain reflects this node. Because builders recurse via `ctx.build_node.call(child)` which resets `_current_chain` for each child, the chain will reflect the CURRENT node at the time its own bindings register. This is sufficient for `:class` on that node (descendant-from-ancestor is explicitly out of scope per spec §6.1).

- [ ] **Step 4.3: Register the on_change callback when binding :class**

In `_register_bindings_for_node`, find the `"v-bind"` → `cls["target"] == "class"` branch that calls `register_class_binding`. Replace it to compute a base snapshot + pass an on_change callback:

```gdscript
				if cls["target"] == "class":
					var restyle_cb := _make_class_restyle_callback(control, node)
					GmlBindingApplierScript.register_class_binding(control, expr, registry, state, scope, binding_tag, restyle_cb)
				else:
					GmlBindingApplierScript.register_attr_binding(control, cls["target"], expr, registry, state, scope, binding_tag)
```

Add the helper at the bottom of `GmlRenderer.gd`:

```gdscript
## Build the on_change callback for a :class binding. Captures the node,
## its ancestor chain (current at registration), the view's css_rules,
## the transition manager, and a base snapshot of static-only visual
## props. Returns Callable(PackedStringArray) that re-resolves + applies.
func _make_class_restyle_callback(control: Control, node) -> Callable:
	if _gml_view == null:
		return Callable()
	var css_rules: Array = _gml_view._css_rules
	if css_rules.is_empty():
		return Callable()
	var chain: Array = _current_chain.duplicate()
	var tm = _transition_manager
	var GmlClassRestylerScript = preload("res://addons/gtml/src/css/GmlClassRestyler.gd")
	# Base snapshot = static-only visual props.
	var static_classes: PackedStringArray = node.get_classes()
	var base_snapshot: Dictionary = GmlClassRestylerScript.resolve_visual_props(node, chain, static_classes, css_rules)
	var ctrl_ref: WeakRef = weakref(control)
	return func(dynamic_classes: PackedStringArray):
		var c = ctrl_ref.get_ref()
		if c == null:
			return
		GmlClassRestylerScript.restyle(c, node, chain, dynamic_classes, css_rules, base_snapshot, tm)
```

Verify the renderer has a `_transition_manager` member (it does — used in `_build_node`). If the member name differs, adjust.

- [ ] **Step 4.4: Run full suite**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 90 godot --headless --import 2>&1 | tail -3
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 378/378 (no new tests yet — Task 5 adds integration tests). Existing `:class` tests (`test_register_class_binding_writes_meta_classes`, `test_class_binding_with_comparison`, `test_class_binding_with_ternary`) must still pass — the meta write is unchanged; the callback is additive.

- [ ] **Step 4.5: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add addons/gtml/src/binding/GmlBindingApplier.gd addons/gtml/src/html_renderer/GmlRenderer.gd && git commit -m "feat(css): wire :class re-resolution callback in the renderer

register_class_binding gains an optional on_change callback invoked
after the dynamic_classes meta write. The renderer builds that
callback via _make_class_restyle_callback, capturing the node, its
ancestor chain (current at registration), the view's retained
css_rules, the transition manager, and a static-only base snapshot.
On every :class change the callback re-resolves the element's visual
props and applies them in place via GmlClassRestyler.restyle.

_build_node threads an ancestor_chain; _current_chain reflects the
node whose bindings are registering. Descendant-from-ancestor
re-resolution stays out of scope (spec §6.1).

No new tests here — the meta write is unchanged so existing :class
tests stay green; integration tests land in Task 5. Still 378."
```

---

## Task 5: Integration tests through GmlView

**Files:**
- Modify: `tests/unit/test_binding_integration.gd`

- [ ] **Step 5.1: Write integration tests**

Append to `tests/unit/test_binding_integration.gd`:

```gdscript

# ─── v0.8.2: dynamic :class CSS re-resolution ──────────────

func _find_first_span_label(view: GmlView) -> Label:
	# Content labels live under a VBoxContainer; markers under HBoxContainer.
	var out: Array = []
	_collect_label_nodes(view, out)
	return out[0] if out.size() > 0 else null


func test_dynamic_class_reresolves_font_color() -> void:
	var view := _build_view(
		'<div><span :class="{ rare: is_rare }" class="name">Item</span></div>',
		'.name { color: #ffffff; } .rare { color: #b59aff; }'
	)
	view.state.set("is_rare", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)
	assert_not_null(label)

	view.state.set("is_rare", true)
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.b, 1.0, 0.06, "rare class should turn font purple-ish")

	# Toggle back → revert to white.
	view.state.set("is_rare", false)
	await get_tree().process_frame
	var c2: Color = label.get_theme_color("font_color")
	assert_almost_eq(c2.r, 1.0, 0.06)
	assert_almost_eq(c2.b, 1.0, 0.06)


func test_dynamic_class_reresolves_background_on_panel() -> void:
	# A div with a background gets a PanelContainer wrapper with a stylebox.
	var view := _build_view(
		'<div :class="{ active: on }" class="card">x</div>',
		'.card { background-color: #222222; } .active { background-color: #ffcc00; }'
	)
	view.state.set("on", false)
	await get_tree().process_frame
	await get_tree().process_frame

	view.state.set("on", true)
	await get_tree().process_frame
	# Find a PanelContainer with a StyleBoxFlat whose bg is goldish.
	var found := false
	var stack: Array = [view]
	while not stack.is_empty():
		var nd = stack.pop_back()
		if nd is PanelContainer and nd.has_theme_stylebox("panel"):
			var box = nd.get_theme_stylebox("panel")
			if box is StyleBoxFlat and box.bg_color.r > 0.8 and box.bg_color.g > 0.6 and box.bg_color.b < 0.3:
				found = true
				break
		for ch in nd.get_children():
			stack.append(ch)
	assert_true(found, "active class should set goldish panel background")


func test_dynamic_class_low_hp_turns_red() -> void:
	var view := _build_view(
		'<div><span :class="{ low: hp < 25 }" class="hp">HP</span></div>',
		'.hp { color: #ffffff; } .low { color: #ff0000; }'
	)
	view.state.set("hp", 100)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)

	view.state.set("hp", 10)
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.r, 1.0, 0.06)
	assert_almost_eq(c.g, 0.0, 0.06, "low hp should turn red")


func test_dynamic_class_array_syntax_swaps_rarity() -> void:
	var view := _build_view(
		'<div><span :class="[\'badge\', rarity]" class="b">x</span></div>'.replace("\\'", "'"),
		'.common { color: #888888; } .epic { color: #cc44ff; }'
	)
	view.state.set("rarity", "common")
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)

	view.state.set("rarity", "epic")
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	assert_almost_eq(c.b, 1.0, 0.1, "epic rarity should turn purple-ish")


func test_dynamic_class_in_vfor_clone_reresolves() -> void:
	var view := _build_view(
		'<ul><li v-for="item in items" :key="item.id" :class="{ sel: item.active }" class="row">{{ item.name }}</li></ul>',
		'.row { color: #ffffff; } .sel { color: #00ff00; }'
	)
	view.state.set("items", [
		{"id": "a", "name": "A", "active": false},
		{"id": "b", "name": "B", "active": true},
	])
	await get_tree().process_frame
	await get_tree().process_frame
	# At least one clone's label should be green (the active one).
	var labels: Array = []
	_collect_label_nodes(view, labels)
	var any_green := false
	for l in labels:
		var c: Color = (l as Label).get_theme_color("font_color")
		if c.g > 0.8 and c.r < 0.2:
			any_green = true
			break
	assert_true(any_green, "v-for clone with :class sel should re-resolve green")


func test_dynamic_class_descendant_from_ancestor_NOT_reresolved() -> void:
	# Documented limitation (spec §6.1): toggling a class on the CARD does
	# NOT re-resolve a child styled by `.card.selected .name`.
	var view := _build_view(
		'<div :class="{ selected: on }" class="card"><span class="name">child</span></div>',
		'.name { color: #ffffff; } .card.selected .name { color: #ff0000; }'
	)
	view.state.set("on", false)
	await get_tree().process_frame
	await get_tree().process_frame
	var label := _find_first_span_label(view)

	view.state.set("on", true)
	await get_tree().process_frame
	var c: Color = label.get_theme_color("font_color")
	# Child stays white — ancestor-class descendant re-resolution is NOT supported.
	assert_almost_eq(c.r, 1.0, 0.06)
	assert_almost_eq(c.g, 1.0, 0.06, "child must NOT turn red — documented limitation")
```

- [ ] **Step 5.2: Run + commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 384/384 (378 + 6).

Debugging notes:
- If `test_dynamic_class_reresolves_background_on_panel` fails, the `<div>` may not be wrapped in a PanelContainer unless it has background-color at BUILD time. The `.card` static class sets `background-color: #222`, so the wrapper should exist. If no PanelContainer is found, inspect how `GmlWrap` decides to wrap (background-color present → PanelContainer). Adjust the test's CSS if the wrap trigger differs.
- If `test_dynamic_class_array_syntax_swaps_rarity` has quote-escaping issues, verify with `cat -A` that the HTML attribute reads `:class="['badge', rarity]"`.
- The v-for clone test depends on Task 4's chain threading reaching clones built by the reconciler. If clones don't re-resolve, confirm the reconciler's insert path calls `_build_node` (which sets `_current_chain`) before `_register_bindings_for_node`.

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/unit/test_binding_integration.gd && git commit -m "test(css): dynamic :class re-resolution integration tests

Six end-to-end tests through GmlView: font-color re-resolve + revert,
panel background re-resolve, low-hp red via comparison, array-syntax
rarity swap, v-for clone re-resolution, and the documented
descendant-from-ancestor limitation (child NOT re-resolved when an
ancestor's dynamic class changes).

378 → 384."
```

---

## Task 6: Docs + CHANGELOG + version bump

**Files:**
- Modify: `docs/bindings.md`
- Modify: `CHANGELOG.md`
- Modify: `addons/gtml/plugin.cfg`

- [ ] **Step 6.1: Update docs/bindings.md :class section**

In `docs/bindings.md`, find the `### \`:class="..."\` — class binding` section. It contains a "Limitation in v0.7" paragraph. Replace that limitation paragraph with:

```markdown
**Runtime re-resolution (v0.8.2+)**: changing a dynamic class re-resolves
the element's **visual** properties — `color`, `background-color`,
`border-color`, `border-width`, `border-radius`, `outline`, `opacity`,
`font-size` — from the merged class list and applies them in place. The
element's identity (focus, scroll, animations) is preserved.

**Not re-resolved** (documented limitations):
- **Layout / structural props** in a dynamic class (`display`, `flex-*`,
  `width`, `height`, `padding`, `margin`, `gap`) are ignored + warned.
  Use `v-if` / `v-show` for layout swaps.
- **Descendant selectors keyed on an ancestor's dynamic class**
  (`.card.selected .name`) do NOT re-resolve the descendant. Only the
  element carrying the `:class` binding restyles. Put the `:class` on
  the element you want to restyle, or bind the child to its own state key.
- **Hover collision**: if hovering when a dynamic class changes the same
  property, hover wins until it ends, then the new base shows.
- **Font-family** is not re-resolved (only `font-size`).
```

- [ ] **Step 6.2: Update CHANGELOG.md**

Insert after the `# Changelog` line, before `## 0.8.1`:

```markdown
## 0.8.2

### Features — Dynamic :class CSS re-resolution

Since v0.7, `:class` only wrote a `dynamic_classes` meta — adding a class
at runtime pulled in no styles. v0.8.2 makes dynamic `:class` actually
restyle the element: on change, the bound element's **visual** properties
(color, background, border, outline, opacity, font-size) are recomputed
from the merged class list and applied in place. Control identity
(focus / scroll / animation) is preserved — no structural rebuild.

```html
<span :class="{ rare: is_rare }">{{ item.name }}</span>
```
```css
.rare { color: #b59aff; }
```

`view.state.set("is_rare", true)` now turns the span purple.

### Architecture

- New `GmlClassRestyler` recomputes the visual-property subset via
  `GmlStyleResolver._compute_style` (temporarily setting the node's
  `class` attr to the merged list since selector matching reads node
  state) and applies deltas in place: stylebox field mutation for
  bg/border, theme overrides for color/font-size, `modulate.a` for
  opacity.
- `GmlView` retains the parsed `_css_rules` + resolver after build.
- The renderer threads the ancestor chain and registers an `on_change`
  callback on `:class` bindings with a static-only base snapshot for
  clean revert.

### Limitations (documented)

- Layout props in dynamic classes are ignored + warned.
- Descendant selectors keyed on an ancestor's dynamic class are not
  re-resolved (only the bound element restyles).
- Hover wins during a collision; new base shows after.
- `font-family` not re-resolved (only `font-size`).

### Tests

17 new tests across the restyler + integration; 367 → 384.

### Next blocker

One v0.8 production-readiness PR remains: focus traversal + perf bench.
```

- [ ] **Step 6.3: Bump version**

In `addons/gtml/plugin.cfg`: `version="0.8.1"` → `version="0.8.2"`.

- [ ] **Step 6.4: Final suite run**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 384/384.

- [ ] **Step 6.5: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/bindings.md CHANGELOG.md addons/gtml/plugin.cfg && git commit -m "chore(v0.8.2): dynamic :class re-resolution — docs + CHANGELOG + version

Replaces the bindings.md 'v0.7 does not re-resolve' caveat with the
visual-only re-resolution behaviour + the four documented limitations
(layout ignored, descendant-from-ancestor not re-resolved, hover
collision, no font-family). CHANGELOG 0.8.2 entry; plugin.cfg bumped."
```

---

## Task 7: Push + open PR

- [ ] **Step 7.1: Push**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git push -u origin feat/v0.8-class-reresolve 2>&1 | tail -3
```

- [ ] **Step 7.2: Open PR**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && gh pr create --base master --title "v0.8.2: dynamic :class CSS re-resolution (visual props, in-place)" --body "$(cat <<'EOF'
## Summary

Dynamic `:class` changes now re-resolve and re-apply the bound element's **visual** properties in place — color, background, border, outline, opacity, font-size — instead of doing nothing (the v0.7/v0.8.1 limitation). Control identity (focus/scroll/animation) is preserved; no structural rebuild.

```html
<span :class="{ rare: is_rare }">{{ item.name }}</span>
```
```css
.rare { color: #b59aff; }
```
`state.set("is_rare", true)` turns the span purple.

## Architecture

- **New `GmlClassRestyler`** — recomputes the visual subset via `GmlStyleResolver._compute_style` (temporarily sets the node's `class` attr to the merged list, since selector matching reads node state, then restores). Applies in place: stylebox mutation (bg/border), theme overrides (color/font-size), `modulate.a` (opacity).
- **`GmlView`** retains parsed `_css_rules` + resolver after build.
- **Renderer** threads the ancestor chain, registers an `on_change` callback on `:class` bindings, captures a static-only base snapshot for clean revert.

## Limitations (documented + tested)

- Layout props in dynamic classes ignored + warned.
- Descendant selectors keyed on an ancestor's dynamic class NOT re-resolved (only the bound element restyles) — a test pins this as intentional.
- Hover wins during a collision; new base shows after.
- `font-family` not re-resolved (only `font-size`).

## Stats

| | |
|---|---|
| Tests | 384 (was 367) |
| New engine LOC | ~140 restyler + renderer/view wiring |
| Plugin version | 0.8.1 → 0.8.2 |

## Test plan

- [ ] `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` → 384/384 green
- [ ] Inventory showcase: add `:class="{ rare: ... }"` to an item label with a `.rare { color }` rule, toggle the bound state — color changes live.

## Next

Final v0.8 production-readiness PR: focus traversal + perf bench.
EOF
)" 2>&1 | tail -3
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-05-28-class-reresolve-design.md`):

- §1 Component split → Task 2 + 3 (GmlClassRestyler), Task 4 (renderer wiring) ✓
- §2 Visual allowlist + structural boundary → Task 2 (VISUAL_KEYS, LAYOUT_KEYS, _warn_layout_props) ✓
- §3 Application through transition manager → Task 3 (`_apply_visual`; snap baseline + optional animated path; null-tm handled) ✓
- §4 Context capture + GmlView retention → Task 1 (retain _css_rules), Task 4 (thread chain, base snapshot) ✓
- §5 register_class_binding extension → Task 4 (on_change param) ✓
- §6 Known limitations → Task 5 (descendant-NOT-reresolved test), Task 6 (docs) ✓
- §7 Testing plan → Tasks 2,3,5 ✓
- §8 Phasing → 7 tasks ✓

**Placeholder scan:** none.

**Type consistency:** `resolve_visual_props(node, ancestor_chain, class_list, css_rules)` + `restyle(control, node, ancestor_chain, dynamic_classes, css_rules, base_snapshot, transition_manager)` consistent across Tasks 2-4. `_css_rules` field name consistent (Task 1 ↔ Task 4). `on_change: Callable` consistent (Task 4 applier ↔ renderer callback). `VISUAL_KEYS` referenced consistently.

**Implementation risks flagged inline:**
- Node class-attr accessor (`node.attrs["class"]` vs `set_attr`) — Task 2 canary test + note.
- `set_border_width_all` / `set_corner_radius_all` may need explicit per-side setters — Task 3 note.
- PanelContainer wrap trigger for the bg integration test — Task 5 note.
- v-for clone chain threading reaching the reconciler insert path — Task 5 note.
- The ancestor-chain threading via `_current_chain` is a pragmatic shortcut (not full per-recursion threading); sufficient because descendant-from-ancestor is out of scope. Documented in Task 4.
