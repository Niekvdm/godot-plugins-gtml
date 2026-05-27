extends GutTest

## Tests for GmlBindingExpr — the mini-expression parser.

func test_parse_simple_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("score")
	assert_eq(ast["type"], "path")
	assert_eq(ast["parts"], PackedStringArray(["score"]))


func test_parse_dotted_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("player.health")
	assert_eq(ast["type"], "path")
	assert_eq(ast["parts"], PackedStringArray(["player", "health"]))


func test_parse_deep_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("a.b.c.d")
	assert_eq(ast["parts"], PackedStringArray(["a", "b", "c", "d"]))


func test_parse_negation() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("!loading")
	assert_eq(ast["type"], "neg")
	assert_eq(ast["inner"]["type"], "path")
	assert_eq(ast["inner"]["parts"], PackedStringArray(["loading"]))


func test_parse_negation_dotted_path() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("!player.invincible")
	assert_eq(ast["type"], "neg")
	assert_eq(ast["inner"]["parts"], PackedStringArray(["player", "invincible"]))


func test_parse_string_double_quoted() -> void:
	var ast: Dictionary = GmlBindingExpr.parse('"hello"')
	assert_eq(ast["type"], "string")
	assert_eq(ast["value"], "hello")


func test_parse_string_single_quoted() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("'world'")
	assert_eq(ast["type"], "string")
	assert_eq(ast["value"], "world")


func test_parse_object_literal_single_entry() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_active }")
	assert_eq(ast["type"], "object")
	assert_eq(ast["entries"].size(), 1)
	assert_eq(ast["entries"][0]["key"], "active")
	assert_eq(ast["entries"][0]["value"]["type"], "path")
	assert_eq(ast["entries"][0]["value"]["parts"], PackedStringArray(["is_active"]))


func test_parse_object_literal_multiple_with_negation() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("{ active: is_active, dim: !is_active }")
	assert_eq(ast["entries"].size(), 2)
	assert_eq(ast["entries"][0]["key"], "active")
	assert_eq(ast["entries"][1]["key"], "dim")
	assert_eq(ast["entries"][1]["value"]["type"], "neg")


func test_parse_array_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("['static', dynamic_key]")
	assert_eq(ast["type"], "array")
	assert_eq(ast["items"].size(), 2)
	assert_eq(ast["items"][0]["type"], "string")
	assert_eq(ast["items"][0]["value"], "static")
	assert_eq(ast["items"][1]["type"], "path")


func test_parse_call_no_args() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("handler()")
	assert_eq(ast["type"], "call")
	assert_eq(ast["name"], "handler")
	assert_eq(ast["args"].size(), 0)


func test_parse_call_one_arg() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("select(item)")
	assert_eq(ast["type"], "call")
	assert_eq(ast["name"], "select")
	assert_eq(ast["args"].size(), 1)
	assert_eq(ast["args"][0]["type"], "path")
	assert_eq(ast["args"][0]["parts"], PackedStringArray(["item"]))


func test_parse_call_multiple_args() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("select(item, index)")
	assert_eq(ast["args"].size(), 2)
	assert_eq(ast["args"][0]["parts"], PackedStringArray(["item"]))
	assert_eq(ast["args"][1]["parts"], PackedStringArray(["index"]))


func test_parse_malformed_returns_error() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("{ unclosed")
	assert_eq(ast["type"], "error")
	assert_true("message" in ast)


# ─── Number literals + parens + ident hyphen drop (Task 2) ───

func test_parse_integer_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("42")
	assert_eq(ast["type"], "number")
	assert_eq(ast["value"], 42.0)


func test_parse_float_literal() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("3.14")
	assert_eq(ast["type"], "number")
	assert_eq(ast["value"], 3.14)


func test_parse_zero() -> void:
	var ast: Dictionary = GmlBindingExpr.parse("0")
	assert_eq(ast["type"], "number")
	assert_eq(ast["value"], 0.0)


func test_parse_parenthesized_path() -> void:
	# Parens are transparent — must collapse back to the inner AST.
	var ast: Dictionary = GmlBindingExpr.parse("(score)")
	assert_eq(ast["type"], "path")
	assert_eq(ast["parts"], PackedStringArray(["score"]))


func test_parse_ident_hyphens_no_longer_accepted() -> void:
	# v0.7 accepted "data-n" as one ident; v0.8 stops there and errors
	# (since the next token is unexpected).
	var ast: Dictionary = GmlBindingExpr.parse("data-n")
	# Either treated as error OR parsed up to 'data' then trailing chars.
	# Spec says "trailing chars at pos N" — either reading is acceptable.
	assert_eq(ast["type"], "error")
