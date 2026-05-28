# GTML v0.8.4 — Performance benchmark harness

**Date:** 2026-05-28
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.8.4 (final v0.8 production-readiness item)

## Summary

The v0.7/v0.8 specs repeatedly listed "perf at scale — never measured" as
a known unknown: full v-for rebuild on >100 items, keyed-reconcile cost,
binding fan-out. This PR adds an **informational** benchmark harness that
builds GTML views at scale, times the hot paths, and prints a table. It
is run on demand (not in CI), carries no assertions about wall-clock
budgets (so a slow machine never fails), and gives the numbers needed to
reason about whether a 1000-item HUD/list is viable.

## Goals

- Measure the four hot paths: v-for build at scale, v-for reconcile ops,
  the pure LIS diff, and state.set fan-out + full view build.
- Print a readable per-group table (total ms, ms/op, ops/sec).
- Run on demand; never part of the default CI suite; never flaky.
- Reuse the existing GUT headless view-build harness.

## Non-goals

- **CI regression gating / wall-clock budgets.** Informational only.
- **Machine-readable artifacts (JSON), trend tracking, charts.** Stdout
  table only. (A future PR could add artifacts.)
- **Micro-optimizing anything.** This PR measures; it does not change
  engine code. If a number is alarming, that's a separate follow-up.
- **Rendering/pixel perf.** We measure build + binding + reconcile CPU
  cost, not draw time.

## Architecture

```
tests/perf/test_perf_bench.gd   # NEW — GUT bench file, excluded from default suite
```

One file. The default suite is scoped by `.gutconfig.json` to
`res://tests/unit/` only, so a file under `tests/perf/` is naturally
excluded — no config change. Run explicitly:

```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/perf/test_perf_bench.gd
```

The file `extends GutTest`, reuses GUT's `add_child_autofree`, and a
local `_build_view(html, css)` helper (copied from the integration-test
pattern — writes temp fixture files, instantiates `GmlView`, autofrees).
A `_bench(...)` helper times an operation; each `test_*` method benches
one target group and prints a table.

## §1 — What's measured (all synchronous)

Every timed operation runs synchronously, so the timed region is a clean
`Time.get_ticks_usec()` delta with no `await`:

- **Pure diff** — `GmlVForReconciler.diff(old_keys, new_keys)`. Pure.
- **v-for build at scale** — build a view whose `<li v-for>` binds an
  initially-empty array, settle it (awaits, untimed), then time
  `view.state.set("items", make_items(N))`. The binding fires the
  reconciler synchronously (insert N clones) and returns. N ∈ {10, 100,
  500, 1000}.
