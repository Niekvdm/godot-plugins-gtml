extends GutTest

const DemoScript := preload("res://addons/gtml/examples/showcase/foundry/demo.gd")

func _new_demo():
	# demo.gd extends Control; .new() makes a bare instance (no _ready until tree-added).
	return autofree(DemoScript.new())

func test_fmt_below_thousand_is_plain_int() -> void:
	var d = _new_demo()
	assert_eq(d.fmt(0.0), "0")
	assert_eq(d.fmt(42.0), "42")
	assert_eq(d.fmt(999.0), "999")

func test_fmt_uses_suffixes() -> void:
	var d = _new_demo()
	assert_eq(d.fmt(1000.0), "1.00K")
	assert_eq(d.fmt(1500000.0), "1.50M")
	assert_eq(d.fmt(2300000000.0), "2.30B")
