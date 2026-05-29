# Foundry Idle Demo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `addons/gtml/examples/showcase/foundry/` — a complete idle/clicker game ("Commit Idle") that showcases GTML's reactive bindings, keyed `v-for` reconciliation, live `:class` restyle, and focus-trap modals in a real game loop.

**Architecture:** `demo.gd` (attached to the scene's `Control` root) is the single source of truth: it holds plain game fields (`commits`, owned counts, purchased set, `insight`) and exposes *pure* logic functions that operate only on those fields. A throttled tick pushes pre-formatted display strings + reconstructed list arrays into `view.state`; `index.html` renders them via bindings. The pure/runtime split makes the game math unit-testable headless without rendering.

**Tech Stack:** Godot 4 GDScript, the GTML addon (`GtmlView`/`GtmlState`), GUT for tests. HTML/CSS authored as GTML markup.

---

## Reference patterns (read before starting)

- Existing reactive demo: `addons/gtml/examples/showcase/inventory/{demo.gd,demo.tscn,index.html,style.css}`.
- `GtmlView` API: `addons/gtml/src/GtmlView.gd` — signals `button_clicked(method_name)`, `item_clicked(handler, args)`; `var state: GtmlState`.
- `GtmlState`: `set_state(Dictionary)`, plus `state.set("key", v)` / `state.get("key")` via Object virtuals.
- Signal routing: `@click="tap"` (no parens) → `button_clicked("tap")`. `@click="buy(g.id)"` → `item_clicked("buy", ["intern"])`.
- Run the whole suite: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` (from project root).
- Run one file: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_foundry_demo.gd -gexit`.

## File structure

```
addons/gtml/examples/showcase/foundry/
  demo.gd       # game logic (data tables, fields, pure functions, runtime glue)
  demo.gd.uid   # minted by `godot --headless --import`
  demo.tscn     # Control root + GtmlView wired to index.html / style.css
  index.html    # markup + bindings (no game numbers)
  style.css     # dark palette, flex, :class buckets, transitions
tests/unit/
  test_foundry_demo.gd   # GUT unit + one integration smoke test
```

Commit convention (this repo): conventional-commits subject, **no `Co-Authored-By`**. Track `.uid` files.

---

## Task 1: Scaffold `demo.gd` with data tables, fields, and `fmt()`

**Files:**
- Create: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_foundry_demo.gd`:

```gdscript
extends GutTest

const DemoScript := preload("res://addons/gtml/examples/showcase/foundry/demo.gd")

func _new_demo():
	# demo.gd extends Control; .new() makes a bare instance (no _ready until tree-added).
	return autofree(DemoScript.new())

func test_fmt_below_thousand_is_plain_int() -> void:
	var d = _new_demo()
	assert_eq(d.fmt(0.0), "0")
	assert_eq(d.fmt(42.0), "42")
	assert_eq(d.fmt(999.0), "999")

func test_fmt_uses_suffixes() -> void:
	var d = _new_demo()
	assert_eq(d.fmt(1000.0), "1.00K")
	assert_eq(d.fmt(1500000.0), "1.50M")
	assert_eq(d.fmt(2300000000.0), "2.30B")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_foundry_demo.gd -gexit`
Expected: FAIL — cannot preload/parse `demo.gd` (file does not exist yet).

- [ ] **Step 3: Create `demo.gd` with data, fields, and `fmt()`**

```gdscript
extends Control

## Foundry — "Commit Idle". A fully reactive idle game built on GTML.
## demo.gd is the source of truth; pure functions operate on the fields below
## and never touch `view`. Only _ready/_process/_derive/_show_toast and the
## signal handlers push into view.state.

@onready var view: GtmlView = $GtmlView

const GENERATORS := [
	{"id": "intern",   "name": "Intern",         "desc": "Writes commits while you sleep.", "cost": 10,     "rate": 0.5},
	{"id": "compiler", "name": "Compiler",       "desc": "Turns coffee into builds.",       "cost": 120,    "rate": 4.0},
	{"id": "ci_farm",  "name": "CI Farm",        "desc": "Green checks, all day.",          "cost": 1500,   "rate": 25.0},
	{"id": "render",   "name": "Render Server",  "desc": "Bakes lightmaps on the side.",    "cost": 20000,  "rate": 160.0},
	{"id": "linter",   "name": "Quantum Linter", "desc": "Fixes bugs in superposition.",    "cost": 250000, "rate": 1000.0},
]

const UPGRADES := [
	{"id": "keyboard",  "name": "Mechanical Keyboard", "desc": "Per-click x2.",       "cost": 100,    "kind": "click", "factor": 2.0, "gate_commits": 50},
	{"id": "hotreload", "name": "Hot Reload",          "desc": "Intern output x2.",   "cost": 500,    "kind": "gen",   "factor": 2.0, "target": "intern",   "gate_gen": "intern",   "gate_n": 5},
	{"id": "ssd",       "name": "NVMe Array",          "desc": "Compiler output x2.", "cost": 4000,   "kind": "gen",   "factor": 2.0, "target": "compiler", "gate_gen": "compiler", "gate_n": 5},
	{"id": "distcc",    "name": "Distributed Build",   "desc": "CI Farm output x2.",  "cost": 25000,  "kind": "gen",   "factor": 2.0, "target": "ci_farm",  "gate_gen": "ci_farm",  "gate_n": 5},
	{"id": "caffeine",  "name": "Infinite Caffeine",   "desc": "Per-click x3.",       "cost": 8000,   "kind": "click", "factor": 3.0, "gate_commits": 5000},
	{"id": "gpu",       "name": "GPU Cluster",         "desc": "Render output x2.",   "cost": 120000, "kind": "gen",   "factor": 2.0, "target": "render",   "gate_gen": "render",   "gate_n": 5},
]

const ACHIEVEMENTS := [
	{"id": "first",          "name": "First Commit",   "desc": "Write your first commit."},
	{"id": "ten_interns",    "name": "Onboarding",     "desc": "Own 10 Interns."},
	{"id": "kilo",           "name": "Kilocommit",     "desc": "Reach 1,000 commits."},
	{"id": "mega",           "name": "Megacommit",     "desc": "Reach 1,000,000 commits."},
	{"id": "first_refactor", "name": "Tech Debt Paid", "desc": "Refactor once."},
	{"id": "five_gens",      "name": "Full Stack",     "desc": "Own every generator type."},
	{"id": "upgrader",       "name": "Optimizer",      "desc": "Buy 3 upgrades."},
	{"id": "insightful",     "name": "Enlightened",    "desc": "Reach 10 Insight."},
]

const DERIVE_INTERVAL := 0.1

var commits: float = 0.0
var total_this_run: float = 0.0
var per_click: float = 1.0
var insight: int = 0
var refactored: int = 0
var gen_owned: Dictionary = {}   # id -> int
var purchased: Dictionary = {}   # upgrade id -> true
var earned: Dictionary = {}      # achievement id -> true
var _derive_accum: float = 0.0


func fmt(n: float) -> String:
	if absf(n) < 1000.0:
		return str(int(n))
	var units := ["K", "M", "B", "T"]
	var idx := -1
	var v := n
	while absf(v) >= 1000.0 and idx < units.size() - 1:
		v /= 1000.0
		idx += 1
	return "%.2f%s" % [v, units[idx]]
```

- [ ] **Step 4: Mint the `.uid` and verify tests pass**

Run: `godot --headless --import` (from project root) to mint `demo.gd.uid`.
Then run: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_foundry_demo.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add tests/unit/test_foundry_demo.gd addons/gtml/examples/showcase/foundry/demo.gd addons/gtml/examples/showcase/foundry/demo.gd.uid
git commit -m "feat(examples): foundry idle demo scaffold + number formatter"
```

---

## Task 2: Cost scaling, effective rate, and `per_sec`

**Files:**
- Modify: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_foundry_demo.gd`:

```gdscript
func test_cost_scales_by_115_percent() -> void:
	var d = _new_demo()
	assert_eq(d.cost_of("intern"), 10)        # 10 * 1.15^0
	d.gen_owned["intern"] = 1
	assert_eq(d.cost_of("intern"), 11)        # floor(10 * 1.15)
	d.gen_owned["intern"] = 2
	assert_eq(d.cost_of("intern"), 13)        # floor(10 * 1.3225)

func test_per_sec_sums_owned_generators() -> void:
	var d = _new_demo()
	assert_eq(d.per_sec(), 0.0)
	d.gen_owned["intern"] = 2     # 2 * 0.5 = 1.0
	d.gen_owned["compiler"] = 1   # 1 * 4.0 = 4.0
	assert_almost_eq(d.per_sec(), 5.0, 0.0001)

func test_global_mult_scales_rate_with_insight() -> void:
	var d = _new_demo()
	d.gen_owned["intern"] = 1
	d.insight = 50              # mult = 1 + 50*0.02 = 2.0
	assert_almost_eq(d.effective_rate("intern"), 1.0, 0.0001)  # 0.5 * 1 * 2.0
```

- [ ] **Step 2: Run to verify failure**

Run: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_foundry_demo.gd -gexit`
Expected: FAIL — `cost_of`, `per_sec`, `effective_rate` not defined.

- [ ] **Step 3: Add the functions to `demo.gd`** (place after `fmt`)

```gdscript
func _gen_def(id: String) -> Dictionary:
	for g in GENERATORS:
		if g.id == id:
			return g
	return {}

func _owned(id: String) -> int:
	return int(gen_owned.get(id, 0))

func cost_of(id: String) -> int:
	var base: float = float(_gen_def(id).get("cost", 0))
	return int(floor(base * pow(1.15, _owned(id))))

func global_mult() -> float:
	return 1.0 + insight * 0.02

func _gen_factor(id: String) -> float:
	var f := 1.0
	for u in UPGRADES:
		if u.kind == "gen" and u.get("target", "") == id and purchased.has(u.id):
			f *= float(u.factor)
	return f

func effective_rate(id: String) -> float:
	return float(_gen_def(id).get("rate", 0.0)) * _owned(id) * _gen_factor(id) * global_mult()

func per_sec() -> float:
	var s := 0.0
	for g in GENERATORS:
		s += effective_rate(g.id)
	return s

func click_value() -> float:
	return per_click * global_mult()

func can_afford(amount: float) -> bool:
	return commits >= amount
```

- [ ] **Step 4: Run to verify pass**

Run: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_foundry_demo.gd -gexit`
Expected: PASS (5 tests total).

- [ ] **Step 5: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.gd tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry generator cost scaling + production rate"
```

---

## Task 3: Buy a generator

**Files:**
- Modify: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

- [ ] **Step 1: Write the failing tests**

Append:

```gdscript
func test_buy_generator_deducts_and_increments() -> void:
	var d = _new_demo()
	d.commits = 10.0
	assert_true(d.buy_generator("intern"))
	assert_eq(d._owned("intern"), 1)
	assert_almost_eq(d.commits, 0.0, 0.0001)

func test_buy_generator_fails_when_too_poor() -> void:
	var d = _new_demo()
	d.commits = 9.0
	assert_false(d.buy_generator("intern"))
	assert_eq(d._owned("intern"), 0)
	assert_almost_eq(d.commits, 9.0, 0.0001)

func test_buy_generator_uses_scaled_cost() -> void:
	var d = _new_demo()
	d.gen_owned["intern"] = 1   # next cost 11
	d.commits = 11.0
	assert_true(d.buy_generator("intern"))
	assert_eq(d._owned("intern"), 2)
```

- [ ] **Step 2: Run to verify failure**

Run: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_foundry_demo.gd -gexit`
Expected: FAIL — `buy_generator` not defined.

- [ ] **Step 3: Add `buy_generator`**

```gdscript
func buy_generator(id: String) -> bool:
	var c := cost_of(id)
	if not can_afford(c):
		return false
	commits -= c
	gen_owned[id] = _owned(id) + 1
	return true
```

- [ ] **Step 4: Run to verify pass**

Expected: PASS (8 tests total).

- [ ] **Step 5: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.gd tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry generator purchase logic"
```

---

## Task 4: Upgrades — gating, purchase, and the unpurchased view

**Files:**
- Modify: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

Behavior: an upgrade is *visible/purchasable* only when its gate is met and it is not yet bought. `build_upgrades_view()` returns the visible set; buying removes it (so the keyed `v-for` reconciles a node out). `click`-kind upgrades multiply `per_click`; `gen`-kind upgrades are applied via `_gen_factor` (already implemented in Task 2).

- [ ] **Step 1: Write the failing tests**

Append:

```gdscript
func test_upgrade_gate_by_commits() -> void:
	var d = _new_demo()
	d.total_this_run = 49.0
	assert_false(d.upgrade_unlocked(d._upg_def("keyboard")))
	d.total_this_run = 50.0
	assert_true(d.upgrade_unlocked(d._upg_def("keyboard")))

func test_upgrade_gate_by_generator_count() -> void:
	var d = _new_demo()
	d.gen_owned["intern"] = 4
	assert_false(d.upgrade_unlocked(d._upg_def("hotreload")))
	d.gen_owned["intern"] = 5
	assert_true(d.upgrade_unlocked(d._upg_def("hotreload")))

func test_buy_click_upgrade_multiplies_per_click() -> void:
	var d = _new_demo()
	d.commits = 100.0
	assert_true(d.buy_upgrade("keyboard"))
	assert_almost_eq(d.per_click, 2.0, 0.0001)
	assert_true(d.purchased.has("keyboard"))

func test_buy_gen_upgrade_multiplies_generator_output() -> void:
	var d = _new_demo()
	d.gen_owned["intern"] = 10        # base rate 5.0
	d.commits = 500.0
	assert_true(d.buy_upgrade("hotreload"))
	assert_almost_eq(d.effective_rate("intern"), 10.0, 0.0001)  # 5.0 * 2.0

func test_buy_upgrade_twice_fails() -> void:
	var d = _new_demo()
	d.commits = 1000.0
	assert_true(d.buy_upgrade("keyboard"))
	assert_false(d.buy_upgrade("keyboard"))

func test_upgrades_view_excludes_purchased_and_locked() -> void:
	var d = _new_demo()
	d.total_this_run = 50.0          # only "keyboard" gate met
	var ids := []
	for u in d.build_upgrades_view():
		ids.append(u.id)
	assert_eq(ids, ["keyboard"])
	d.commits = 100.0
	d.buy_upgrade("keyboard")
	var ids2 := []
	for u in d.build_upgrades_view():
		ids2.append(u.id)
	assert_false(ids2.has("keyboard"))
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `upgrade_unlocked`, `_upg_def`, `buy_upgrade`, `build_upgrades_view` not defined.

- [ ] **Step 3: Add the upgrade functions**

```gdscript
func _upg_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

func upgrade_cost(id: String) -> int:
	return int(_upg_def(id).get("cost", 0))

func upgrade_unlocked(u: Dictionary) -> bool:
	if u.is_empty() or purchased.has(u.id):
		return false
	if u.has("gate_gen") and _owned(u.gate_gen) < int(u.gate_n):
		return false
	if u.has("gate_commits") and total_this_run < float(u.gate_commits):
		return false
	return true

func buy_upgrade(id: String) -> bool:
	if purchased.has(id):
		return false
	var c := upgrade_cost(id)
	if not can_afford(c):
		return false
	commits -= c
	purchased[id] = true
	var u := _upg_def(id)
	if u.get("kind", "") == "click":
		per_click *= float(u.factor)
	return true

func build_upgrades_view() -> Array:
	var out := []
	for u in UPGRADES:
		if not upgrade_unlocked(u):
			continue
		var c := upgrade_cost(u.id)
		out.append({
			"id": u.id, "name": u.name, "desc": u.desc,
			"cost_display": fmt(c), "affordable": can_afford(c),
		})
	return out
```

- [ ] **Step 4: Run to verify pass**

Expected: PASS (14 tests total).

- [ ] **Step 5: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.gd tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry upgrades — gating, purchase, unpurchased view"
```

---

## Task 5: Achievements

**Files:**
- Modify: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

- [ ] **Step 1: Write the failing tests**

Append:

```gdscript
func test_check_achievements_returns_newly_earned_once() -> void:
	var d = _new_demo()
	d.commits = 1.0
	var newly := d._check_achievements()
	assert_true(newly.has("first"))
	assert_true(d.earned.has("first"))
	# Calling again returns nothing new.
	assert_eq(d._check_achievements(), [])

func test_five_gens_achievement_requires_all_types() -> void:
	var d = _new_demo()
	for g in d.GENERATORS:
		d.gen_owned[g.id] = 1
	var newly := d._check_achievements()
	assert_true(newly.has("five_gens"))

func test_achievements_view_reports_earned_flag() -> void:
	var d = _new_demo()
	d.commits = 1.0
	d._check_achievements()
	var by_id := {}
	for a in d.build_achievements_view():
		by_id[a.id] = a.earned
	assert_true(by_id["first"])
	assert_false(by_id["kilo"])
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `_check_achievements`, `build_achievements_view` not defined.

- [ ] **Step 3: Add the achievement functions**

```gdscript
func _all_gens_owned() -> bool:
	for g in GENERATORS:
		if _owned(g.id) <= 0:
			return false
	return true

func _check_achievements() -> Array:
	var conds := {
		"first": commits >= 1.0,
		"ten_interns": _owned("intern") >= 10,
		"kilo": commits >= 1000.0,
		"mega": commits >= 1000000.0,
		"first_refactor": refactored >= 1,
		"five_gens": _all_gens_owned(),
		"upgrader": purchased.size() >= 3,
		"insightful": insight >= 10,
	}
	var newly := []
	for a in ACHIEVEMENTS:
		if conds.get(a.id, false) and not earned.has(a.id):
			earned[a.id] = true
			newly.append(a.id)
	return newly

func _ach_name(id: String) -> String:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a.name
	return id

func build_achievements_view() -> Array:
	var out := []
	for a in ACHIEVEMENTS:
		out.append({"id": a.id, "name": a.name, "desc": a.desc, "earned": earned.has(a.id)})
	return out
```

- [ ] **Step 4: Run to verify pass**

Expected: PASS (17 tests total).

- [ ] **Step 5: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.gd tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry achievements check + view"
```

---

## Task 6: Refactor (prestige)

**Files:**
- Modify: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

- [ ] **Step 1: Write the failing tests**

Append:

```gdscript
func test_refactor_gain_formula() -> void:
	var d = _new_demo()
	d.total_this_run = 10000.0      # floor(sqrt(1)) = 1
	assert_eq(d.refactor_gain(), 1)
	d.total_this_run = 250000.0     # floor(sqrt(25)) = 5
	assert_eq(d.refactor_gain(), 5)

func test_do_refactor_resets_run_keeps_insight_and_achievements() -> void:
	var d = _new_demo()
	d.commits = 1.0
	d._check_achievements()         # earns "first"
	d.total_this_run = 250000.0
	d.gen_owned["intern"] = 7
	d.commits = 250000.0
	d.purchased["keyboard"] = true
	d.do_refactor()
	assert_eq(d.insight, 5)
	assert_eq(d.refactored, 1)
	assert_almost_eq(d.commits, 0.0, 0.0001)
	assert_almost_eq(d.total_this_run, 0.0, 0.0001)
	assert_eq(d._owned("intern"), 0)
	assert_eq(d.purchased.size(), 0)
	assert_almost_eq(d.per_click, 1.0, 0.0001)
	assert_true(d.earned.has("first"))   # achievements persist
	assert_almost_eq(d.global_mult(), 1.1, 0.0001)  # 1 + 5*0.02
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `refactor_gain`, `do_refactor` not defined.

- [ ] **Step 3: Add the refactor functions**

```gdscript
func refactor_gain() -> int:
	return int(floor(sqrt(total_this_run / 10000.0)))

func do_refactor() -> void:
	insight += refactor_gain()
	refactored += 1
	commits = 0.0
	total_this_run = 0.0
	per_click = 1.0
	gen_owned.clear()
	purchased.clear()
	# insight + earned achievements intentionally persist.
```

- [ ] **Step 4: Run to verify pass**

Expected: PASS (19 tests total).

- [ ] **Step 5: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.gd tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry refactor/prestige reset + insight gain"
```

---

## Task 7: Generators view + runtime glue (tick, state push, signal handlers)

**Files:**
- Modify: `addons/gtml/examples/showcase/foundry/demo.gd`
- Test: `tests/unit/test_foundry_demo.gd`

The `build_generators_view()` function is pure and gets a unit test here. The runtime glue (`_ready`, `_process`, `_derive`, `_show_toast`, `_on_button`, `_on_item`, `_refresh_all`) touches `view`, so it is verified by the integration smoke test in Task 10 — do not unit-test those.

- [ ] **Step 1: Write the failing test (pure part only)**

Append:

```gdscript
func test_generators_view_marks_affordability() -> void:
	var d = _new_demo()
	d.commits = 10.0
	var rows := d.build_generators_view()
	assert_eq(rows.size(), d.GENERATORS.size())
	var first = rows[0]
	assert_eq(first.id, "intern")
	assert_eq(first.owned, 0)
	assert_eq(first.cost_display, "10")
	assert_true(first.affordable)        # 10 >= 10
	assert_false(rows[1].affordable)     # compiler costs 120
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `build_generators_view` not defined.

- [ ] **Step 3: Add `build_generators_view` and the runtime glue**

```gdscript
func build_generators_view() -> Array:
	var out := []
	for g in GENERATORS:
		var c := cost_of(g.id)
		out.append({
			"id": g.id, "name": g.name, "desc": g.desc,
			"owned": _owned(g.id),
			"cost_display": fmt(c),
			"rate_display": fmt(effective_rate(g.id)),
			"affordable": can_afford(c),
		})
	return out


func _ready() -> void:
	view.state.set_state({
		"commits_display": fmt(commits),
		"per_sec_display": fmt(per_sec()),
		"per_click_display": fmt(click_value()),
		"insight": insight,
		"mult_display": "%.2f" % global_mult(),
		"generators": build_generators_view(),
		"upgrades": build_upgrades_view(),
		"no_upgrades": build_upgrades_view().is_empty(),
		"achievements": build_achievements_view(),
		"toast": "",
		"show_toast": false,
		"show_refactor": false,
		"refactor_gain": str(refactor_gain()),
	})
	view.button_clicked.connect(_on_button)
	view.item_clicked.connect(_on_item)


func _process(delta: float) -> void:
	if view == null:
		return
	var rate := per_sec()
	var earnings := rate * delta
	commits += earnings
	total_this_run += earnings
	view.state.set("commits_display", fmt(commits))
	view.state.set("per_sec_display", fmt(rate))
	_derive_accum += delta
	if _derive_accum >= DERIVE_INTERVAL:
		_derive_accum = 0.0
		_derive()


func _derive() -> void:
	if view == null:
		return
	var ups := build_upgrades_view()
	view.state.set("generators", build_generators_view())
	view.state.set("upgrades", ups)
	view.state.set("no_upgrades", ups.is_empty())
	view.state.set("per_click_display", fmt(click_value()))
	view.state.set("refactor_gain", str(refactor_gain()))
	var newly := _check_achievements()
	if not newly.is_empty():
		view.state.set("achievements", build_achievements_view())
		_show_toast(_ach_name(newly[0]))


func _show_toast(text: String) -> void:
	view.state.set("toast", text)
	view.state.set("show_toast", true)
	await get_tree().create_timer(3.0).timeout
	if view != null:
		view.state.set("show_toast", false)


func _on_button(method: String) -> void:
	match method:
		"tap":
			var v := click_value()
			commits += v
			total_this_run += v
			_derive()
		"open_refactor":
			view.state.set("refactor_gain", str(refactor_gain()))
			view.state.set("show_refactor", true)
		"confirm_refactor":
			do_refactor()
			view.state.set("show_refactor", false)
			_refresh_all()
		"cancel_refactor":
			view.state.set("show_refactor", false)


func _on_item(handler: String, args: Array) -> void:
	var id := str(args[0]) if args.size() > 0 else ""
	match handler:
		"buy":
			if buy_generator(id):
				_derive()
		"buy_upgrade":
			if buy_upgrade(id):
				_derive()


func _refresh_all() -> void:
	view.state.set("insight", insight)
	view.state.set("mult_display", "%.2f" % global_mult())
	view.state.set("achievements", build_achievements_view())
	_derive()
```

- [ ] **Step 4: Run to verify pass**

Expected: PASS (20 tests total).

- [ ] **Step 5: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.gd tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry generators view + tick loop + signal wiring"
```

---

## Task 8: `index.html` markup

**Files:**
- Create: `addons/gtml/examples/showcase/foundry/index.html`

No unit test (markup); verified by the Task 10 integration smoke + manual run. Note: visibility booleans (`no_upgrades`, `show_toast`) are pushed from GDScript rather than relying on `.length`/string-truthiness in expressions.

- [ ] **Step 1: Create `index.html`**

```html
<div class="app">
	<header class="hud">
		<div class="counts">
			<span class="commits">{{ commits_display }}</span>
			<span class="rate">{{ per_sec_display }} commits/s</span>
		</div>
		<button class="tap-btn" @click="tap">Commit  (+{{ per_click_display }})</button>
		<div class="meta">
			<span class="insight">Insight: {{ insight }}</span>
			<span class="mult">x{{ mult_display }}</span>
			<button class="refactor-btn" @click="open_refactor">Refactor</button>
		</div>
	</header>

	<div class="body">
		<section class="panel">
			<h2 class="panel-title">Generators</h2>
			<ul class="rows">
				<li v-for="g in generators" :key="g.id" class="row">
					<div class="row-info">
						<span class="row-name">{{ g.name }}</span>
						<span class="row-desc">{{ g.desc }}</span>
						<span class="row-stat">Owned {{ g.owned }} &middot; {{ g.rate_display }}/s</span>
					</div>
					<button class="buy-btn" :class="{ affordable: g.affordable }" :disabled="!g.affordable" @click="buy(g.id)">{{ g.cost_display }}</button>
				</li>
			</ul>
		</section>

		<section class="panel">
			<h2 class="panel-title">Upgrades</h2>
			<ul class="rows">
				<li v-for="u in upgrades" :key="u.id" class="row">
					<div class="row-info">
						<span class="row-name">{{ u.name }}</span>
						<span class="row-desc">{{ u.desc }}</span>
					</div>
					<button class="buy-btn" :class="{ affordable: u.affordable }" :disabled="!u.affordable" @click="buy_upgrade(u.id)">{{ u.cost_display }}</button>
				</li>
			</ul>
			<p v-if="no_upgrades" class="empty">No upgrades available yet.</p>
		</section>

		<section class="panel">
			<h2 class="panel-title">Achievements</h2>
			<ul class="badges">
				<li v-for="a in achievements" :key="a.id" class="badge" :class="{ earned: a.earned }">
					<span class="badge-name">{{ a.name }}</span>
					<span class="badge-desc">{{ a.desc }}</span>
				</li>
			</ul>
		</section>
	</div>

	<div v-show="show_toast" class="toast">Unlocked: {{ toast }}</div>

	<div v-if="show_refactor" class="modal-overlay">
		<div class="modal" focus-trap>
			<h2 class="modal-title">Refactor?</h2>
			<p class="modal-text">Reset commits and generators to gain {{ refactor_gain }} Insight (permanent +2% output each).</p>
			<div class="modal-actions">
				<button class="confirm-btn" @click="confirm_refactor" autofocus>Confirm</button>
				<button class="cancel-btn" @click="cancel_refactor">Cancel</button>
			</div>
		</div>
	</div>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/index.html
git commit -m "feat(examples): foundry markup + bindings"
```

---

## Task 9: `style.css`

**Files:**
- Create: `addons/gtml/examples/showcase/foundry/style.css`

- [ ] **Step 1: Create `style.css`**

```css
.app {
	display: flex;
	flex-direction: column;
	height: 100%;
	background-color: #1a1d23;
	font-family: sans-serif;
}

.hud {
	display: flex;
	flex-direction: column;
	gap: 8px;
	padding: 18px 24px;
	background-color: #20242c;
	border-bottom: 2px solid #2e3440;
}
.counts { display: flex; flex-direction: row; gap: 16px; }
.commits { color: #8fd6ff; font-size: 36px; font-weight: bold; }
.rate { color: #7c8595; font-size: 16px; }

.tap-btn {
	background-color: #3a7bd5;
	color: #ffffff;
	font-size: 22px;
	padding: 16px;
	border-radius: 8px;
	transition: background-color 0.12s;
}
.tap-btn:hover { background-color: #4d8de0; }

.meta { display: flex; flex-direction: row; gap: 16px; }
.insight { color: #ffd479; font-size: 15px; }
.mult { color: #b6e58a; font-size: 15px; }
.refactor-btn {
	background-color: #5a3a6e;
	color: #f0e6ff;
	padding: 6px 14px;
	border-radius: 6px;
	transition: background-color 0.12s;
}
.refactor-btn:hover { background-color: #6e4a85; }

.body { overflow-y: auto; padding: 16px 24px; }

.panel { margin-bottom: 20px; }
.panel-title { color: #c8ced8; font-size: 18px; margin-bottom: 8px; }

.rows { display: flex; flex-direction: column; gap: 8px; }
.row {
	display: flex;
	flex-direction: row;
	gap: 12px;
	padding: 12px;
	background-color: #252932;
	border-radius: 8px;
	border: 1px solid #2e3440;
}
.row-info { display: flex; flex-direction: column; gap: 2px; }
.row-name { color: #e6eaf0; font-size: 16px; font-weight: bold; }
.row-desc { color: #7c8595; font-size: 13px; }
.row-stat { color: #9aa3b2; font-size: 13px; }

.buy-btn {
	background-color: #33384a;
	color: #6b7280;
	padding: 10px 18px;
	border-radius: 6px;
	font-size: 15px;
	transition: background-color 0.12s;
}
.buy-btn.affordable { background-color: #2f7d4f; color: #ffffff; }
.buy-btn.affordable:hover { background-color: #38935d; }

.badges { display: flex; flex-direction: row; flex-wrap: wrap; gap: 10px; }
.badge {
	display: flex;
	flex-direction: column;
	gap: 2px;
	padding: 12px;
	background-color: #20242c;
	border-radius: 8px;
	border: 1px solid #2e3440;
	opacity: 0.45;
}
.badge.earned { opacity: 1.0; border-color: #ffd479; }
.badge-name { color: #e6eaf0; font-size: 14px; font-weight: bold; }
.badge-desc { color: #7c8595; font-size: 12px; }

.empty { color: #7c8595; font-size: 14px; }

.toast {
	background-color: #ffd479;
	color: #1a1d23;
	padding: 12px 20px;
	border-radius: 8px;
	font-size: 16px;
	font-weight: bold;
	transition: opacity 0.2s;
}

.modal-overlay {
	background-color: #000000;
	opacity: 0.92;
	display: flex;
	flex-direction: column;
	padding: 80px;
}
.modal {
	background-color: #252932;
	border: 2px solid #5a3a6e;
	border-radius: 12px;
	padding: 28px;
	display: flex;
	flex-direction: column;
	gap: 14px;
}
.modal-title { color: #f0e6ff; font-size: 24px; }
.modal-text { color: #c8ced8; font-size: 15px; }
.modal-actions { display: flex; flex-direction: row; gap: 12px; }
.confirm-btn {
	background-color: #5a3a6e;
	color: #ffffff;
	padding: 12px 24px;
	border-radius: 8px;
	transition: background-color 0.12s;
}
.confirm-btn:hover, .confirm-btn:focus { background-color: #7a4f95; }
.cancel-btn {
	background-color: #33384a;
	color: #c8ced8;
	padding: 12px 24px;
	border-radius: 8px;
}
```

- [ ] **Step 2: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/style.css
git commit -m "feat(examples): foundry styling"
```

---

## Task 10: Scene wiring + integration smoke test + manual verification

**Files:**
- Create: `addons/gtml/examples/showcase/foundry/demo.tscn`
- Test: `tests/unit/test_foundry_demo.gd`

- [ ] **Step 1: Create `demo.tscn`**

```
[gd_scene load_steps=3 format=3 uid="uid://foundry_commit_idle"]

[ext_resource type="Script" path="res://addons/gtml/src/GtmlView.gd" id="1_gtmlview"]
[ext_resource type="Script" path="res://addons/gtml/examples/showcase/foundry/demo.gd" id="2_demo"]

[node name="FoundryDemo" type="Control"]
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
color = Color(0.102, 0.114, 0.137, 1)

[node name="GtmlView" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_gtmlview")
html_path = "res://addons/gtml/examples/showcase/foundry/index.html"
css_path = "res://addons/gtml/examples/showcase/foundry/style.css"
```

- [ ] **Step 2: Reimport so Godot registers the scene + any new uids**

Run: `godot --headless --import` (from project root).
Expected: completes without script/parse errors referencing `foundry`.

- [ ] **Step 3: Write the integration smoke test**

Append to `tests/unit/test_foundry_demo.gd`:

```gdscript
func test_scene_builds_and_ticks() -> void:
	var scene = load("res://addons/gtml/examples/showcase/foundry/demo.tscn")
	var inst = add_child_autofree(scene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var view = inst.get_node("GtmlView")
	assert_gt(view.get_child_count(), 0, "GtmlView built a control tree")
	# Headline state is populated and a tap increments commits.
	assert_true(view.state.has("commits_display"), "state seeded in _ready")
	var before: float = inst.commits
	inst._on_button("tap")
	assert_gt(inst.commits, before, "tap adds commits")
```

- [ ] **Step 4: Run the FULL suite to verify pass + no regressions**

Run: `timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
Expected: PASS — all prior tests (403) plus the new `test_foundry_demo.gd` (21 tests). No failures, no orphan errors referencing foundry.

- [ ] **Step 5: Manual verification (golden path)**

Open `addons/gtml/examples/showcase/foundry/demo.tscn` in the editor and press Play. Confirm:
- Headline counter starts at `0`, big **Commit** button increments it.
- Buying enough Interns makes `commits/s` rise and the counter ticks on its own.
- A `.buy-btn` switches from grey to green (`.affordable`) live as you can afford it.
- Crossing 50 commits reveals the Mechanical Keyboard upgrade; buying it removes its card (siblings stay put) and doubles per-click.
- An achievement toast pops and disappears after ~3s.
- **Refactor** opens the modal; Tab/arrow keys stay trapped inside it; Confirm resets the run and raises the `x` multiplier; Cancel closes with no change.

If any manual check fails, fix and re-run Step 4 before committing.

- [ ] **Step 6: Commit**

```bash
git add addons/gtml/examples/showcase/foundry/demo.tscn tests/unit/test_foundry_demo.gd
git commit -m "feat(examples): foundry scene wiring + integration smoke test"
```

---

## Task 11 (optional): Register the demo in docs

**Files:**
- Modify: `README.md` (the Examples table), `docs/index.md` if it lists demos.

Only do this if keeping the examples table current is desired. Add a `foundry` row, e.g.:

```
| **foundry** | Idle game — full reactive loop: per-frame `state.set`, keyed `v-for` add/remove (upgrades), live `:class` affordability, focus-trap prestige modal |
```

- [ ] Commit: `docs: list foundry idle demo in examples table`

---

## Self-review notes (author)

- **Spec coverage:** generators (T2/T3/T7), one-time upgrades incl. keyed removal (T4/T8), achievements + toast (T5/T7/T8), refactor + modal (T6/T8), header+scroll layout (T8/T9), session-only (no persistence tasks — correct), tick + throttled derive (T7), GDScript number formatting (T1), unit + manual testing (T1–T10). All covered.
- **No `.length`/string-truthiness reliance:** `no_upgrades` and `show_toast` booleans are pushed from GDScript (T7) and consumed by `v-if`/`v-show` (T8).
- **Type consistency:** field/function names (`gen_owned`, `_owned`, `cost_of`, `buy_generator`, `buy_upgrade`, `build_*_view`, `do_refactor`, `refactor_gain`, `click_value`) are identical across tasks and tests.
- **Test-count crumbs** (2→5→8→14→17→19→20→21) are guidance; the authoritative gate is the full-suite run in T10 Step 4.
