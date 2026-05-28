extends GutTest

## Tests for GtmlSearchEngine — find/replace ops on a string.

func test_find_all_literal_case_sensitive() -> void:
	var text := "foo Foo FOO\nfoo"
	var matches = GtmlSearchEngine.find_all(text, "foo", true, false)
	assert_eq(matches.size(), 2, "case-sensitive 'foo' should match exactly 2 times")
	assert_eq(matches[0]["line"], 0)
	assert_eq(matches[0]["col"], 0)
	assert_eq(matches[0]["length"], 3)
	assert_eq(matches[1]["line"], 1)
	assert_eq(matches[1]["col"], 0)


func test_find_all_literal_case_insensitive() -> void:
	var text := "foo Foo FOO"
	var matches = GtmlSearchEngine.find_all(text, "foo", false, false)
	assert_eq(matches.size(), 3)


func test_find_all_regex() -> void:
	var text := "abc123 def456"
	var matches = GtmlSearchEngine.find_all(text, "\\d+", true, true)
	assert_eq(matches.size(), 2)
	assert_eq(matches[0]["length"], 3)


func test_find_all_empty_query_returns_no_matches() -> void:
	var matches = GtmlSearchEngine.find_all("foo", "", true, false)
	assert_eq(matches.size(), 0)


func test_find_all_no_matches() -> void:
	var matches = GtmlSearchEngine.find_all("hello world", "xyz", true, false)
	assert_eq(matches.size(), 0)


func test_replace_all_literal() -> void:
	var result = GtmlSearchEngine.replace_all("foo bar foo", "foo", "qux", true, false)
	assert_eq(result["new_text"], "qux bar qux")
	assert_eq(result["count"], 2)


func test_replace_all_regex_with_backreference() -> void:
	var result = GtmlSearchEngine.replace_all("abc-123 def-456", "([a-z]+)-(\\d+)", "$2-$1", true, true)
	assert_eq(result["new_text"], "123-abc 456-def")
	assert_eq(result["count"], 2)


func test_replace_all_case_insensitive() -> void:
	var result = GtmlSearchEngine.replace_all("Foo foo FOO", "foo", "bar", false, false)
	assert_eq(result["new_text"], "bar bar bar")
	assert_eq(result["count"], 3)


func test_replace_all_no_matches_unchanged() -> void:
	var result = GtmlSearchEngine.replace_all("hello", "xyz", "qux", true, false)
	assert_eq(result["new_text"], "hello")
	assert_eq(result["count"], 0)


func test_invalid_regex_returns_zero_matches_no_crash() -> void:
	# Unterminated bracket
	var matches = GtmlSearchEngine.find_all("abc", "[unclosed", true, true)
	assert_eq(matches.size(), 0)
	var result = GtmlSearchEngine.replace_all("abc", "[unclosed", "x", true, true)
	assert_eq(result["count"], 0)
	assert_eq(result["new_text"], "abc")
	# RegEx.compile() pushes engine errors for malformed patterns; mark them
	# handled so the test passes (the whole point is graceful degradation).
	for err in get_errors():
		err.handled = true


func test_replace_all_with_empty_replacement_deletes_matches() -> void:
	# Common "delete all matches" use case.
	var result = GtmlSearchEngine.replace_all("hello world hello ", "hello ", "", true, false)
	assert_eq(result["new_text"], "world ")
	assert_eq(result["count"], 2)


func test_find_all_regex_with_anchors() -> void:
	# ^ and $ anchors should bind to line boundaries with multiline mode.
	var text := "foo\nbar\nfoo"
	# (?m) enables multiline so ^ / $ match line boundaries
	var matches = GtmlSearchEngine.find_all(text, "(?m)^foo$", true, true)
	assert_eq(matches.size(), 2, "multiline ^foo$ should match lines 0 and 2, got %d" % matches.size())


func test_find_all_regex_caret_anchor_without_multiline() -> void:
	# Without (?m), ^ only matches the very start of the string.
	var text := "foo\nfoo\nfoo"
	var matches = GtmlSearchEngine.find_all(text, "^foo", true, true)
	assert_eq(matches.size(), 1, "single ^foo should match only the first occurrence, got %d" % matches.size())
