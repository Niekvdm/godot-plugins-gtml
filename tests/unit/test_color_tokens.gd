extends GutTest

## Tests for GtmlColorTokens — scan a buffer for color literals and round-trip
## values back to text.

func test_scan_finds_six_digit_hex() -> void:
	var tokens = GtmlColorTokens.scan("color: #ff8800;")
	assert_eq(tokens.size(), 1)
	var t = tokens[0]
	assert_eq(t["kind"], "hex")
	assert_eq(t["length"], 7)
	assert_almost_eq(t["color"].r, 1.0, 0.01)
	assert_almost_eq(t["color"].g, 0.533, 0.01)


func test_scan_finds_three_digit_hex() -> void:
	var tokens = GtmlColorTokens.scan(".a { color: #f80; }")
	assert_eq(tokens.size(), 1)
	assert_eq(tokens[0]["length"], 4)


func test_scan_finds_eight_digit_hex_with_alpha() -> void:
	var tokens = GtmlColorTokens.scan("bg: #00aaff80;")
	assert_eq(tokens.size(), 1)
	assert_eq(tokens[0]["length"], 9)
	assert_almost_eq(tokens[0]["color"].a, 0.502, 0.01)


func test_scan_finds_rgb_function() -> void:
	var tokens = GtmlColorTokens.scan("color: rgb(128, 64, 200);")
	assert_eq(tokens.size(), 1)
	assert_eq(tokens[0]["kind"], "rgb")
	assert_almost_eq(tokens[0]["color"].r, 0.502, 0.01)


func test_scan_finds_rgba_function() -> void:
	var tokens = GtmlColorTokens.scan("bg: rgba(255, 0, 0, 0.5);")
	assert_eq(tokens.size(), 1)
	assert_eq(tokens[0]["kind"], "rgba")
	assert_almost_eq(tokens[0]["color"].a, 0.5, 0.01)


func test_scan_multiple_per_line() -> void:
	var tokens = GtmlColorTokens.scan("gradient: #ff0000, #00ff00, #0000ff;")
	assert_eq(tokens.size(), 3)
	assert_lt(tokens[0]["col"], tokens[1]["col"])
	assert_lt(tokens[1]["col"], tokens[2]["col"])


func test_scan_rgb_without_spaces() -> void:
	# Common in minified CSS: no whitespace between args.
	var tokens = GtmlColorTokens.scan("color: rgb(255,64,200);")
	assert_eq(tokens.size(), 1)
	assert_eq(tokens[0]["kind"], "rgb")


func test_scan_ignores_malformed_hex() -> void:
	var tokens = GtmlColorTokens.scan("not-a-color: #xyz; nor: #12;")
	assert_eq(tokens.size(), 0)


func test_format_round_trip_hex() -> void:
	var out := GtmlColorTokens.format(Color(1.0, 0.533, 0.0, 1.0), "hex")
	assert_eq(out, "#ff8800")


func test_format_round_trip_rgba_alpha_below_one() -> void:
	var out := GtmlColorTokens.format(Color(1.0, 0.0, 0.0, 0.5), "rgba")
	# Lock the exact format string so future refactors can't drift.
	assert_eq(out, "rgba(255, 0, 0, 0.50)")
