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
