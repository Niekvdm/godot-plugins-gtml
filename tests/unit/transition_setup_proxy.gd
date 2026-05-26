class_name GtmlTransitionSetupTestProxy
extends RefCounted

## Test-only proxy that exposes GmlTransitionSetup's private helpers so they
## can be unit-tested without instantiating a Control / SceneTree.
##
## Lives under tests/ rather than addons/ so it ships with the test suite,
## not with the addon itself.

static func strip_state_keys(style: Dictionary) -> Dictionary:
	return GmlTransitionSetup._strip_state_keys(style)


static func collect_state_buckets(style: Dictionary) -> Array:
	return GmlTransitionSetup._collect_state_buckets(style)


static func compute_target(base: Dictionary, buckets: Array, active: Dictionary) -> Dictionary:
	return GmlTransitionSetup._compute_target(base, buckets, active)
