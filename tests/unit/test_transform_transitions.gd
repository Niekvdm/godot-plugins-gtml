extends GutTest

## v0.5: transition manager interpolates the transform property —
## scale (Vector2), rotation (float), and translate offset (Vector2)
## animate together when transform appears in a transitioned :hover/:focus
## state bucket.

const GmlTransitionManagerScript = preload("res://addons/gtml/src/html_renderer/GmlTransitionManager.gd")


func _control() -> Control:
	var c := Control.new()
	c.size = Vector2(100, 50)
	add_child_autofree(c)
	return c


func _transitions(duration_ms: int = 0) -> Array:
	return [{
		"property": "transform",
		"duration": duration_ms / 1000.0,
		"timing": {"trans_type": Tween.TRANS_LINEAR, "ease_type": Tween.EASE_IN_OUT},
		"delay": 0.0,
	}]


func test_transform_scale_applied_via_zero_duration_transition() -> void:
	# duration: 0 short-circuits to immediate apply — exercises the dispatch
	# path without waiting for tween frames.
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	var to := {"transform": {"translate": Vector2.ZERO, "scale": Vector2(1.5, 1.5), "rotate": 0.0}}
	manager.transition_style(c, from, to, _transitions(0))
	assert_eq(c.scale, Vector2(1.5, 1.5))


func test_transform_rotate_applied_via_zero_duration_transition() -> void:
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	var to := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": PI / 4.0}}
	manager.transition_style(c, from, to, _transitions(0))
	assert_almost_eq(c.rotation, PI / 4.0, 0.001)


func test_transform_reverts_to_base_when_target_has_no_transform() -> void:
	# Going from a scaled state back to a style with no transform should
	# reset to identity (scale=1, rotation=0, no translate offset).
	var c := _control()
	c.scale = Vector2(1.5, 1.5)
	c.rotation = 0.3
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2(1.5, 1.5), "rotate": 0.3}}
	var to := {}  # no transform key in target
	manager.transition_style(c, from, to, _transitions(0))
	assert_eq(c.scale, Vector2.ONE, "scale should revert to 1 when target has no transform")
	assert_almost_eq(c.rotation, 0.0, 0.001)


func test_transform_with_duration_eventually_reaches_target_value() -> void:
	# Real tween path — kick off a short animation, wait it out, verify the
	# final value matches the target. Catches setup-but-no-tween bugs.
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	var to := {"transform": {"translate": Vector2.ZERO, "scale": Vector2(1.2, 1.2), "rotate": 0.0}}
	manager.transition_style(c, from, to, _transitions(50))
	# Wait long enough for the 50ms tween to finish.
	await get_tree().create_timer(0.15).timeout
	assert_eq(c.scale, Vector2(1.2, 1.2))


func test_transform_intermediate_frame_is_between_endpoints() -> void:
	# Mid-animation, scale must be strictly between from and to. Confirms
	# the tween is actually interpolating, not snapping at frame 0 or N.
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	var to := {"transform": {"translate": Vector2.ZERO, "scale": Vector2(2.0, 2.0), "rotate": 0.0}}
	manager.transition_style(c, from, to, _transitions(200))
	await get_tree().create_timer(0.08).timeout
	# Roughly 40% through: scale.x should be ~1.4, definitely between 1 and 2.
	assert_true(c.scale.x > 1.05 and c.scale.x < 1.95,
		"mid-tween scale.x should be strictly between 1 and 2, got %s" % c.scale.x)


#region Review fixups


