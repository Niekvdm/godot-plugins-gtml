extends GutTest

## Tests for GmlSearchEngine — find/replace ops on a string.

func test_find_all_literal_case_sensitive() -> void:
	var text := "foo Foo FOO\nfoo"
	var matches = GmlSearchEngine.find_all(text, "foo", true, false)
	assert_eq(matches.size(), 2, "case-sensitive 'foo' should match exactly 2 times")
	assert_eq(matches[0]["line"], 0)
	assert_eq(matches[0]["col"], 0)
	assert_eq(matches[0]["length"], 3)
	assert_eq(matches[1]["line"], 1)
	assert_eq(matches[1]["col"], 0)


func test_find_all_literal_case_insensitive() -> void:
	var text := "foo Foo FOO"
	var matches = GmlSearchEngine.find_all(text, "foo", false, false)
	assert_eq(matches.size(), 3)


func test_find_all_regex() -> void:
	var text := "abc123 def456"
	var matches = GmlSearchEngine.find_all(text, "\\d+", true, true)
	assert_eq(matches.size(), 2)
	assert_eq(matches[0]["length"], 3)


func test_find_all_empty_query_returns_no_matches() -> void:
	var matches = GmlSearchEngine.find_all("foo", "", true, false)
	assert_eq(matches.size(), 0)


func test_find_all_no_matches() -> void:
	var matches = GmlSearchEngine.find_all("hello world", "xyz", true, false)
	assert_eq(matches.size(), 0)


func test_replace_all_literal() -> void:
	var result = GmlSearchEngine.replace_all("foo bar foo", "foo", "qux", true, false)
	assert_eq(result["new_text"], "qux bar qux")
	assert_eq(result["count"], 2)


func test_replace_all_regex_with_backreference() -> void:
	var result = GmlSearchEngine.replace_all("abc-123 def-456", "([a-z]+)-(\\d+)", "$2-$1", true, true)
	assert_eq(result["new_text"], "123-abc 456-def")
	assert_eq(result["count"], 2)


func test_replace_all_case_insensitive() -> void:
	var result = GmlSearchEngine.replace_all("Foo foo FOO", "foo", "bar", false, false)
	assert_eq(result["new_text"], "bar bar bar")
	assert_eq(result["count"], 3)


func test_replace_all_no_matches_unchanged() -> void:
	var result = GmlSearchEngine.replace_all("hello", "xyz", "qux", true, false)
	assert_eq(result["new_text"], "hello")
	assert_eq(result["count"], 0)


func test_invalid_regex_returns_zero_matches_no_crash() -> void:
	# Unterminated bracket
	var matches = GmlSearchEngine.find_all("abc", "[unclosed", true, true)
	assert_eq(matches.size(), 0)
	var result = GmlSearchEngine.replace_all("abc", "[unclosed", "x", true, true)
	assert_eq(result["count"], 0)
	assert_eq(result["new_text"], "abc")
	# RegEx.compile() pushes engine errors for malformed patterns; mark them
	# handled so the test passes (the whole point is graceful degradation).
	for err in get_errors():
		err.handled = true
