extends GutTest

## Tests for GmlBindingRegistry — per-view {key → Array[binding]} reverse index.

func test_register_then_fire_invokes_applier() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	var binding := {
		"deps": ["score"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	}
	r.register(binding)
	r.fire("score")
	assert_eq(fired.size(), 1)


func test_fire_unrelated_key_does_not_invoke() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["score"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.fire("name")
	assert_eq(fired.size(), 0)


func test_multiple_deps_fire_on_any_key() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["a", "b"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.fire("a")
	r.fire("b")
	assert_eq(fired.size(), 2)


func test_clear_drops_all_bindings() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["a"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.clear()
	r.fire("a")
	assert_eq(fired.size(), 0)


func test_pruned_when_control_ref_freed() -> void:
	var r := GmlBindingRegistry.new()
	var ctrl := Control.new()
	add_child_autofree(ctrl)
	var ref: WeakRef = weakref(ctrl)
	r.register({
		"deps": ["x"],
		"apply": func(): pass,
		"control_ref": ref,
	})
	ctrl.queue_free()
	await get_tree().process_frame
	r.fire("x")
	assert_eq(r.binding_count(), 0, "freed-control binding should be pruned on fire")


func test_fire_batched_runs_each_binding_once() -> void:
	var r := GmlBindingRegistry.new()
	var fired: Array = []
	r.register({
		"deps": ["a", "b"],
		"apply": func(): fired.append(true),
		"control_ref": null,
	})
	r.fire_batch(["a", "b"])
	assert_eq(fired.size(), 1)
