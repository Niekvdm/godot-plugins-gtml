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
