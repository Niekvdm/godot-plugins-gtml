# GTML v0.8 — v-for keyed reconciliation

**Date:** 2026-05-27
**Status:** Design approved, awaiting implementation plan
**Target release:** v0.8.1 (second of four v0.8 production-readiness PRs)

## Summary

v0.7's `v-for` tears down every child of the host on any change to the
bound array and rebuilds them from scratch. A 100-item inventory
where one item's quantity changed rebuilds 100 Controls and re-registers
100 sets of bindings. Worse for game UI: input focus jumps, scroll
position resets, hover states blink, in-flight animations restart.

v0.8.1 replaces the rebuild with a Vue-3-style **LIS-based keyed
reconciler** that preserves Control identity across array changes.
Authors opt into stable identity with `:key="item.id"`; without it,
the array index is the default key.

```html
<li v-for="item in inventory" :key="item.id">
  <input :value="item.name">
  <button @click="remove(item)">x</button>
</li>
```

After `state.set("inventory", [items.shuffled()])`: the `<input>` that
had focus before the shuffle still has focus afterwards; only DOM
positions move.

## Goals

- Preserve Control identity (focus, scroll, hover state, in-flight
  animations) when array items are reordered, inserted, or removed.
- Make 100+ item v-fors viable for real-time HUDs.
- Document the `:key` recommendation as the production-ready pattern.
- Keep the API surface identical for authors who don't add `:key` —
  default-index key gives them automatic reuse for stable-order lists,
  and the same tear-down they had before only triggers when keys
  genuinely don't match.

## Non-goals

- Cross-list reuse (item moves from `<ul>` to `<ol>`). Vue doesn't
  support this either; out of scope.
- Lazy / virtualized rendering. Different problem (only render visible
  rows).
- Server / network sync. Same shape as v-model: state changes,
  reconciler reacts.
- `<TransitionGroup>` for staggered reorder animations. v0.9 if needed.

## Architecture

Three concrete changes:

1. **New module** `addons/gtml/src/binding/GmlVForReconciler.gd` —
   pure-data LIS diff. Takes `(old_keys, new_keys)` → returns ops list.
   No scene-tree access; trivially unit-testable.
2. **`GmlBindingRegistry` extension** — `register(binding, tag)` gains
   a default-empty `tag` parameter; new `prune_tag(tag)` removes a
   group of bindings without affecting others. Lets the reconciler
   free a clone's bindings cleanly when the clone is removed.
3. **`GmlRenderer` refactor** — replace the tear-down-rebuild closure
   in `_maybe_expand_v_for_children` with a reconcile flow that keeps
   per-host state (`current_keys`, `controls`, `binding_tags`) attached
   as meta on the parent control.

```
addons/gtml/src/binding/
  GmlVForReconciler.gd          # NEW — LIS diff (~150 LOC)
  GmlBindingRegistry.gd         # MODIFY — +tag/prune_tag (~30 LOC delta)
addons/gtml/src/html_renderer/
  GmlRenderer.gd                # MODIFY — replace rebuild with reconcile (~120 LOC delta)
tests/unit/
  test_vfor_reconciler.gd       # NEW — 14 reconciler tests
  test_binding_registry.gd      # MODIFY — +4 tag tests
  test_binding_integration.gd   # MODIFY — +6 end-to-end tests
docs/bindings.md                # MODIFY — :key section
CHANGELOG.md                    # MODIFY — 0.8.1 entry
addons/gtml/plugin.cfg          # MODIFY — 0.8.0 → 0.8.1
```

## §1 — Key extraction

`v-for` syntax unchanged. The optional `:key` attribute lives on the
same element as `v-for` and is read once during expansion. The
expression is evaluated per-element against the loop scope.

```html
<li v-for="item in items" :key="item.id">{{ item.name }}</li>
```

Resolution rules:

- **`:key` present and resolves to non-null** → `str(value)` is the key.
- **`:key` present but resolves to null / empty string** → treated as
  unique-per-render anonymous key (clone never reused). Warn once per
  v-for site.
