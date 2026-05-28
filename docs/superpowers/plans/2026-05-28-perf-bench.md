# GTML v0.8.4 — Performance benchmark harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An informational, on-demand GUT benchmark that times GTML's hot paths (pure v-for diff, v-for build at scale, reconcile ops, state.set fan-out, full render) and prints a ms/op + ops/sec table — excluded from the default CI suite, never flaky.

**Architecture:** A single file `tests/perf/test_perf_bench.gd` (`extends GutTest`) outside the default suite's `tests/unit/` dir. A `_bench(...)` helper times only the operation (excludes setup/cleanup); each `test_*` method benches one target group and prints a formatted table via `print()`. One self-check test verifies the harness.

**Tech Stack:** Godot 4.6 GDScript, GUT 9.6, `Time.get_ticks_usec()`, existing GTML pipeline (no engine changes).

**Reference spec:** `docs/superpowers/specs/2026-05-28-perf-bench-design.md`

---

## Pre-flight

- Branch: `feat/v0.8-perf-bench` (already created with spec commit)
- Working directory: `/data/personal/projects/godot/godot-plugins-gtml`
- Default suite count: **408** — MUST stay 408 (the perf file is NOT in `tests/unit/`, so the default run never collects it)
- Bench run command (explicit): `cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd`
- Default suite command: `cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Style: TABS for indentation. NO Co-Authored-By line.
- ALL subagent shell commands prefix with `cd /data/personal/projects/godot/godot-plugins-gtml &&`

---

## Verified integration facts

- `.gutconfig.json` `dirs` = `["res://tests/unit/"]` → `tests/perf/` is excluded from the default run. Run the bench file explicitly with `-gtest=`.
- `GmlVForReconciler.diff(old_keys: PackedStringArray, new_keys: PackedStringArray) -> Array` — pure.
- `_build_view` pattern (from `tests/unit/test_binding_integration.gd`): writes temp `index.html` + `style.css` under a fixture dir, sets `view.html_path`/`css_path`/`size`, `add_child_autofree(view)`. The view's `_ready` awaits a frame then builds; integration tests await 2 `process_frame`s before asserting.
- `view.state.set(key, value)` fires bindings synchronously; the v-for reconcile + interpolation re-render happen inside that call. `set` short-circuits when the new value equals the old — so fan-out benches must set a CHANGING value each iteration.
- Full render path: `GmlHtmlParser.new().parse(html)` → DOM; `GmlCssParser.new().parse(css)` → rules; `GmlStyleResolver.new().resolve(dom, rules)` → styles dict; `GmlRenderer.new().build(dom, styles, gml_view)` → root Control (synchronous). The renderer needs a `gml_view` with `state` + `_binding_registry` (a real `GmlView` instance provides both).

---

## File Structure

**New:**
```
tests/perf/test_perf_bench.gd   # the whole harness (~260 LOC)
docs/perf.md                    # how-to-run doc (Task 6)
```

**Modify:**
```
docs/getting-started.md         # link perf.md
CHANGELOG.md                    # 0.8.4 entry
addons/gtml/plugin.cfg          # 0.8.3 → 0.8.4
```

No engine files change.

---

## Task 1: Harness scaffold — _bench + helpers + self-check

**Files:**
- Create: `tests/perf/test_perf_bench.gd`

- [ ] **Step 1.1: Create the file with helpers + the self-check test**

Create `tests/perf/test_perf_bench.gd`:

```gdscript
extends GutTest

## Informational performance benchmarks for GTML. NOT part of the default
## suite (gutconfig scopes to tests/unit/). Run explicitly:
##   godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json \
##     -gtest=res://tests/perf/test_perf_bench.gd
##
## Bench tests print tables and carry NO wall-clock assertions, so a slow
## machine never fails. The single self-check test verifies the _bench
## helper times only the operation (excludes setup/cleanup).

const GmlViewScript = preload("res://addons/gtml/src/GmlView.gd")
const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlRendererScript = preload("res://addons/gtml/src/html_renderer/GmlRenderer.gd")

# Captured by the most recent _bench call so the self-check can inspect it.
var _last_ms_per_op: float = 0.0
var _last_ops_per_sec: float = 0.0