- **v-for reconcile ops** — a settled view with N items; time each
  `state.set` for: append (N→N+1), prepend (prepend 1), replace-one
  (swap a middle element's identity), shuffle (reverse the array). N =
  100 (and a 500 row for shuffle to stress LIS).
- **state.set fan-out** — a view with K `{{ count }}` interpolations on
  one key; time `state.set("count", v)` (fires K bindings synchronously).
  K ∈ {10, 100, 500}.
- **full view build** — time `GmlRenderer.new().build(dom_root, styles,
  view)` on a pre-parsed representative DOM (synchronous render). The
  produced root is freed in `cleanup` (untimed).

Each bench runs `warmup` untimed iterations first (first-call import/JIT
noise), then `iterations` timed runs. Iteration counts scale inversely
with per-op cost (≈1000 for pure diff, ≈5 for 1000-item build).

## §2 — Bench helper + output

```gdscript
## Time `op` over `iterations` runs (after `warmup` untimed). `setup`
## (untimed, before each timed op) resets state so each iteration starts
## from the same baseline; `cleanup` (untimed, after each op) frees any
## object `op` produced. Only `op` is inside the timer.
func _bench(label: String, n: int, iterations: int, op: Callable, setup := Callable(), warmup := 2, cleanup := Callable()) -> void
```

Methodology:
1. Warmup: run (`setup`?) → `op` → (`cleanup`?), `warmup` times, untimed.
2. Timed: for each iteration — run `setup` untimed; `var t0 =
   Time.get_ticks_usec()`; run `op`; `total_usec += Time.get_ticks_usec()
   - t0`; run `cleanup` untimed.
3. Report:
   - `total_ms = total_usec / 1000.0`
   - `ms_per_op = total_ms / iterations`
   - `ops_per_sec = 1_000_000.0 * iterations / total_usec` (0 if total is 0)
4. Print one aligned row via `_print_row`.

Output (illustrative numbers):

```
── v-for build at scale ─────────────────────────────────────
operation              N    iters   total ms    ms/op    ops/sec
build_initial         10       20      12.40    0.620       1612
build_initial        100       20      88.10    4.405        227
build_initial        500       10     410.30   41.030         24
build_initial       1000        5     880.50  176.100          6
```

Helpers `_print_header(title)` + `_print_row(op, n, iters, total_ms,
ms_per_op, ops_sec)` keep columns aligned (use `String.pad` / `%` format
specifiers). Printed via `print()` (visible in the gut_cmdln console).

**No wall-clock assertions** in bench tests — an assertion-free GUT test
passes, so the harness never fails on a slow machine.

## §3 — Fixtures + object lifecycle

- **Item data**: `make_items(n)` → `[{"id": str(i), "name": "Item %d" %
  i}, …]`.
- **Views**: built via the local `_build_view(html, css)` (writes temp
  files under `res://tests/snapshots/.actual/perf_fixture/`, instantiates
  `GmlView`, `add_child_autofree`). Auto-freed at test end.
- **`cleanup` callable**: full-build bench stashes each built root and
  frees it untimed (peak memory = (iterations+warmup) roots, bounded by
  modest counts).
- **Reconcile churn note**: synchronous reconciles `queue_free` old
  clones (end-of-frame); across many timed iterations without frame
  yields they accumulate until the test's next frame. Mitigated by modest
  iteration counts on big-N benches; documented in a code comment so a
  reader doesn't mistake the transient growth for a leak.

## §4 — Verifying the harness

Bench tests have no assertions, so the file includes ONE self-check:

- `test_bench_helper_sanity`: runs `_bench` on a trivial op (e.g. an
  integer add loop) and asserts `ops_per_sec > 0`; AND benches an op
  paired with a deliberately slow `setup` (a busy-loop) and asserts the
  reported `ms_per_op` stays small — proving the timer excludes
  `setup`/`cleanup`.

Because `tests/perf/` is excluded from the default suite, this self-check
runs only when the perf dir/file is explicitly invoked. The
implementation's final step runs the bench file manually and confirms a
sane table prints + the self-check passes. (Full-suite count is
unchanged at 408 — the perf file is not collected by the default run.)

## §5 — Test groups (one `test_*` each)

1. `test_bench_helper_sanity` — the §4 self-check (the only assertions).
2. `test_perf_pure_diff` — `GmlVForReconciler.diff` for append / prepend /
   replace / shuffle at N=100, 1000.
3. `test_perf_vfor_build_scale` — initial populate at N=10/100/500/1000.
4. `test_perf_vfor_reconcile_ops` — append / prepend / replace-one /
   shuffle at N=100 (+ shuffle at N=500).
5. `test_perf_state_fanout_and_full_build` — state.set fan-out at K=10/
   100/500 + full `renderer.build` of a representative document.

## §6 — Docs + version

- `docs/perf.md` (NEW): how to run the bench, what each group measures,
  a note that numbers are machine-dependent + informational, and the
  reconcile-churn caveat. Linked from getting-started "Next Steps".
- `CHANGELOG.md`: 0.8.4 entry — completes the v0.8 production-readiness
  line; notes the bench is informational + how to run it.
- `addons/gtml/plugin.cfg`: 0.8.3 → 0.8.4.

## §7 — Phasing

Single PR:

1. `_bench` helper + `_build_view`/`make_items`/print helpers + the
   `test_bench_helper_sanity` self-check.
2. Pure-diff bench.
3. v-for build-at-scale bench.
4. v-for reconcile-ops bench.
5. state.set fan-out + full-build bench.
6. Docs (`docs/perf.md`) + CHANGELOG 0.8.4 + version bump.
7. Push + PR.

## §8 — Known limitations (documented)

- Numbers are machine- and load-dependent; informational, not a contract.
- Headless timing excludes GPU/draw cost (CPU build/binding/reconcile only).
- Reconcile-churn transient memory growth within a timed loop (not a leak).
- No historical tracking — each run is standalone stdout.

## §9 — Out of scope (deferred)

- CI perf gating / budgets.
- JSON artifacts, trend charts.
- Draw/render-time (GPU) profiling.
- Any engine optimization prompted by the numbers (separate follow-up).
