extends GutTest

## Snapshot tests for HTML + CSS parsers against the examples/ corpus.
## Locks current parser output so future refactors can be compared diff-by-diff.

const GmlHtmlParserScript = preload("res://addons/gtml/src/html_parser/GmlHtmlParser.gd")
const GmlCssParserScript = preload("res://addons/gtml/src/css/GmlCssParser.gd")
const GmlStyleResolverScript = preload("res://addons/gtml/src/css/GmlStyleResolver.gd")
const SnapshotHelper = preload("res://tests/unit/snapshot_helper.gd")

const EXAMPLES := [
	"basic",
	"all_elements",
	"flex_layout",
	"css_features",
	"transitions",
]


func _load_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "missing fixture: %s" % path)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _assert_snapshot(name: String, value: Variant) -> void:
	var result: Dictionary = GtmlSnapshotHelper.match_snapshot(name, value)
	match result.get("status", ""):
		"match":
			pass_test("snapshot match: %s" % name)
		"bootstrapped":
			fail_test("bootstrapped snapshot %s — review and commit %s" % [name, result["path"]])
		"diff":
			var exp_s: String = result.get("expected", "")
			var act_s: String = result.get("actual", "")
			var actual_path: String = result.get("actual_path", "(not written)")
			fail_test("snapshot diff: %s\nfull actual written to %s\n--- expected (first 2000) ---\n%s\n--- actual (first 2000) ---\n%s" % [
				name,
				actual_path,
				exp_s.substr(0, 2000),
				act_s.substr(0, 2000),
			])
		_:
			fail_test("snapshot helper error: %s" % result.get("msg", "?"))


func test_parser_dom_snapshots() -> void:
	for name in EXAMPLES:
		var html := _load_text("res://addons/gtml/examples/%s.html" % name)
		var parser = GmlHtmlParserScript.new()
		var dom = parser.parse(html)
		assert_not_null(dom, "parser returned null for %s" % name)
		_assert_snapshot("dom_%s" % name, GtmlSnapshotHelper.serialize_dom(dom))


func test_resolver_style_snapshots() -> void:
	for name in EXAMPLES:
		var html := _load_text("res://addons/gtml/examples/%s.html" % name)
		var css := _load_text("res://addons/gtml/examples/%s.css" % name)
		var parser = GmlHtmlParserScript.new()
		var dom = parser.parse(html)
		var css_parser = GmlCssParserScript.new()
		var rules = css_parser.parse(css)
		var resolver = GmlStyleResolverScript.new()
		var styles: Dictionary = resolver.resolve(dom, rules)
		_assert_snapshot("styles_%s" % name, GtmlSnapshotHelper.serialize_styles(dom, styles))
