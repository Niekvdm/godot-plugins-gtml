extends GutTest

## Informational performance benchmarks for GTML. NOT part of the default
## suite (gutconfig scopes to tests/unit/). Run explicitly:
##   godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json \
##     -gtest=res://tests/perf/test_perf_bench.gd
##
## Bench tests print tables and carry NO wall-clock assertions, so a slow
## machine never fails. The single self-check test verifies the _bench
## helper times only the operation (excludes setup/cleanup).

const GtmlViewScript = preload("res://addons/gtml/src/GtmlView.gd")
const GtmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GtmlHtmlParser.gd")
const GtmlCssParserScript = preload("res://addons/gtml/src/css/GtmlCssParser.gd")
const GtmlRendererScript = preload("res://addons/gtml/src/html_renderer/GtmlRenderer.gd")

# Captured by the most recent _bench call so the self-check can inspect it.
var _last_ms_per_op: float = 0.0
var _last_ops_per_sec: float = 0.0


## Build a GtmlView from inline HTML/CSS (writes temp fixture files).
func _build_view(html: String, css: String = "") -> GtmlView:
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
	var view: GtmlView = GtmlViewScript.new()
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


# ─── Slow setup helper for self-check ──────────────────────

func _slow_setup() -> void:
	var burn: int = 0
	for _b in 50000:
		burn += 1


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
		_slow_setup
	)
	assert_lt(_last_ms_per_op, 1.0, "timed region must exclude the slow setup")


# ─── Pure GtmlVForReconciler.diff ───────────────────────────

func test_perf_pure_diff() -> void:
	_print_header("pure GtmlVForReconciler.diff")
	for n in [100, 1000]:
		var old_keys := make_keys(n)

		# append: new = old + 1 extra key
		var appended := make_keys(n)
		appended.append(str(n))
		_bench("diff_append", n, 1000, func(): GtmlVForReconciler.diff(old_keys, appended))

		# prepend: new = [new_key] + old
		var prepended := PackedStringArray([str(n)])
		prepended.append_array(old_keys)
		_bench("diff_prepend", n, 1000, func(): GtmlVForReconciler.diff(old_keys, prepended))

		# replace one middle key
		var replaced := old_keys.duplicate()
		replaced[n / 2] = "X"
		_bench("diff_replace", n, 1000, func(): GtmlVForReconciler.diff(old_keys, replaced))

		# shuffle: reverse the array (LIS worst-ish case)
		var reversed := PackedStringArray()
		for i in range(n - 1, -1, -1):
			reversed.append(old_keys[i])
		_bench("diff_shuffle", n, 200, func(): GtmlVForReconciler.diff(old_keys, reversed))

	assert_true(true)  # keep GUT happy (informational test, no perf assertion)


# ─── v-for initial build at scale ──────────────────────────

func test_perf_vfor_build_scale() -> void:
	_print_header("v-for build at scale (initial populate)")
	for spec in [[10, 30], [100, 20], [500, 8], [1000, 4]]:
		var n: int = spec[0]
		var iters: int = spec[1]
		var items := make_items(n)
		# Pre-build + settle ONE view per N (the body can await; lambdas can't).
		var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
		await get_tree().process_frame
		await get_tree().process_frame
		# setup (untimed) clears the list → reconcile removes all → empty.
		# op (timed) populates → reconcile inserts n clones from empty.
		# Both are synchronous. Clones from the clear queue_free within the
		# loop; transient growth, not a leak (settles next frame).
		_bench("build_initial", n, iters,
			func(): view.state.set("items", items),
			func(): view.state.set("items", []),
			1
		)
	assert_true(true)

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

	# One settled view; setup resets to a FRESH base copy (untimed), op
	# applies the mutation (timed). Each op is a single synchronous
	# reconcile. base.duplicate() differs from the prior op array, so the
	# reset always fires; the mutation arrays differ from base, so ops fire.
	var view := _build_view('<ul><li v-for="item in items" :key="item.id">{{ item.name }}</li></ul>')
	await get_tree().process_frame
	await get_tree().process_frame

	var reset := func(): view.state.set("items", base.duplicate())

	_bench("append", 100, 50, func(): view.state.set("items", appended), reset)
	_bench("prepend", 100, 50, func(): view.state.set("items", prepended), reset)
	_bench("replace_one", 100, 50, func(): view.state.set("items", replaced), reset)
	_bench("shuffle_reverse", 100, 30, func(): view.state.set("items", reversed), reset)

	# Shuffle at N=500 to stress LIS through the full scene-mutating reconcile.
	var base500 := make_items(500)
	var reversed500: Array = []
	for i in range(499, -1, -1):
		reversed500.append(base500[i])
	view.state.set("items", base500)
	await get_tree().process_frame
	var reset500 := func(): view.state.set("items", base500.duplicate())
	_bench("shuffle_reverse", 500, 10, func(): view.state.set("items", reversed500), reset500)

	assert_true(true)


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
	var dom = GtmlHtmlParserScript.new().parse(html)
	var rules = GtmlCssParserScript.new().parse(css)
	var resolver = GtmlStyleResolver.new()
	var styles = resolver.resolve(dom, rules)
	var host_view := _build_view("<div></div>")
	await get_tree().process_frame
	var built: Array = []
	_bench("renderer_build", 50, 30,
		func(): built.append(GtmlRendererScript.new().build(dom, styles, host_view))
	)
	# Free all built roots (untimed, after the loop).
	for b in built:
		if is_instance_valid(b):
			(b as Node).free()

	assert_true(true)
