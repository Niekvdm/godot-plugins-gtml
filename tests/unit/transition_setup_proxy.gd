class_name GtmlTransitionSetupTestProxy
extends RefCounted

## Test-only proxy that exposes GtmlTransitionSetup's private helpers so they
## can be unit-tested without instantiating a Control / SceneTree.
##
## Lives under tests/ rather than addons/ so it ships with the test suite,
## not with the addon itself.

static func strip_state_keys(style: Dictionary) -> Dictionary:
	return GtmlTransitionSetup._strip_state_keys(style)


static func collect_state_buckets(style: Dictionary) -> Array:
	return GtmlTransitionSetup._collect_state_buckets(style)


static func compute_target(base: Dictionary, buckets: Array, active: Dictionary) -> Dictionary:
	return GtmlTransitionSetup._compute_target(base, buckets, active)