## Build a GmlView from inline HTML/CSS (writes temp fixture files).
func _build_view(html: String, css: String = "") -> GmlView:
	var dir := "res://tests/snapshots/.actual/perf_fixture"
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
	view.size = Vector2(800, 600)
	add_child_autofree(view)
	return view


## Generate n item dicts: [{"id": "0", "name": "Item 0"}, ...].
func make_items(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"id": str(i), "name": "Item %d" % i})
	return out


## Generate n string keys ["0", "1", ...] as a PackedStringArray.
func make_keys(n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i in n:
		out.append(str(i))
	return out


## Time `op` over `iterations` runs (after `warmup` untimed runs). `setup`
## runs untimed before each timed op; `cleanup` runs untimed after each op.
## Only `op` is inside the timer. Prints a row + stashes the last metrics.
func _bench(label: String, n: int, iterations: int, op: Callable, setup: Callable = Callable(), warmup: int = 2, cleanup: Callable = Callable()) -> void:
	for _w in warmup:
		if setup.is_valid():
			setup.call()
		op.call()
		if cleanup.is_valid():
			cleanup.call()
	var total_usec: int = 0
	for _i in iterations:
		if setup.is_valid():
			setup.call()
		var t0: int = Time.get_ticks_usec()
		op.call()
		total_usec += Time.get_ticks_usec() - t0
		if cleanup.is_valid():
			cleanup.call()
	var total_ms: float = total_usec / 1000.0
	var ms_per_op: float = total_ms / iterations if iterations > 0 else 0.0
	var ops_per_sec: float = (1000000.0 * iterations / total_usec) if total_usec > 0 else 0.0
	_last_ms_per_op = ms_per_op
	_last_ops_per_sec = ops_per_sec
	_print_row(label, n, iterations, total_ms, ms_per_op, ops_per_sec)


func _print_header(title: String) -> void:
	print("")
	print("── %s %s" % [title, "─".repeat(max(0, 56 - title.length()))])
	print("%-22s %6s %8s %11s %9s %10s" % ["operation", "N", "iters", "total ms", "ms/op", "ops/sec"])


func _print_row(op: String, n: int, iters: int, total_ms: float, ms_per_op: float, ops_sec: float) -> void:
	print("%-22s %6d %8d %11.2f %9.4f %10.1f" % [op, n, iters, total_ms, ms_per_op, ops_sec])


# ─── Self-check (the only assertions in this file) ─────────

func test_bench_helper_sanity() -> void:
	_print_header("harness self-check")
	# Trivial op → positive ops/sec.
	var acc: Array = [0]
	_bench("noop_add", 0, 1000, func(): acc[0] += 1)
	assert_gt(_last_ops_per_sec, 0.0, "ops/sec must be positive")

	# Op paired with a deliberately slow setup → the timer must EXCLUDE
	# setup, so ms/op stays tiny despite the slow setup.
	_bench("excludes_setup", 0, 50,
		func(): acc[0] += 1,
		func():
			var burn: int = 0
			for _b in 50000:
				burn += 1
	)
	assert_lt(_last_ms_per_op, 1.0, "timed region must exclude the slow setup")
```

- [ ] **Step 1.2: Run the bench file, verify the self-check passes + tables print**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 90 godot --headless --import 2>&1 | tail -3
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd 2>&1 | tail -25
```

Expected: `test_bench_helper_sanity` passes (2 asserts); the console shows the `harness self-check` header + two rows with positive ops/sec.

- [ ] **Step 1.3: Confirm the default suite is UNCHANGED (perf file excluded)**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 408/408 (the perf file is NOT collected — gutconfig dirs = tests/unit only).

- [ ] **Step 1.4: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/perf/test_perf_bench.gd && git commit -m "perf(bench): harness scaffold — _bench helper + self-check

tests/perf/test_perf_bench.gd is an informational GUT bench, excluded
from the default suite (gutconfig scopes to tests/unit). The _bench
helper times only the operation — setup + cleanup callables run
untimed before/after — over N iterations after a warmup, and prints
total ms / ms-per-op / ops-per-sec. Helpers: _build_view (temp-file
GmlView), make_items, make_keys, _print_header/_print_row.

One self-check test (the only assertions in the file) verifies the
helper reports positive ops/sec and that the timed region excludes a
deliberately slow setup. Default suite unchanged at 408 (perf file
not collected)."
```

---

## Task 2: Pure-diff bench

**Files:**
- Modify: `tests/perf/test_perf_bench.gd`

- [ ] **Step 2.1: Add the pure-diff bench test**

Append to `tests/perf/test_perf_bench.gd`:

```gdscript

# ─── Pure GmlVForReconciler.diff ───────────────────────────

func test_perf_pure_diff() -> void:
	_print_header("pure GmlVForReconciler.diff")
	for n in [100, 1000]:
		var old_keys := make_keys(n)

		# append: new = old + 1 extra key
		var appended := make_keys(n)
		appended.append(str(n))
		_bench("diff_append", n, 1000, func(): GmlVForReconciler.diff(old_keys, appended))

		# prepend: new = [new_key] + old
		var prepended := PackedStringArray([str(n)])
		prepended.append_array(old_keys)
		_bench("diff_prepend", n, 1000, func(): GmlVForReconciler.diff(old_keys, prepended))

		# replace one middle key
		var replaced := old_keys.duplicate()
		replaced[n / 2] = "X"
		_bench("diff_replace", n, 1000, func(): GmlVForReconciler.diff(old_keys, replaced))

		# shuffle: reverse the array (LIS worst-ish case)
		var reversed := PackedStringArray()
		for i in range(n - 1, -1, -1):
			reversed.append(old_keys[i])
		_bench("diff_shuffle", n, 200, func(): GmlVForReconciler.diff(old_keys, reversed))

	assert_true(true)  # keep GUT happy (informational test, no perf assertion)
```

- [ ] **Step 2.2: Run, verify it prints**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd 2>&1 | tail -30
```

Expected: a `pure GmlVForReconciler.diff` table with 8 rows (append/prepend/replace/shuffle × N=100,1000), all with positive ops/sec; `test_perf_pure_diff` passes.

- [ ] **Step 2.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/perf/test_perf_bench.gd && git commit -m "perf(bench): pure GmlVForReconciler.diff bench

Times the LIS diff in isolation (no scene cost) for append / prepend /
replace-one / shuffle at N=100 and N=1000. Shuffle (array reversal)
stresses the LIS path; append/prepend/replace exercise the
common-prefix/suffix fast paths."
```

---

## Task 3: v-for build-at-scale bench

**Files:**
- Modify: `tests/perf/test_perf_bench.gd`

- [ ] **Step 3.1: Add the build-at-scale bench**

Append to `tests/perf/test_perf_bench.gd`:

```gdscript

# ─── v-for initial build at scale ──────────────────────────

func test_perf_vfor_build_scale() -> void:
	_print_header("v-for build at scale (initial populate)")
	for spec in [[10, 30], [100, 20], [500, 8], [1000, 4]]:
		var n: int = spec[0]
		var iters: int = spec[1]
		var items := make_items(n)
		# Fresh view per timed iteration: setup builds an empty-list view +
		# settles it; op populates (the timed reconcile inserts n clones).
		# A captured slot holds the current view so op + cleanup reach it.
		var slot: Array = [null]
		_bench("build_initial", n, iters,
			func():
				(slot[0] as GmlView).state.set("items", items),
			func():
				var v := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
				# Settle the empty build (its _ready awaits a frame).
				await get_tree().process_frame
				await get_tree().process_frame
				slot[0] = v,
			1,
			func():
				if slot[0] != null and is_instance_valid(slot[0]):
					(slot[0] as Node).queue_free()
					slot[0] = null
		)
	assert_true(true)
```

NOTE: `_bench`'s `setup` here uses `await`. GDScript lambdas CAN contain `await` but then they're coroutines and `setup.call()` returns immediately without awaiting — the frames won't actually settle inside `_bench`. To handle this correctly, do NOT await inside the lambda. Instead, settle the view in the bench BODY before the timed loop. Rewrite this test without await-in-lambda:

```gdscript
func test_perf_vfor_build_scale() -> void:
	_print_header("v-for build at scale (initial populate)")
	for spec in [[10, 30], [100, 20], [500, 8], [1000, 4]]:
		var n: int = spec[0]
		var iters: int = spec[1]
		var items := make_items(n)
		# Pre-build + settle ONE view per N; each timed iteration clears the
		# list then re-populates so the reconcile does a full n-insert from
		# empty. setup (untimed) clears; op (timed) populates.
		var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
		await get_tree().process_frame
		await get_tree().process_frame
		_bench("build_initial", n, iters,
			func(): view.state.set("items", items),
			func(): view.state.set("items", []),
			1
		)
	assert_true(true)
```

Use THIS second version (no await in lambdas). `setup` clears the list (reconcile removes all → empty), `op` populates (reconcile inserts n). Both are synchronous. queue_free'd clones from the clear accumulate within the timed loop — acceptable per the spec's documented churn note; add a short comment.

- [ ] **Step 3.2: Run, verify it prints**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd 2>&1 | tail -35
```

Expected: a `v-for build at scale` table, 4 rows (N=10/100/500/1000), positive ops/sec, ms/op rising with N. `test_perf_vfor_build_scale` passes.

If it times out at N=1000: lower the N=1000 iters from 4 to 2, or drop the 1000 row to 500 only. Note the adjustment.

- [ ] **Step 3.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/perf/test_perf_bench.gd && git commit -m "perf(bench): v-for initial build at scale

Times a full v-for populate (empty → N items) at N=10/100/500/1000 by
clearing the list untimed (setup) then setting N items timed (op). The
timed reconcile builds N clones + registers their bindings. The
headline 'is a 1000-item list viable' number. Clones from the clear
queue_free within the loop (transient, not a leak — see comment)."
```

---

## Task 4: v-for reconcile-ops bench

**Files:**
- Modify: `tests/perf/test_perf_bench.gd`

- [ ] **Step 4.1: Add the reconcile-ops bench**

Append to `tests/perf/test_perf_bench.gd`:

```gdscript

# ─── v-for reconcile ops (keyed) ───────────────────────────

func test_perf_vfor_reconcile_ops() -> void:
	_print_header("v-for reconcile ops")
	var base := make_items(100)
	var appended := make_items(100)
	appended.append({"id": "100", "name": "Item 100"})
	var prepended: Array = [{"id": "p", "name": "Prepend"}]
	prepended.append_array(make_items(100))
	var replaced := make_items(100)
	replaced[50] = {"id": "X", "name": "Replaced"}
	var reversed: Array = []
	for i in range(99, -1, -1):
		reversed.append(base[i])

	# One settled view; setup resets to `base` (untimed), op applies the
	# mutation (timed). Each op is a single synchronous reconcile.
	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	await get_tree().process_frame
	await get_tree().process_frame

	var reset := func(): view.state.set("items", base.duplicate())

	_bench("append", 100, 50, func(): view.state.set("items", appended), reset)
	_bench("prepend", 100, 50, func(): view.state.set("items", prepended), reset)
	_bench("replace_one", 100, 50, func(): view.state.set("items", replaced), reset)
	_bench("shuffle_reverse", 100, 30, func(): view.state.set("items", reversed), reset)

	# Shuffle at N=500 to stress LIS through the full reconcile.
	var base500 := make_items(500)
	var reversed500: Array = []
	for i in range(499, -1, -1):
		reversed500.append(base500[i])
	view.state.set("items", base500)
	await get_tree().process_frame
	var reset500 := func(): view.state.set("items", base500.duplicate())
	_bench("shuffle_reverse", 500, 10, func(): view.state.set("items", reversed500), reset500)

	assert_true(true)
```

NOTE: `set` short-circuits on equal values — `base.duplicate()` is a NEW array each reset so the reset always fires; `appended`/etc. are distinct arrays so the op always fires. After an op sets `appended`, the next `reset` sets a fresh `base.duplicate()` (different from `appended`) → reconcile runs. Good.

- [ ] **Step 4.2: Run, verify it prints**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd 2>&1 | tail -40
```

Expected: a `v-for reconcile ops` table with append/prepend/replace_one/shuffle_reverse(100) + shuffle_reverse(500). append/replace should be cheap (few ops); shuffle is the heaviest. `test_perf_vfor_reconcile_ops` passes.

- [ ] **Step 4.3: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/perf/test_perf_bench.gd && git commit -m "perf(bench): v-for reconcile ops

Times each mutation kind on a 100-item keyed list — append, prepend,
replace-one, shuffle (reverse) — by resetting to a base array untimed
then applying the mutation timed. Adds a 500-item shuffle to stress
the LIS path through the full scene-mutating reconcile. Shows the
keyed-reconcile payoff: append/replace touch few controls vs a full
rebuild."
```

---

## Task 5: state.set fan-out + full-build bench

**Files:**
- Modify: `tests/perf/test_perf_bench.gd`

- [ ] **Step 5.1: Add the fan-out + full-build bench**

Append to `tests/perf/test_perf_bench.gd`:

```gdscript

# ─── state.set fan-out + full view build ───────────────────

func test_perf_state_fanout_and_full_build() -> void:
	_print_header("state.set fan-out")
	for k in [10, 100, 500]:
		# K interpolations of the same key → one set fires K text bindings.
		var inner := ""
		for _i in k:
			inner += "<span>{{ count }}</span>"
		var view := _build_view("<div>" + inner + "</div>")
		view.state.set("count", 0)
		await get_tree().process_frame
		await get_tree().process_frame
		# op must set a CHANGING value each time (set short-circuits equals).
		var counter: Array = [0]
		_bench("set_fanout", k, 200,
			func():
				counter[0] += 1
				view.state.set("count", counter[0])
		)

	_print_header("full view build (renderer.build)")
	# Representative document: header + a 50-item list + footer + some text.
	var li := ""
	for i in 50:
		li += '<li>Item %d</li>' % i
	var html := '<div class="page"><header><h1>Title</h1></header><ul>' + li + '</ul><footer><p>Footer text here</p></footer></div>'
	var css := '.page { background-color: #222; } h1 { color: #fff; } li { color: #ccc; }'
	# Parse + resolve ONCE (untimed); time only renderer.build.
	var dom = GmlHtmlParserScript.new().parse(html)
	var rules = GmlCssParserScript.new().parse(css)
	var styles = GmlStyleResolverNew(dom, rules)
	var host_view := _build_view("<div></div>")
	await get_tree().process_frame
	var built: Array = []
	_bench("renderer_build", 50, 30,
		func():
			built.append(GmlRendererScript.new().build(dom, styles, host_view)),
		Callable(),
		2,
		Callable()
	)
	# Free all built roots (untimed, after the loop).
	for b in built:
		if is_instance_valid(b):
			(b as Node).free()

	assert_true(true)


## GmlStyleResolver is instantiated; resolve() is an instance method.
func GmlStyleResolverNew(dom, rules) -> Dictionary:
	var resolver = GmlStyleResolver.new()
	return resolver.resolve(dom, rules)
```

NOTE: `GmlStyleResolver` is available by `class_name` globally (used in GmlView). The tiny `GmlStyleResolverNew` wrapper avoids a long inline expression in the bench body. `renderer.build` returns a detached root each call; they're collected in `built` and freed after the timed loop (untimed). The `built` array grows by iterations+warmup roots — fine for 30+2.

If `GmlStyleResolver` is NOT global by class_name, preload it: add `const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")` at the top and use `GmlStyleResolverScript.new()`.

- [ ] **Step 5.2: Run, verify it prints**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd 2>&1 | tail -45
```

Expected: a `state.set fan-out` table (K=10/100/500) + a `full view build` row, positive ops/sec. `test_perf_state_fanout_and_full_build` passes.

- [ ] **Step 5.3: Run the WHOLE bench file once + eyeball all five groups**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 180 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd 2>&1 | grep -E "──|operation|build_initial|diff_|append|prepend|replace|shuffle|set_fanout|renderer_build|Passing|Failing"
```

Expected: all five group headers + rows present; all bench tests pass (5 tests incl. self-check).

- [ ] **Step 5.4: Confirm default suite STILL 408**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 408/408.

- [ ] **Step 5.5: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add tests/perf/test_perf_bench.gd && git commit -m "perf(bench): state.set fan-out + full renderer.build

Fan-out: a view with K {{ count }} interpolations; times one
state.set('count', changing) that fires K text bindings (K=10/100/
500). Each op sets a new value so the equality short-circuit doesn't
skip it. Full build: parse + resolve a representative document
(header + 50-item list + footer) once, untimed, then time
renderer.build over 30 iterations; built roots freed after the loop.
Completes the four hot-path groups."
```

---

## Task 6: Docs + CHANGELOG + version bump

**Files:**
- Create: `docs/perf.md`
- Modify: `docs/getting-started.md`
- Modify: `CHANGELOG.md`
- Modify: `addons/gtml/plugin.cfg`

- [ ] **Step 6.1: Create docs/perf.md**

Create `docs/perf.md`:

```markdown
# Performance benchmarks (v0.8.4+)

GTML ships an informational benchmark harness that times the engine's
hot paths. It is **not** part of the default test suite and has **no
pass/fail budgets** — it prints numbers you read on demand.

## Running

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json \
  -gtest=res://tests/perf/test_perf_bench.gd
```

The default suite (`tests/unit/`) does not include the bench, so normal
CI runs are unaffected.

## What it measures

Each group prints a table: operation, N, iterations, total ms, ms/op,
ops/sec.

- **pure GmlVForReconciler.diff** — the LIS keyed-diff in isolation
  (append / prepend / replace / shuffle at N=100, 1000). No scene cost.
- **v-for build at scale** — full populate of an empty list at N=10/100/
  500/1000. The "is a 1000-item list viable" number.
- **v-for reconcile ops** — append / prepend / replace-one / shuffle on a
  100-item keyed list (+ a 500-item shuffle). Shows the keyed-reconcile
  payoff — append/replace touch few controls, not the whole list.
- **state.set fan-out** — one `state.set` firing K text bindings (K=10/
  100/500).
- **full view build** — `GmlRenderer.build` of a representative document.

## Caveats

- Numbers are **machine- and load-dependent** — informational, not a
  contract.
- Headless timing covers CPU build/binding/reconcile cost only, **not**
  GPU/draw time.
- Within a timed loop, reconcile churn `queue_free`s old clones that
  settle on the next frame — a transient, not a leak.
- Each run is standalone stdout; there is no historical tracking.
```

- [ ] **Step 6.2: Link from getting-started.md**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && grep -n "Focus & navigation\|focus.md\|Next Steps" docs/getting-started.md
```

After the `focus.md` link line in "Next Steps", add (match format/indent):

```markdown
- [Performance](perf.md) - the benchmark harness + how to run it
```

- [ ] **Step 6.3: Update CHANGELOG.md**

Insert after `# Changelog`, before `## 0.8.3`:

```markdown
## 0.8.4

### Tooling — Performance benchmark harness

Adds `tests/perf/test_perf_bench.gd`, an informational benchmark that
times GTML's hot paths and prints a ms/op + ops/sec table. It answers
the long-standing "perf at scale — never measured" known unknown from
the v0.7/v0.8 specs.

- **Excluded from the default suite** (gutconfig scopes to `tests/unit/`);
  run on demand with `-gtest=res://tests/perf/test_perf_bench.gd`.
- **No wall-clock budgets / assertions** — never flaky on a slow machine.
- Measures: pure `GmlVForReconciler.diff`, v-for build at scale
  (10/100/500/1000), reconcile ops (append/prepend/replace/shuffle),
  `state.set` fan-out (K=10/100/500), and full `renderer.build`.
- A single self-check test verifies the `_bench` helper times only the
  operation (excludes setup/cleanup).

Measurement only — no engine changes. Any alarming number is a separate
follow-up.

This completes the v0.8 production-readiness line (expression operators,
v-for `:key` reconciliation, dynamic `:class` re-resolution, focus
traversal, and now the perf harness).

### Tests

Default suite unchanged at 408 (the perf file is not collected). The
bench file adds 5 on-demand bench tests (1 with assertions).

### Docs

New `docs/perf.md` — how to run + what each group measures + caveats.
```

- [ ] **Step 6.4: Bump version**

In `addons/gtml/plugin.cfg`: `version="0.8.3"` → `version="0.8.4"`.

- [ ] **Step 6.5: Final default-suite run**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && timeout 120 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -E "Tests |Passing|Failing"
```

Expected: 408/408.

- [ ] **Step 6.6: Commit**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git add docs/perf.md docs/getting-started.md CHANGELOG.md addons/gtml/plugin.cfg && git commit -m "chore(v0.8.4): perf benchmark harness — docs + CHANGELOG + version

New docs/perf.md (how to run + what each group measures + caveats),
linked from getting-started. CHANGELOG 0.8.4 closes the v0.8
production-readiness line. plugin.cfg bumped to 0.8.4."
```

---

## Task 7: Push + open PR

- [ ] **Step 7.1: Push**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && git push -u origin feat/v0.8-perf-bench 2>&1 | tail -3
```

- [ ] **Step 7.2: Open PR**

```bash
cd /data/personal/projects/godot/godot-plugins-gtml && gh pr create --base master --title "v0.8.4: performance benchmark harness (informational)" --body "$(cat <<'EOF'
## Summary

Adds an informational benchmark harness that times GTML's hot paths and prints a ms/op + ops/sec table. Answers the "perf at scale — never measured" known unknown carried since v0.7. Measurement only — no engine changes.

## What it measures

- **pure `GmlVForReconciler.diff`** — LIS diff in isolation (append/prepend/replace/shuffle at N=100, 1000).
- **v-for build at scale** — full populate at N=10/100/500/1000.
- **v-for reconcile ops** — append/prepend/replace-one/shuffle on a 100-item keyed list (+ 500-item shuffle).
- **state.set fan-out** — one set firing K text bindings (K=10/100/500).
- **full view build** — `renderer.build` of a representative document.

## How to run

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json \
  -gtest=res://tests/perf/test_perf_bench.gd
```

Excluded from the default suite (gutconfig scopes to `tests/unit/`), so CI is unaffected. No wall-clock assertions — never flaky. A self-check verifies the `_bench` helper times only the operation.

## Stats

| | |
|---|---|
| Default suite | 408 (unchanged — perf file not collected) |
| New | 1 bench file (~260 LOC), docs/perf.md |
| Plugin version | 0.8.3 → 0.8.4 |

## Test plan

- [ ] Default suite: `… -gconfig=res://.gutconfig.json` → 408/408 (perf excluded)
- [ ] Bench: `… -gtest=res://tests/perf/test_perf_bench.gd` → 5 tests pass, five tables print with positive ops/sec

## Closes the v0.8 line

Expression operators (0.8.0) · v-for `:key` reconciliation (0.8.1) · dynamic `:class` re-resolution (0.8.2) · focus traversal (0.8.3) · perf harness (0.8.4). GTML is now production-usable for dynamic, keyboard/gamepad-navigable, reorderable game UIs.
EOF
)" 2>&1 | tail -3
```

---

## Self-Review

**Spec coverage** (against `docs/superpowers/specs/2026-05-28-perf-bench-design.md`):

- §1 What's measured (all synchronous) → Tasks 2–5 ✓ (build-at-scale rewritten to avoid await-in-lambda — flagged in Task 3)
- §2 Bench helper + output → Task 1 (`_bench`, `_print_header/_row`) ✓
- §3 Fixtures + lifecycle → Task 1 (`_build_view`, `make_items`), Task 5 (full-build `built`-array free) ✓
- §4 Verifying the harness → Task 1 (`test_bench_helper_sanity`) ✓
- §5 Test groups → Tasks 1–5 (5 `test_*`) ✓
- §6 Docs + version → Task 6 ✓
- §7 Phasing → 7 tasks ✓
- §8 Limitations → Task 6 docs ✓

**Placeholder scan:** none.

**Type consistency:** `_bench(label, n, iterations, op, setup, warmup, cleanup)` signature consistent across all call sites. `make_items`/`make_keys`/`_build_view`/`_print_header`/`_print_row` consistent. `GmlVForReconciler`, `GmlStyleResolver` referenced by class_name (preload fallback noted in Task 5).

**Key correctness flags surfaced inline:**
- await-in-lambda doesn't settle frames → Task 3 uses the no-await clear/populate version (the SECOND code block is authoritative).
- `state.set` equality short-circuit → reset uses `base.duplicate()` (fresh array) + distinct mutation arrays so ops always fire (Tasks 3, 4, 5).
- full-build roots freed after the timed loop, untimed (Task 5).
- `GmlStyleResolver` class_name availability → preload fallback noted (Task 5).
