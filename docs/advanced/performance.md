# Performance

_How to run the GTML benchmark harness and what the five groups measure._

The benchmark harness lives in `tests/perf/test_perf_bench.gd`. It is
**excluded from the default test suite** — `.gutconfig.json` scopes GUT
to `tests/unit/`, so routine `gut_cmdln` runs never execute it. There are
no wall-clock pass/fail assertions; a slow machine never fails. All output
is printed as a formatted table.

---

## Running the benchmarks

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json \
  -gtest=res://tests/perf/test_perf_bench.gd
```

The `-gtest` flag bypasses the gutconfig scope and runs only the bench
file. The single assertion in the file (`test_bench_helper_sanity`) verifies
that the `_bench` helper excludes setup time from its measurements — it is
not a latency budget.

---

## Benchmark groups

### 1. Pure `GtmlVForReconciler.diff` — `test_perf_pure_diff`

Measures only the diff algorithm in isolation, with no scene tree
involvement. Runs four operations at `N = 100` and `N = 1000` keys, each
at 1000 iterations (200 for shuffle):

| Operation | Description |
|---|---|
| `diff_append` | New key-set = old + 1 extra key appended |
| `diff_prepend` | New key-set = 1 new key prepended to old |
| `diff_replace` | One middle key replaced by a new key `"X"` |
| `diff_shuffle` | Full reversal (LIS worst-ish case) |

### 2. v-for initial build at scale — `test_perf_vfor_build_scale`

Measures a full `state.set("items", items)` → reconcile → insert-N-clones
cycle starting from an empty list. Uses a real `GtmlView` with a settled
scene tree. The untimed setup clears the list; the timed op populates it.

Sizes tested: N = 10 (30 iters), 100 (20), 500 (8), 1000 (4).

### 3. v-for reconcile ops (keyed) — `test_perf_vfor_reconcile_ops`

Measures keyed reconciliation against a settled 100-item list. Each
operation is a single synchronous `state.set` that triggers one structural
change; the untimed reset always restores the baseline first.

| Operation | What changes |
|---|---|
| `append` | One item appended (101 items) |
| `prepend` | One item prepended (101 items) |
| `replace_one` | Item at index 50 replaced (different `id`) |
| `shuffle_reverse` | All 100 items reversed |
| `shuffle_reverse` at N=500 | 500-item full reversal (stresses LIS through scene mutation) |

### 4. `state.set` fan-out — `test_perf_state_fanout_and_full_build`

The first part of this group measures how long a single `state.set` takes
when K text bindings all subscribe to the same key. The timed op
increments a counter each call to ensure the state actually changes (the
registry short-circuits on equal values).

K values tested: 10, 100, 500 (200 iterations each).

### 5. Full `GtmlRenderer.build` — same group

The second part times only `GtmlRenderer.build` with a pre-parsed DOM and
pre-resolved styles. The representative document is a `<header>` + 50
`<li>` items + `<footer>` with minimal CSS. HTML parsing and CSS
resolution are excluded from the timed region (done once in untimed setup).

50 iterations.

---

## Caveats

- **Machine-dependent.** Results vary with CPU speed and load. There are
  no reference baselines stored in the repo.
- **CPU only.** No GPU draw calls occur in headless mode; visual rendering
  cost is not captured.
- **Reconcile churn is transient.** Clone nodes created by `v-for` inserts
  call `queue_free`, which defers destruction to the next frame. Memory
  usage temporarily spikes during a large insert run and settles on the
  following frame.
- **No historical tracking.** The harness prints tables but does not write
  results to disk or compare against prior runs. Trend analysis requires
  manual comparison.

---

## See also

- [Bindings guide](../guide/bindings.md)
- [Limitations](limitations.md)