func test_transform_combined_with_color_both_fire() -> void:
	# A single transition list with two animated properties should drive
	# both — verifies the dispatch loop isn't short-circuiting after the
	# transform branch.
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {
		"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0},
		"opacity": 1.0,
	}
	var to := {
		"transform": {"translate": Vector2.ZERO, "scale": Vector2(1.4, 1.4), "rotate": 0.0},
		"opacity": 0.5,
	}
	var transitions := [
		{"property": "transform", "duration": 0.0, "timing": {}, "delay": 0.0},
		{"property": "opacity", "duration": 0.0, "timing": {}, "delay": 0.0},
	]
	manager.transition_style(c, from, to, transitions)
	assert_eq(c.scale, Vector2(1.4, 1.4))
	assert_almost_eq(c.modulate.a, 0.5, 0.001)


func test_transform_interruption_continues_from_live_value() -> void:
	# Start a 200ms tween; halfway through, request a new transition with
	# a different target. The new tween must pick up from the LIVE scale,
	# not snap back to the original from_value.
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	var to_big := {"transform": {"translate": Vector2.ZERO, "scale": Vector2(2.0, 2.0), "rotate": 0.0}}
	manager.transition_style(c, from, to_big, _transitions(200))
	await get_tree().create_timer(0.08).timeout
	var mid := c.scale.x
	assert_true(mid > 1.05 and mid < 1.95, "setup: mid-tween value should be between, got %s" % mid)

	# Now reverse course; the snap-prevention fix should leave the next
	# frame near the live mid value, not at 2 (where the from for the
	# reverse animation was) or 1 (the original baseline).
	var to_small := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	manager.transition_style(c, to_big, to_small, _transitions(200))
	await get_tree().process_frame
	# After one frame the new tween hasn't moved much — scale.x should be
	# within a hair of the live mid value, not snapped to 2.
	assert_true(abs(c.scale.x - mid) < 0.5,
		"second tween should continue from live %s, got %s (snapped?)" % [mid, c.scale.x])


func test_transform_translate_reverts_when_base_lacks_transform_meta() -> void:
	# Atelier .side-item-link case: base style has NO transform, so
	# GmlDimensions never stamps _transform_base_position. The transition
	# manager should stamp it lazily on first hover so the revert returns
	# to the original layout position.
	var c := Control.new()
	c.position = Vector2(40, 80)
	add_child_autofree(c)
	var manager = GmlTransitionManagerScript.new()

	# Hover-in: translate by +2px
	var from := {}  # no transform
	var to := {"transform": {"translate": Vector2(2, 0), "scale": Vector2.ONE, "rotate": 0.0}}
	manager.transition_style(c, from, to, _transitions(0))
	assert_eq(c.position, Vector2(42, 80), "hover-in should translate +2 from layout position")

	# Hover-out: target style omits transform — should revert to (40, 80)
	manager.transition_style(c, to, {}, _transitions(0))
	assert_eq(c.position, Vector2(40, 80), "hover-out should revert to layout position")


func test_transform_delay_is_honored() -> void:
	# Start a tween with a 60ms delay + 100ms duration. At t=20ms (still
	# in delay), scale should be unchanged. At t=200ms (after full run),
	# it should be at the target.
	var c := _control()
	var manager = GmlTransitionManagerScript.new()
	var from := {"transform": {"translate": Vector2.ZERO, "scale": Vector2.ONE, "rotate": 0.0}}
	var to := {"transform": {"translate": Vector2.ZERO, "scale": Vector2(1.5, 1.5), "rotate": 0.0}}
	var transitions := [{
		"property": "transform",
		"duration": 0.1,
		"timing": {"trans_type": Tween.TRANS_LINEAR, "ease_type": Tween.EASE_IN_OUT},
		"delay": 0.06,
	}]
	manager.transition_style(c, from, to, transitions)
	await get_tree().create_timer(0.02).timeout
	# Mid-delay: scale should still be 1 (delay not yet expired).
	# Some Tween impls might start slightly early; allow a small tolerance.
	assert_true(c.scale.x < 1.1, "delay window should keep scale near 1, got %s" % c.scale.x)
	await get_tree().create_timer(0.25).timeout
	assert_eq(c.scale, Vector2(1.5, 1.5), "post-delay+duration: should reach target")


#endregion
