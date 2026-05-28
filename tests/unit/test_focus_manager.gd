extends GutTest

## Tests for GmlFocusManager.wire_focus — builds synthetic Control trees
## with stamped _gml_* focus meta, runs wire_focus, asserts the chain.

const FM = preload("res://addons/gtml/src/focus/GmlFocusManager.gd")


## Make a focusable Control with the given tabindex; add to `parent`.
func _focusable(parent: Control, tabindex: int = 0, tab_skip: bool = false) -> Control:
	var c := Control.new()
	c.set_meta("_gml_focusable", true)
	c.set_meta("_gml_tabindex", tabindex)
	c.set_meta("_gml_tab_skip", tab_skip)
	parent.add_child(c)
	return c


func _root() -> Control:
	var r := Control.new()
	add_child_autofree(r)
	return r


func test_two_focusables_chain_in_dom_order() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b, "a.focus_next → b")
	assert_eq(b.get_node(b.focus_previous), a, "b.focus_previous → a")


func test_non_focusable_excluded() -> void:
	var r := _root()
	var a := _focusable(r)
	var plain := Control.new()
	r.add_child(plain)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b)


func test_focusables_get_focus_all_is_callers_job_not_wire() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b)


func test_tab_skip_excluded_from_chain() -> void:
	var r := _root()
	var a := _focusable(r)
	var skip := _focusable(r, -1, true)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b)
	assert_eq(skip.focus_next, NodePath(""))


func test_positive_tabindex_ordered_before_natural() -> void:
	var r := _root()
	var b := _focusable(r, 2)
	var a := _focusable(r, 0)
	var c := _focusable(r, 1)
	FM.wire_focus(r)
	assert_eq(c.get_node(c.focus_next), b, "c(1) → b(2)")
	assert_eq(b.get_node(b.focus_next), a, "b(2) → a(0 natural)")


func test_positive_tabindex_tie_broken_by_doc_order() -> void:
	var r := _root()
	var first := _focusable(r, 1)
	var second := _focusable(r, 1)
	FM.wire_focus(r)
	assert_eq(first.get_node(first.focus_next), second, "equal tabindex → doc order")


func test_focus_trap_group_wraps() -> void:
	var r := _root()
	var trap := Control.new()
	trap.set_meta("_gml_focus_trap", true)
	r.add_child(trap)
	var a := _focusable(trap)
	var b := _focusable(trap)
	FM.wire_focus(r)
	assert_eq(b.get_node(b.focus_next), a, "trap last wraps to first")
	assert_eq(a.get_node(a.focus_previous), b, "trap first wraps to last")


func test_root_group_does_not_wrap() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(b.focus_next, NodePath(""), "root last does NOT wrap")
	assert_eq(a.focus_previous, NodePath(""), "root first does NOT wrap")


func test_nested_trap_isolated_from_outer() -> void:
	var r := _root()
	var outer_a := _focusable(r)
	var trap := Control.new()
	trap.set_meta("_gml_focus_trap", true)
	r.add_child(trap)
	var inner_a := _focusable(trap)
	var inner_b := _focusable(trap)
	FM.wire_focus(r)
	assert_eq(inner_b.get_node(inner_b.focus_next), inner_a, "inner wraps within trap")
	assert_eq(outer_a.focus_next, NodePath(""), "outer_a alone in root group")


func test_find_autofocus_returns_first_in_doc_order() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	b.set_meta("_gml_autofocus", true)
	var c := _focusable(r)
	c.set_meta("_gml_autofocus", true)
	assert_eq(FM.find_autofocus(r), b, "first autofocus in doc order wins")


func test_first_tabbable_respects_tabindex_not_doc_order() -> void:
	# DOM order: b(natural), a(tabindex=5). Tab order puts a first.
	var r := _root()
	var b := _focusable(r, 0)
	var a := _focusable(r, 5)
	assert_eq(FM.first_tabbable(r), a, "positive tabindex wins over doc order")


func test_first_tabbable_skips_trapped_and_tab_skip() -> void:
	var r := _root()
	var skip := _focusable(r, -1, true)
	var trap := Control.new()
	trap.set_meta("_gml_focus_trap", true)
	r.add_child(trap)
	var trapped := _focusable(trap)
	var root_btn := _focusable(r)
	# first_tabbable ignores the tab_skip element and the trapped one,
	# returning the first real root-group stop.
	assert_eq(FM.first_tabbable(r), root_btn)


func test_first_tabbable_empty_returns_null() -> void:
	var r := _root()
	assert_null(FM.first_tabbable(r))


func test_empty_tree_no_crash() -> void:
	var r := _root()
	FM.wire_focus(r)
	assert_null(FM.find_autofocus(r))


func test_idempotent_rewire() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	FM.wire_focus(r)
	assert_eq(a.get_node(a.focus_next), b, "second wire yields same chain")
	assert_eq(b.focus_next, NodePath(""), "still no root wrap")


func test_neighbor_bottom_top_mirror_next_previous() -> void:
	var r := _root()
	var a := _focusable(r)
	var b := _focusable(r)
	FM.wire_focus(r)
	assert_eq(a.focus_neighbor_bottom, a.focus_next, "bottom mirrors next")
	assert_eq(b.focus_neighbor_top, b.focus_previous, "top mirrors previous")
