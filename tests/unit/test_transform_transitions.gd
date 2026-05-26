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
