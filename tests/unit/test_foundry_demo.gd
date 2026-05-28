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

func test_cost_scales_by_115_percent() -> void:
	var d = _new_demo()
	assert_eq(d.cost_of("intern"), 10)        # 10 * 1.15^0
	d.gen_owned["intern"] = 1
	assert_eq(d.cost_of("intern"), 11)        # floor(10 * 1.15)
	d.gen_owned["intern"] = 2
	assert_eq(d.cost_of("intern"), 13)        # floor(10 * 1.3225)

func test_per_sec_sums_owned_generators() -> void:
	var d = _new_demo()
	assert_eq(d.per_sec(), 0.0)
	d.gen_owned["intern"] = 2     # 2 * 0.5 = 1.0
	d.gen_owned["compiler"] = 1   # 1 * 4.0 = 4.0
	assert_almost_eq(d.per_sec(), 5.0, 0.0001)

func test_global_mult_scales_rate_with_insight() -> void:
	var d = _new_demo()
	d.gen_owned["intern"] = 1
	d.insight = 50              # mult = 1 + 50*0.02 = 2.0
	assert_almost_eq(d.effective_rate("intern"), 1.0, 0.0001)  # 0.5 * 1 * 2.0

func test_buy_generator_deducts_and_increments() -> void:
	var d = _new_demo()
	d.commits = 10.0
	assert_true(d.buy_generator("intern"))
	assert_eq(d._owned("intern"), 1)
	assert_almost_eq(d.commits, 0.0, 0.0001)

func test_buy_generator_fails_when_too_poor() -> void:
	var d = _new_demo()
	d.commits = 9.0
	assert_false(d.buy_generator("intern"))
	assert_eq(d._owned("intern"), 0)
	assert_almost_eq(d.commits, 9.0, 0.0001)

func test_buy_generator_uses_scaled_cost() -> void:
	var d = _new_demo()
	d.gen_owned["intern"] = 1   # next cost 11
	d.commits = 11.0
	assert_true(d.buy_generator("intern"))
	assert_eq(d._owned("intern"), 2)