- **`:key` parse error** → fall back to index key, warn.
- **`:key` absent** → key is `str(index)` (the clone's position).

Keys are always strings (string-coerced) so Dictionary lookup is stable.

## §2 — Reconciler API

`GmlVForReconciler` is a static `RefCounted` (matches the project's
pure-engine convention — `GmlBindingParser`, `GmlBindingApplier`).

```gdscript
class_name GmlVForReconciler
extends RefCounted

## Pure-data LIS-based key diff. No Godot scene access.
##
## Input:
##   old_keys: PackedStringArray  # previous render order
##   new_keys: PackedStringArray  # requested order
## Output: Array of Dictionary ops, in execution order:
##   {op: "remove", key: String, from_index: int}
##   {op: "insert", key: String, to_index: int}
##   {op: "move",   key: String, from_index: int, to_index: int}
##
## Reuse-without-move is implicit (omitted from ops). Caller applies
## ops by: removing in descending from_index order, then inserting +
## moving in ascending to_index order — emitted that way already.
##
## Duplicate keys in new_keys trigger _warn + empty ops. Caller treats
## empty ops on a non-empty new_keys as "abort, no render change".

static func diff(old_keys: PackedStringArray, new_keys: PackedStringArray) -> Array
```

Algorithm: Vue 3's `patchKeyedChildren` shape.

1. Common-prefix scan: walk both arrays from `0` while keys match.
2. Common-suffix scan: walk from the end inward while keys match.
3. Build `new_key → new_index` map for the middle. Detect duplicates →
   `GmlBindingApplier._warn("v-for duplicate key: %s" % key)` + return `[]`.
4. For each old middle key: if not in new map, emit `remove`; else
   record `index_array[new_pos] = old_pos`.
5. LIS on `index_array` → set of new positions that DON'T need to
   move. Walk new middle backward:
   - new key not in old map → `insert`
   - new key in old map AND new position in LIS → no op
   - new key in old map AND new position NOT in LIS → `move`

Worst-case O(n log n) from the LIS computation; O(n) for typical
mutations (append, prepend, single remove/insert) because the prefix
or suffix consumes the entire array.

## §3 — Renderer integration

`GmlRenderer._maybe_expand_v_for_children` currently calls a `rebuild`
closure on array change that frees everything and re-expands. Replace
that closure with a reconcile flow.

### Per-host state

Attached as meta on the parent control (the dispatched container that
holds the v-for clones as siblings):

```gdscript
{
    "_vfor_state": {
        # Keyed by the template GmlNode's get_instance_id() so multiple
        # v-fors in one parent (rare but legal) don't collide.
        <template_node_id: int>: {
            "current_keys": PackedStringArray,
            "controls": Dictionary,         # key (String) → Control
            "binding_tags": Dictionary,     # key (String) → String
            "first_child_index": int,       # parent-relative offset of clone 0
            "key_expr": Variant,            # parsed AST of :key OR null
            "spec": Dictionary,             # {loop_var, index_var, array_key}
            "template_node": GmlNode,
            "binding_scope_parent": Dictionary,
        }
    }
}
```

### Build flow

**Initial render** (state's `current_keys` is empty):

1. Iterate the bound array. For each item, compute the key (see §1).
2. Detect duplicate keys → warn + render nothing for this v-for.
3. Build each clone via the existing `_clone_dom_node` + `_stamp_scope`
   + `_build_node` chain. Each clone's bindings are registered with a
   unique tag: `"vfor_%d_%s" % [template_id, str(key)]`.
4. Add clones as siblings of the parent at `first_child_index +
   clone_index`.
5. Stash `current_keys`, `controls`, `binding_tags` on the parent's meta.

**Subsequent renders** (array changed → registry fires the v-for binding):

1. Compute `new_keys` per the current array.
2. Compare with `current_keys`. Identical → return (no DOM ops).
3. Call `GmlVForReconciler.diff(current_keys, new_keys)`. Empty ops on
   non-empty `new_keys` means duplicates → return (warning already
   emitted by reconciler).
4. Apply ops in the order the reconciler returned them:
   - **`remove`**: `parent._binding_registry.prune_tag(state.binding_tags[key])`,
     `parent.remove_child(state.controls[key])`, `state.controls[key].queue_free()`,
     drop from dicts.
   - **`insert`**: build a new clone (`_clone_dom_node` + `_stamp_scope` +
     `_build_node` with a fresh binding tag), `parent.add_child(new_clone)`,
     `parent.move_child(new_clone, first_child_index + to_index)`.
   - **`move`**: `parent.move_child(state.controls[key], first_child_index + to_index)`.
     If `spec.index_var != ""`, update the clone's scope meta:
     `clone.get_meta("_binding_scope")[spec.index_var] = to_index`, then
     `_fire_clone_bindings(registry, state.binding_tags[key])` (§5).
5. Update state: `current_keys = new_keys`, refresh `controls` (key
   mapping unchanged for reused, removed for removes, added for inserts).

### `first_child_index`

The v-for region is embedded among the parent's other siblings:

```html
<div>
  <h1>Header</h1>
  <li v-for="x in xs">...</li>
  <p>Footer</p>
</div>
```

The Header child sits at parent index 0, the v-for clones at indices
1..N, the Footer at N+1. The reconciler emits positions RELATIVE TO
the v-for region (0-based); the renderer offsets by `first_child_index`
when calling `move_child` / `add_child`.

`first_child_index` is captured once during initial render by counting
non-v-for parent children whose original DOM position precedes the
v-for template's. It's stable for the lifetime of the v-for because
siblings around it don't reorder (only the v-for region reconciles).

## §4 — Registry tagging

`GmlBindingRegistry` gains tag-based grouping. Bindings registered
without a tag are never region-pruned; they're freed only by
registry-wide `clear()` (the existing behavior).

```gdscript
var _by_tag: Dictionary = {}   # tag → Array[binding]


func register(binding: Dictionary, tag: String = "") -> void:
    _all.append(binding)
    var deps: Array = binding.get("deps", [])
    for dep in deps:
        if not _by_key.has(dep):
            _by_key[dep] = []
        _by_key[dep].append(binding)
    if not tag.is_empty():
        if not _by_tag.has(tag):
            _by_tag[tag] = []
        _by_tag[tag].append(binding)
        binding["_tag"] = tag


func prune_tag(tag: String) -> void:
    if not _by_tag.has(tag):
        return
    var doomed: Dictionary = {}
    for b in _by_tag[tag]:
        doomed[b.get("apply")] = true
    for k in _by_key.keys():
        _by_key[k] = (_by_key[k] as Array).filter(func(b): return not doomed.has(b.get("apply")))
    _all = _all.filter(func(b): return not doomed.has(b.get("apply")))
    _by_tag.erase(tag)
```

`clear()` also clears `_by_tag`. Call sites in v0.7/v0.8 that pass no
tag continue working (default empty string).

A renderer helper `_register_clone_bindings(clone_node, control, tag)`
wraps the existing `_register_bindings_for_node` to thread the tag
through every binding registered during a clone's build.

## §5 — Index re-eval helper

When a clone moves and `spec.index_var` is declared, the clone's
`_binding_scope` Dictionary has stale `index_var`. Since the bindings
captured the scope dict reference (not a copy), mutating the dict in
place is enough to refresh the data the closures see — we just need
to re-fire the apply functions.

```gdscript
static func _fire_clone_bindings(registry: GmlBindingRegistry, tag: String) -> void:
    if not registry._by_tag.has(tag):
        return
    for b in registry._by_tag[tag]:
        if GmlBindingRegistry._is_alive(b):
            b["apply"].call()
```

When `spec.index_var == ""`, the helper is skipped — moves don't need
re-eval because no binding references the index.

**Item-identity case** (item reference changed at the same key): per
the design decision, we only re-eval on **index change**, not on item
mutation. If the author replaces an array element with a new dict at
the same key, the OLD clone's scope still points at the OLD dict.
Documented limitation: keep keys stable AND update with new dict
instances if you want field updates to propagate. Future work could
add a deep-equality option or a force-refresh signal.

## §6 — Testing plan

| File | Existing | Added | Total |
|---|---|---|---|
| `test_binding_registry.gd` | 6 | +4 | 10 |
| `test_vfor_reconciler.gd` | 0 | +14 | 14 (new file) |
| `test_binding_integration.gd` | 25 | +6 | 31 |

Total: 341 → **365** (24 new).

### Reconciler tests (pure-data, no scene)

- No-op fast path (identical arrays).
- All append: `[a,b]` → `[a,b,c,d]` → 2 inserts.
- All prepend: `[c,d]` → `[a,b,c,d]` → 2 inserts at 0,1.
- All remove: `[a,b,c]` → `[]` → 3 removes.
- Middle remove: `[a,b,c,d]` → `[a,c,d]` → 1 remove.
- Single move: `[a,b,c]` → `[c,a,b]` → 1 move.
- Reverse: `[a,b,c,d]` → `[d,c,b,a]` → minimal moves via LIS.
- Replace one: `[a,b,c]` → `[a,x,c]` → 1 remove + 1 insert.
- Common prefix + middle change.
- Common suffix.
- Empty → populated.
- Populated → empty.
- Duplicate keys: `[a,b,b]` → empty ops + warn captured.
- LIS smoke: `[1,2,3,4,5]` → `[3,1,2,4,5]` → at most 1 move.

### Registry tag tests

- Tagged binding still fires on `fire(key)`.
- `prune_tag(t)` then `fire(key)` → bindings under `t` do NOT fire.
- Multi-tag isolation: prune one tag, others survive.
- `prune_tag("nonexistent")` is no-op.

### Integration tests through `GmlView`

- Focus preservation across append.
- Control identity preserved across reorder (object reference check).
- Index re-eval: `{{ i }}: {{ x }}` updates after reorder.
- Default-index key reconciliation works without `:key`.
- Custom `:key` preserves identity across permutation.
- Duplicate key warns + aborts (DOM unchanged).

## §7 — Phasing

Single bundled PR. Tasks:

1. `GmlVForReconciler` skeleton + 14 reconciler tests (TDD, pure-data).
2. `GmlBindingRegistry` tag API + 4 tests.
3. Renderer refactor — extract per-host state, wire reconciler ops.
4. `:key` extraction in expansion (with eval + warn paths).
5. Index re-eval helper + integration tests.
6. Docs update + CHANGELOG 0.8.1 entry.
7. Version bump.

## §8 — Known unknowns

- **Animation interaction.** Existing GTML transitions fire on style
  changes via `GmlTransitionManager`. Preserving Control identity means
  in-flight transitions ALSO survive — desirable for hover states,
  potentially surprising for reorder animations (none currently). Spec
  acknowledges this is the correct default.
- **State recovery on re-enter.** Removed clones lose their bindings.
  If an item is removed then re-added (same key) the new clone starts
  fresh — no inherited focus/scroll. Vue behaves identically. Document.
- **Perf at scale.** Plan ships without a benchmark; the next blocker
  (PR #3 of v0.8) adds perf bench infrastructure. The reconciler
  itself is O(n log n); the per-op cost (build clone / register
  bindings) dominates and is per-item.

## §9 — Out of scope (deferred)

- Two-pass reconciliation (insert before remove, or vice versa).
  Single-pass ordered ops are enough for current needs.
- `:key` with computed expressions referencing scope vars outside the
  current clone. Spec says expression evaluates in the loop scope;
  outer references are by name as usual.
- Cross-tree move (drag-and-drop item between two v-for lists). Each
  v-for reconciles independently.
- Transition-group-style "leave" / "enter" animations.
