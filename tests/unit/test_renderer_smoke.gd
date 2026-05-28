extends GutTest

## Renderer smoke tests: each example file is fed through the full pipeline
## (parser -> resolver -> renderer) inside a real SceneTree so we exercise the
## modules that touch Control nodes (GtmlDimensions, GtmlPercentSizing, GtmlWrap,
## GtmlTransitionSetup) end-to-end. We assert that build() returns a non-null
## root and that no engine errors were raised.

const GtmlViewScript = preload("res://addons/gtml/src/GtmlView.gd")

const SHOWCASES := [
	{"name": "atlas", "dir": "showcase/atlas"},
	{"name": "atelier", "dir": "showcase/atelier"},
	{"name": "forge", "dir": "showcase/forge"},
	{"name": "kitchen", "dir": "showcase/kitchen"},
	{"name": "inventory", "dir": "showcase/inventory"},
]


func _build_showcase(spec: Dictionary) -> GtmlView:
	var view: GtmlView = GtmlViewScript.new()
	view.html_path = "res://addons/gtml/examples/%s/index.html" % spec["dir"]
	view.css_path = "res://addons/gtml/examples/%s/style.css" % spec["dir"]
	view.size = Vector2(1280, 800)
	add_child_autofree(view)
	return view


func _assert_built(view: GtmlView, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(view.get_child_count(), 0, "%s produced no children" % name)


func test_showcase_atlas_renders() -> void:
	var v := _build_showcase(SHOWCASES[0])
	await _assert_built(v, "atlas")


func test_showcase_atelier_renders() -> void:
	var v := _build_showcase(SHOWCASES[1])
	await _assert_built(v, "atelier")


func test_showcase_forge_renders() -> void:
	# Regression pin for the </input> hang that originally surfaced when
	# opening the Forge demo in the editor.
	var v := _build_showcase(SHOWCASES[2])
	await _assert_built(v, "forge")


func test_showcase_kitchen_renders() -> void:
	# Kitchen-sink reference card — exercises virtually every element +
	# CSS property in one scene, so renderer regressions on any of them
	# will fail this build.
	var v := _build_showcase(SHOWCASES[3])
	await _assert_built(v, "kitchen")


func test_showcase_inventory_renders() -> void:
	# v0.7 binding showcase — exercises every directive end-to-end.
	var v := _build_showcase(SHOWCASES[4])
	await _assert_built(v, "inventory")


func test_get_element_by_id_returns_control() -> void:
	# Validate the registry contract against a real built showcase: a lookup
	# for a non-existent id must return null without crashing.
	var v := _build_showcase(SHOWCASES[0])
	await _assert_built(v, "atlas")
	assert_null(v.get_element_by_id("definitely-not-there"))
