# GTML Editor — v0.6 Professional Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add VSCode/Sublime-style power tools — autocomplete, find & replace, jumps, color picker, multi-cursor — to the GML editor panel.

**Architecture:** Five pure-data engines under `addons/gtml/src/editor/` feed CodeEdit's native UI from `addons/gtml/editor/gml_editor_panel.gd`. Engines are static-method-only `RefCounted`s that operate on `(text, cursor, …)` and return data, so they can be unit-tested without instantiating the panel.

**Tech Stack:** Godot 4.6 GDScript, GUT 9.6 test framework, CodeEdit native APIs (`code_completion_*`, gutter APIs, multiple_carets_enabled).

**Reference spec:** `docs/superpowers/specs/2026-05-26-editor-pro-design.md`

---

## Pre-flight

**The plan assumes:**
- You're working on `feat/v0.6-editor-pro` branched from `master` (or the latest merged release). If the v0.5 PR (#11) is still open and you want clean separation, branch from `master` and cherry-pick the spec commit from `feat/v0.5-transform-transitions-polish-docs` if needed.
- Existing test command: `timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`
- Test count baseline at the start of this plan: **162 tests** (whatever's on master after v0.5 merges).

**Commit message convention** (matches existing history):

```
type(scope): summary line under 70 chars

Multi-paragraph body explaining what and why. No Co-Authored-By line —
the project strips Claude attribution from commits.
```

`type` is one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.

---

## File Structure

**New module files** (created in Task 1, populated across Tasks 2–7):

```
addons/gtml/src/editor/
  GmlEditorContext.gd          # shared buffer-state struct
  GmlAutocompleteSource.gd     # candidate generator
  GmlJumpResolver.gd           # cursor-context → jump target
  GmlSearchEngine.gd           # find/replace ops
  GmlColorTokens.gd            # color-literal scanner
```

**New test files:**

```
tests/unit/test_editor_context.gd
tests/unit/test_autocomplete_source.gd
tests/unit/test_jump_resolver.gd
tests/unit/test_search_engine.gd
tests/unit/test_color_tokens.gd
tests/unit/test_editor_panel_v06.gd     # integration
```

**Modified files:**

```
addons/gtml/editor/gml_editor_panel.gd  # ~700 LOC → ~900 LOC after wiring
addons/gtml/editor/gml_editor_panel.tscn # add Replace row to SearchBar
addons/gtml/plugin.cfg                   # version bump
CHANGELOG.md                             # new v0.6.0 section
docs/editor.md                           # new — editor features reference
docs/getting-started.md                  # add link to docs/editor.md
```

---

## Task 1: Engine scaffold + GmlEditorContext

**Files:**
- Create: `addons/gtml/src/editor/GmlEditorContext.gd`
- Create: `addons/gtml/src/editor/GmlAutocompleteSource.gd` (empty stub)
- Create: `addons/gtml/src/editor/GmlJumpResolver.gd` (empty stub)
- Create: `addons/gtml/src/editor/GmlSearchEngine.gd` (empty stub)
- Create: `addons/gtml/src/editor/GmlColorTokens.gd` (empty stub)
- Create: `tests/unit/test_editor_context.gd`

- [ ] **Step 1.1: Write failing test for GmlEditorContext.from_html**

Create `tests/unit/test_editor_context.gd`:

```gdscript
extends GutTest

## Tests for GmlEditorContext — the shared "current buffer state" struct
## passed to autocomplete + jump + color engines.

func test_from_html_captures_kind_and_cursor() -> void:
    var ctx = GmlEditorContext.from_html("<div></div>", 2, 5, "<p></p>")
    assert_eq(ctx.kind, "html")
    assert_eq(ctx.text, "<div></div>")
    assert_eq(ctx.cursor_line, 2)
    assert_eq(ctx.cursor_col, 5)
    assert_eq(ctx.other_text, "<p></p>")


func test_from_css_captures_kind_and_cursor() -> void:
    var ctx = GmlEditorContext.from_css("div {}", 0, 3, "<div></div>")
    assert_eq(ctx.kind, "css")
    assert_eq(ctx.text, "div {}")
    assert_eq(ctx.cursor_line, 0)
    assert_eq(ctx.cursor_col, 3)
    assert_eq(ctx.other_text, "<div></div>")


func test_line_at_returns_indexed_line() -> void:
    var ctx = GmlEditorContext.from_html("<div>\n<p>x</p>\n</div>", 1, 0, "")
    assert_eq(ctx.line_at(0), "<div>")
    assert_eq(ctx.line_at(1), "<p>x</p>")
    assert_eq(ctx.line_at(2), "</div>")


func test_prefix_at_cursor_returns_text_before_cursor_on_current_line() -> void:
    var ctx = GmlEditorContext.from_css("div {\n  color: red;\n}", 1, 9, "")
    # Line 1 is "  color: red;"; col 9 is just after "color: re"
    assert_eq(ctx.prefix_at_cursor(), "  color: re")
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_editor_context.gd 2>&1 | tail -15
```

Expected: tests fail with "Identifier 'GmlEditorContext' not declared".

- [ ] **Step 1.3: Implement GmlEditorContext**

Create `addons/gtml/src/editor/GmlEditorContext.gd`:

```gdscript
class_name GmlEditorContext
extends RefCounted

## Snapshot of the editor's current buffer + cursor state, passed by value
## to the autocomplete / jump / color engines.
##
## ``text`` is the buffer the user is editing; ``other_text`` is the paired
## buffer (HTML when editing CSS and vice versa) so cross-buffer queries
## like "list class names declared in the CSS" can read from it without
## the engine needing a reference to the editor panel.

var kind: String = ""             # "html" | "css"
var text: String = ""             # active buffer
var other_text: String = ""       # paired buffer
var cursor_line: int = 0          # 0-based
var cursor_col: int = 0           # 0-based

var _lines: PackedStringArray = PackedStringArray()


static func from_html(text: String, line: int, col: int, css_text: String) -> GmlEditorContext:
    return _make("html", text, line, col, css_text)


static func from_css(text: String, line: int, col: int, html_text: String) -> GmlEditorContext:
    return _make("css", text, line, col, html_text)


static func _make(kind: String, text: String, line: int, col: int, other: String) -> GmlEditorContext:
    var c := GmlEditorContext.new()
    c.kind = kind
    c.text = text
    c.cursor_line = line
    c.cursor_col = col
    c.other_text = other
    c._lines = text.split("\n")
    return c


func line_at(idx: int) -> String:
    if idx < 0 or idx >= _lines.size():
        return ""
    return _lines[idx]


## Returns the text on the current line up to (but not including) the cursor
## column. Used as the canonical input to context-classifying regexes.
func prefix_at_cursor() -> String:
    var line: String = line_at(cursor_line)
    var c: int = clampi(cursor_col, 0, line.length())
    return line.substr(0, c)
```

- [ ] **Step 1.4: Create empty engine stubs**

Create `addons/gtml/src/editor/GmlAutocompleteSource.gd`:

```gdscript
class_name GmlAutocompleteSource
extends RefCounted

## Generates autocomplete candidates for a given editor context.
## Populated in Task 2.

static func get_candidates(_ctx: GmlEditorContext) -> Array:
    return []
```

Create `addons/gtml/src/editor/GmlJumpResolver.gd`:

```gdscript
class_name GmlJumpResolver
extends RefCounted

## Resolves a cursor position to a jump target.
## Populated in Task 4.

static func resolve(_ctx: GmlEditorContext) -> Variant:
    return null
```

Create `addons/gtml/src/editor/GmlSearchEngine.gd`:

```gdscript
class_name GmlSearchEngine
extends RefCounted

## Find / replace ops on a buffer.
## Populated in Task 3.

static func find_all(_text: String, _query: String, _case_sensitive: bool, _use_regex: bool) -> Array:
    return []
```

Create `addons/gtml/src/editor/GmlColorTokens.gd`:

```gdscript
class_name GmlColorTokens
extends RefCounted

## Scans a buffer for color literals.
## Populated in Task 5.

static func scan(_text: String) -> Array:
    return []
```

- [ ] **Step 1.5: Re-import + run tests**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_editor_context.gd 2>&1 | tail -10
```

Expected: 4/4 pass.

- [ ] **Step 1.6: Run the full test suite to confirm no regression**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head -3
```

Expected: all previous tests pass + 4 new = baseline + 4.

- [ ] **Step 1.7: Commit**

```bash
git add addons/gtml/src/editor/ tests/unit/test_editor_context.gd
git commit -m "feat(editor): scaffold src/editor/ engine modules

GmlEditorContext is the shared {text, cursor, other_text, kind} snapshot
passed to all engines so they stay free of EditorInterface dependencies
and can be unit-tested without instantiating the panel.

Adds four empty engine stubs (GmlAutocompleteSource, GmlJumpResolver,
GmlSearchEngine, GmlColorTokens) that subsequent tasks populate.

4 new tests pin the context API."
```

---

## Task 2: Autocomplete engine

**Files:**
- Modify: `addons/gtml/src/editor/GmlAutocompleteSource.gd`
- Create: `tests/unit/test_autocomplete_source.gd`

This task is large. Split into 5 sub-stages, each TDD'd separately:

### 2a — HTML tag completion

- [ ] **Step 2a.1: Write failing tests for HTML tag context**

Create `tests/unit/test_autocomplete_source.gd`:

```gdscript
extends GutTest

## Tests for GmlAutocompleteSource — the engine that, given a buffer +
## cursor context, returns candidate completions. Each candidate is a
## Dictionary: {label: String, kind: String, insert_text: String}.
##
## kind values: "tag" | "attr" | "value" | "property" | "var" | "class"

func _html_ctx(text: String, line: int, col: int) -> GmlEditorContext:
    return GmlEditorContext.from_html(text, line, col, "")


func _css_ctx(text: String, line: int, col: int, html: String = "") -> GmlEditorContext:
    return GmlEditorContext.from_css(text, line, col, html)


func _labels(candidates: Array) -> PackedStringArray:
    var out := PackedStringArray()
    for c in candidates:
        out.append(c["label"])
    return out


#region HTML tag completion

func test_html_tag_completion_after_open_bracket() -> void:
    # Cursor just past the < — expect a list of element tag names.
    var ctx = _html_ctx("<", 0, 1)
    var candidates = GmlAutocompleteSource.get_candidates(ctx)
    var labels = _labels(candidates)
    for tag in ["div", "p", "button", "input", "section", "h1", "ul", "li"]:
        assert_true(tag in labels, "missing expected tag '%s' from candidates" % tag)
    # And every candidate's kind is "tag"
    for c in candidates:
        assert_eq(c["kind"], "tag")


func test_html_tag_completion_filters_by_typed_prefix() -> void:
    # The engine returns ALL tags; the popup filters by prefix natively.
    # We just need the data to be there.
    var ctx = _html_ctx("<bu", 0, 3)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    assert_true("button" in labels)


#endregion
```

- [ ] **Step 2a.2: Run, confirm fail**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_autocomplete_source.gd 2>&1 | tail -10
```

Expected: 2 fails (empty candidates list).

- [ ] **Step 2a.3: Implement HTML tag detection + tag list**

Replace `GmlAutocompleteSource.gd` contents with:

```gdscript
class_name GmlAutocompleteSource
extends RefCounted

## Generates autocomplete candidates for a given editor context.
##
## Returns an Array of Dictionaries: {label, kind, insert_text}.
## kind ∈ {"tag", "attr", "value", "property", "var", "class"}.
## insert_text is what the editor writes — may include the typed prefix
## or a snippet (e.g. <div></div> with caret position implied).

const HTML_TAGS := [
    "a", "article", "aside", "b", "br", "button", "div", "em",
    "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header",
    "hr", "i", "img", "input", "label", "li", "main", "nav", "ol",
    "option", "p", "progress", "section", "select", "span", "strong",
    "svg", "textarea", "ul",
]


static func get_candidates(ctx: GmlEditorContext) -> Array:
    if ctx.kind == "html":
        return _html_candidates(ctx)
    if ctx.kind == "css":
        return _css_candidates(ctx)
    return []


static func _html_candidates(ctx: GmlEditorContext) -> Array:
    var prefix := ctx.prefix_at_cursor()
    # Inside a tag, but before any attribute? `<` or `<tagstart` with no space yet.
    var open := prefix.rfind("<")
    var close := prefix.rfind(">")
    if open >= 0 and open > close:
        # We're inside an open tag and not yet at a space.
        var inside := prefix.substr(open + 1)
        if not inside.contains(" "):
            return _tag_candidates()
    return []


static func _tag_candidates() -> Array:
    var out: Array = []
    for tag in HTML_TAGS:
        out.append({"label": tag, "kind": "tag", "insert_text": tag})
    return out


static func _css_candidates(_ctx: GmlEditorContext) -> Array:
    return []
```

- [ ] **Step 2a.4: Run, confirm pass**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_autocomplete_source.gd 2>&1 | tail -8
```

Expected: 2/2 pass.

### 2b — HTML attribute completion

- [ ] **Step 2b.1: Write failing tests**

Append to `tests/unit/test_autocomplete_source.gd`:

```gdscript
#region HTML attribute completion

func test_html_attr_completion_after_tag_and_space() -> void:
    # Cursor after "<div " — expect attribute names.
    var ctx = _html_ctx("<div ", 0, 5)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    for attr in ["class", "id", "title", "aria-node"]:
        assert_true(attr in labels)


func test_html_attr_completion_tag_specific_input() -> void:
    # <input attrs include type/value/checked/name/disabled
    var ctx = _html_ctx("<input ", 0, 7)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    for attr in ["type", "value", "checked", "name", "disabled", "placeholder"]:
        assert_true(attr in labels, "missing input-specific attr '%s'" % attr)


func test_html_attr_completion_tag_specific_label() -> void:
    var ctx = _html_ctx("<label ", 0, 7)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    assert_true("for" in labels, "<label> should suggest 'for'")


func test_html_attr_value_completion_for_type() -> void:
    # Inside type="…" — expect input-type keywords.
    var ctx = _html_ctx('<input type="', 0, 13)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    for v in ["text", "password", "checkbox", "radio", "range", "submit"]:
        assert_true(v in labels)

#endregion
```

- [ ] **Step 2b.2: Run, confirm fail**

Expected: 4 fails.

- [ ] **Step 2b.3: Implement attribute + value detection**

Replace `_html_candidates` in `GmlAutocompleteSource.gd`:

```gdscript
# Attributes valid for each known tag. Falls back to CORE_ATTRS otherwise.
const CORE_ATTRS := ["class", "id", "title", "aria-node", "@click", "style"]

const TAG_ATTRS := {
    "input": ["type", "value", "checked", "name", "placeholder", "disabled", "@click", "@keydown"],
    "label": ["for"],
    "a": ["href", "@click"],
    "img": ["src", "alt"],
    "button": ["disabled", "@click"],
    "form": ["@submit"],
    "textarea": ["disabled", "placeholder", "@keydown"],
    "select": ["name", "disabled"],
    "option": ["value", "selected"],
    "progress": ["value", "max"],
}

# Values for enumerated attributes. Tag-keyed so <input type=…> differs
# from any hypothetical other tag.
const ATTR_VALUES := {
    "type:input": ["text", "password", "email", "number", "checkbox", "radio", "range", "submit"],
}


static func _html_candidates(ctx: GmlEditorContext) -> Array:
    var prefix := ctx.prefix_at_cursor()
    var open := prefix.rfind("<")
    var close := prefix.rfind(">")
    if open < 0 or open <= close:
        return []

    var inside := prefix.substr(open + 1)

    # Are we still in the tag-name part? (no whitespace yet)
    if not inside.contains(" "):
        return _tag_candidates()

    # Are we inside an attribute value? Look for an unclosed quote.
    var quote_open := _last_unclosed_quote(inside)
    if quote_open >= 0:
        # Find the attr name to the left of the quote: pattern is `attr="`.
        var head := inside.substr(0, quote_open)
        var eq := head.rfind("=")
        if eq < 0:
            return []
        var attr_name := head.substr(0, eq).strip_edges().get_slice(" ", head.substr(0, eq).strip_edges().get_slice_count(" ") - 1)
        var tag_name := _tag_at_start(inside)
        return _attr_value_candidates(tag_name, attr_name)

    # Otherwise we're picking an attribute name.
    var tag_name := _tag_at_start(inside)
    return _attr_candidates(tag_name)


static func _tag_at_start(inside_tag: String) -> String:
    var space := inside_tag.find(" ")
    if space < 0:
        return inside_tag.to_lower()
    return inside_tag.substr(0, space).to_lower()


## Locate the position of the last quote that opened an attribute value but
## hasn't been closed yet. Returns -1 if all quotes are balanced or none.
static func _last_unclosed_quote(s: String) -> int:
    var in_quote := false
    var quote_char := ""
    var last_open := -1
    var i := 0
    var n := s.length()
    while i < n:
        var ch := s[i]
        if in_quote:
            if ch == quote_char:
                in_quote = false
        else:
            if ch == "\"" or ch == "'":
                in_quote = true
                quote_char = ch
                last_open = i
        i += 1
    return last_open if in_quote else -1


static func _attr_candidates(tag: String) -> Array:
    var attrs: Array = TAG_ATTRS.get(tag, [])
    # Always offer core attrs, deduped.
    var seen: Dictionary = {}
    var out: Array = []
    for a in attrs:
        seen[a] = true
        out.append({"label": a, "kind": "attr", "insert_text": a})
    for a in CORE_ATTRS:
        if not seen.has(a):
            out.append({"label": a, "kind": "attr", "insert_text": a})
    return out


static func _attr_value_candidates(tag: String, attr: String) -> Array:
    var key: String = "%s:%s" % [attr, tag]
    var vals: Array = ATTR_VALUES.get(key, [])
    var out: Array = []
    for v in vals:
        out.append({"label": v, "kind": "value", "insert_text": v})
    return out
```

- [ ] **Step 2b.4: Run, confirm pass**

Expected: 6/6 pass total in this file.

### 2c — CSS property + value completion

- [ ] **Step 2c.1: Write failing tests**

Append to `tests/unit/test_autocomplete_source.gd`:

```gdscript
#region CSS property + value completion

func test_css_property_completion_inside_block() -> void:
    var ctx = _css_ctx("div {\n  \n}", 1, 2)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    for prop in ["color", "background-color", "padding", "display", "font-size", "transform"]:
        assert_true(prop in labels, "missing property '%s'" % prop)


func test_css_value_completion_after_colon_for_display() -> void:
    var ctx = _css_ctx("div { display: ", 0, 15)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    for v in ["flex", "block", "none"]:
        assert_true(v in labels, "display should suggest '%s'" % v)


func test_css_value_completion_after_colon_for_cursor() -> void:
    var ctx = _css_ctx("a { cursor: ", 0, 12)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    for v in ["pointer", "text", "wait"]:
        assert_true(v in labels)


func test_css_no_completion_when_outside_block() -> void:
    # At top-level (between rules), property completions are wrong context.
    var ctx = _css_ctx("div { color: red; }\n", 1, 0)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    # We accept any list (selector tag names are fine for top-level) BUT
    # property names should NOT be in it.
    assert_false("background-color" in labels)

#endregion
```

- [ ] **Step 2c.2: Run, confirm fail**

- [ ] **Step 2c.3: Implement CSS property/value detection**

Replace `_css_candidates` in `GmlAutocompleteSource.gd`:

```gdscript
# CSS property names — union of every known property the parser dispatches.
const CSS_PROPERTIES := [
    # Layout / box
    "display", "flex-direction", "flex-grow", "flex-shrink", "flex-basis",
    "flex-wrap", "align-items", "align-self", "justify-content", "order",
    "gap", "row-gap", "column-gap",
    "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
    "margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
    "width", "height", "min-width", "max-width", "min-height", "max-height",
    "overflow", "overflow-x", "overflow-y",
    # Colors / borders / backgrounds
    "background-color", "background", "background-image", "color",
    "border", "border-width", "border-color", "border-radius",
    "border-top", "border-right", "border-bottom", "border-left",
    "border-top-width", "border-right-width", "border-bottom-width", "border-left-width",
    "border-top-color", "border-right-color", "border-bottom-color", "border-left-color",
    "border-top-left-radius", "border-top-right-radius",
    "border-bottom-left-radius", "border-bottom-right-radius",
    "box-shadow", "outline", "outline-offset",
    # Typography
    "font-size", "font-family", "font-weight", "letter-spacing", "word-spacing",
    "line-height", "text-align", "text-transform", "text-decoration",
    "text-indent", "text-overflow", "white-space", "text-shadow",
    # Misc
    "opacity", "visibility", "cursor", "list-style-type",
    "transition", "transition-property", "transition-duration",
    "transition-timing-function", "transition-delay",
    "transform",
]

# Value keywords per property — only enumerable ones.
const CSS_VALUES := {
    "display": ["flex", "block", "inline", "none"],
    "flex-direction": ["row", "column", "row-reverse", "column-reverse"],
    "flex-wrap": ["nowrap", "wrap", "wrap-reverse"],
    "align-items": ["flex-start", "center", "flex-end", "stretch", "baseline"],
    "align-self": ["auto", "flex-start", "center", "flex-end", "stretch"],
    "justify-content": ["flex-start", "center", "flex-end", "space-between", "space-around"],
    "text-align": ["left", "center", "right", "justify"],
    "text-transform": ["none", "uppercase", "lowercase", "capitalize"],
    "white-space": ["normal", "nowrap", "pre", "pre-wrap", "pre-line"],
    "text-overflow": ["clip", "ellipsis"],
    "overflow": ["visible", "hidden", "scroll", "auto"],
    "overflow-x": ["visible", "hidden", "scroll", "auto"],
    "overflow-y": ["visible", "hidden", "scroll", "auto"],
    "visibility": ["visible", "hidden"],
    "cursor": ["default", "pointer", "text", "move", "wait", "progress", "crosshair", "help",
               "not-allowed", "grab", "grabbing", "col-resize", "row-resize"],
    "font-weight": ["100", "200", "300", "400", "500", "600", "700", "800", "900"],
    "list-style-type": ["disc", "circle", "square", "decimal", "decimal-leading-zero",
                        "lower-alpha", "upper-alpha", "lower-roman", "upper-roman", "none"],
}


static func _css_candidates(ctx: GmlEditorContext) -> Array:
    var prefix := ctx.prefix_at_cursor()

    # Are we inside a declaration block? Find last { vs last }.
    var open := ctx.text.substr(0, _absolute_offset(ctx)).rfind("{")
    var close := ctx.text.substr(0, _absolute_offset(ctx)).rfind("}")
    var inside_block := open > close

    if not inside_block:
        return []

    # Within the current line: is the cursor before or after a colon?
    var colon := prefix.rfind(":")
    var semi := prefix.rfind(";")
    if colon >= 0 and colon > semi:
        # After a colon — we're typing a value. Look back from the colon to
        # the property name on the current line.
        var head := prefix.substr(0, colon).strip_edges()
        # Property name is the trailing identifier (allow - and digits).
        var prop := _trailing_property_name(head)
        return _value_candidates(prop)

    # Otherwise we're typing a property name.
    return _property_candidates()


## Compute the absolute character offset of the cursor in the buffer.
static func _absolute_offset(ctx: GmlEditorContext) -> int:
    var off := 0
    for i in range(ctx.cursor_line):
        off += ctx.line_at(i).length() + 1   # +1 for the newline
    return off + ctx.cursor_col


static func _trailing_property_name(s: String) -> String:
    var i := s.length() - 1
    while i >= 0:
        var ch := s[i]
        if ch.is_valid_identifier() or ch == "-" or ch == "_" or ch.is_valid_int():
            i -= 1
        else:
            break
    return s.substr(i + 1).to_lower()


static func _property_candidates() -> Array:
    var out: Array = []
    for p in CSS_PROPERTIES:
        out.append({"label": p, "kind": "property", "insert_text": p})
    return out


static func _value_candidates(prop: String) -> Array:
    var vals: Array = CSS_VALUES.get(prop, [])
    var out: Array = []
    for v in vals:
        out.append({"label": v, "kind": "value", "insert_text": v})
    return out
```

- [ ] **Step 2c.4: Run, confirm pass**

Expected: 10/10 tests pass in this file.

### 2d — `var()` and class completion (buffer-derived)

- [ ] **Step 2d.1: Write failing tests**

Append to `tests/unit/test_autocomplete_source.gd`:

```gdscript
#region var() and class completion

func test_var_completion_lists_declared_custom_properties() -> void:
    var css := ".app { --brand: red; --gap: 8px; }\n.btn { color: var( }"
    var ctx = _css_ctx(css, 1, 19)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    assert_true("--brand" in labels)
    assert_true("--gap" in labels)


func test_class_completion_lists_classes_declared_in_other_buffer() -> void:
    # Editing HTML `class="…"`; should pull class names from the CSS buffer.
    var html := '<div class="'
    var css := ".card {}\n.row {}\n#x {}"
    var ctx = GmlEditorContext.from_html(html, 0, html.length(), css)
    var labels = _labels(GmlAutocompleteSource.get_candidates(ctx))
    assert_true("card" in labels)
    assert_true("row" in labels)
    # IDs should NOT appear in class completion
    assert_false("x" in labels)

#endregion
```

- [ ] **Step 2d.2: Run, confirm fail**

- [ ] **Step 2d.3: Implement var + class scanning**

Add to `GmlAutocompleteSource.gd` (extend `_css_candidates` and `_html_candidates`):

```gdscript
# Add this branch INSIDE _css_candidates, BEFORE the "are we inside a block?" check:

    # `var(` completion — even outside a block (e.g. inside a calc()) the
    # var-name list is the same.
    if prefix.contains("var(") and not _is_var_call_closed(prefix):
        return _var_candidates(ctx.text)
```

And add these helpers:

```gdscript
## After the last `var(` on the line, is the matching `)` already closed?
static func _is_var_call_closed(prefix: String) -> bool:
    var last_open := prefix.rfind("var(")
    if last_open < 0:
        return true
    # Count parens after the var(
    var tail := prefix.substr(last_open + 4)
    var depth := 1
    for ch in tail:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return true
    return false


## Scan a CSS buffer for `--name:` declarations and return them as
## autocomplete candidates.
static func _var_candidates(css: String) -> Array:
    var regex := RegEx.new()
    regex.compile("--[a-zA-Z_][\\w-]*")
    var seen: Dictionary = {}
    var out: Array = []
    for match in regex.search_all(css):
        var name := match.get_string()
        if not seen.has(name):
            seen[name] = true
            out.append({"label": name, "kind": "var", "insert_text": name})
    return out
```

And add class completion to `_html_candidates` — modify the "inside attr value" branch:

```gdscript
# Inside _html_candidates, replace the attr-value return:

    if quote_open >= 0:
        var head := inside.substr(0, quote_open)
        var eq := head.rfind("=")
        if eq < 0:
            return []
        var attr_name := _trailing_attr_name(head.substr(0, eq))
        var tag_name := _tag_at_start(inside)
        if attr_name == "class":
            return _class_candidates(ctx.other_text)
        return _attr_value_candidates(tag_name, attr_name)
```

Add helpers:

```gdscript
## Last whitespace-delimited token in a string — the attribute name just
## before an = sign.
static func _trailing_attr_name(s: String) -> String:
    var stripped := s.strip_edges()
    var space := stripped.rfind(" ")
    if space < 0:
        return stripped
    return stripped.substr(space + 1)


## Scan a CSS buffer for `.classname` selectors and return them as candidates.
static func _class_candidates(css: String) -> Array:
    var regex := RegEx.new()
    regex.compile("\\.([a-zA-Z_][\\w-]*)")
    var seen: Dictionary = {}
    var out: Array = []
    for match in regex.search_all(css):
        var name := match.get_string(1)   # without the dot
        if not seen.has(name):
            seen[name] = true
            out.append({"label": name, "kind": "class", "insert_text": name})
    return out
```

- [ ] **Step 2d.4: Run, confirm pass**

Expected: 12/12 tests in this file pass.

### 2e — Commit autocomplete engine

- [ ] **Step 2e.1: Run full suite to confirm no regression**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing" | head
```

Expected: baseline + 16 tests (4 context + 12 autocomplete) all pass.

- [ ] **Step 2e.2: Commit**

```bash
git add addons/gtml/src/editor/GmlAutocompleteSource.gd tests/unit/test_autocomplete_source.gd
git commit -m "feat(editor): autocomplete engine for HTML + CSS

GmlAutocompleteSource.get_candidates(ctx) returns a list of
{label, kind, insert_text} candidates classified by cursor context:

  - HTML tag name (inside <)
  - HTML attribute name (inside <tag )
  - HTML attribute value (inside attr=\")
    - class=\" → class names scanned from the paired CSS buffer
    - type=\" → enumerated input-type values
  - CSS property name (inside a declaration block)
  - CSS value keyword (after : on a property line, per known property)
  - var(--… → custom-property names scanned from the CSS buffer

Tag/attr/value/property tables are hardcoded; class names and --vars are
scanned live from the buffer on each request. All static methods,
testable without a panel. 12 new unit tests."
```

---

## Task 3: Search engine + replace UI

**Files:**
- Modify: `addons/gtml/src/editor/GmlSearchEngine.gd`
- Create: `tests/unit/test_search_engine.gd`
- Modify: `addons/gtml/editor/gml_editor_panel.tscn` (add Replace row)
- Modify: `addons/gtml/editor/gml_editor_panel.gd` (wire Replace controls)

### 3a — Search engine TDD

- [ ] **Step 3a.1: Write failing tests for find_all**

Create `tests/unit/test_search_engine.gd`:

```gdscript
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
```

- [ ] **Step 3a.2: Run, confirm fail**

- [ ] **Step 3a.3: Implement GmlSearchEngine**

Replace `GmlSearchEngine.gd` contents:

```gdscript
class_name GmlSearchEngine
extends RefCounted

## Find / replace ops on a buffer. Stateless; pure ops on strings.
## Matches are {line: int, col: int, length: int}.

static func find_all(text: String, query: String, case_sensitive: bool, use_regex: bool) -> Array:
    if query.is_empty() or text.is_empty():
        return []
    if use_regex:
        return _find_regex(text, query, case_sensitive)
    return _find_literal(text, query, case_sensitive)


static func replace_all(text: String, query: String, replacement: String, case_sensitive: bool, use_regex: bool) -> Dictionary:
    if query.is_empty():
        return {"new_text": text, "count": 0}
    if use_regex:
        return _replace_regex(text, query, replacement, case_sensitive)
    return _replace_literal(text, query, replacement, case_sensitive)


# ─── Literal ──────────────────────────────────────────────────────

static func _find_literal(text: String, query: String, case_sensitive: bool) -> Array:
    var hay := text if case_sensitive else text.to_lower()
    var needle := query if case_sensitive else query.to_lower()
    var matches: Array = []
    var pos := 0
    while pos < hay.length():
        var idx := hay.find(needle, pos)
        if idx < 0:
            break
        var lc := _line_col_for(text, idx)
        matches.append({"line": lc["line"], "col": lc["col"], "length": query.length()})
        pos = idx + query.length()
    return matches


static func _replace_literal(text: String, query: String, replacement: String, case_sensitive: bool) -> Dictionary:
    if case_sensitive:
        var count := text.count(query)
        return {"new_text": text.replace(query, replacement), "count": count}
    # Case-insensitive literal: walk and rebuild.
    var hay := text.to_lower()
    var needle := query.to_lower()
    var out := ""
    var pos := 0
    var count := 0
    while pos < hay.length():
        var idx := hay.find(needle, pos)
        if idx < 0:
            out += text.substr(pos)
            break
        out += text.substr(pos, idx - pos) + replacement
        pos = idx + query.length()
        count += 1
    if pos < text.length() and count == 0:
        out = text
    elif pos >= text.length():
        pass   # consumed
    return {"new_text": out, "count": count}


# ─── Regex ────────────────────────────────────────────────────────

static func _compile_regex(pattern: String, case_sensitive: bool) -> RegEx:
    var re := RegEx.new()
    # Godot RegEx is case-sensitive by default. For insensitive, prefix with (?i).
    var effective := pattern if case_sensitive else "(?i)" + pattern
    if re.compile(effective) != OK:
        return null
    return re


static func _find_regex(text: String, query: String, case_sensitive: bool) -> Array:
    var re := _compile_regex(query, case_sensitive)
    if re == null:
        return []
    var matches: Array = []
    for m in re.search_all(text):
        var start := m.get_start()
        var lc := _line_col_for(text, start)
        matches.append({"line": lc["line"], "col": lc["col"], "length": m.get_end() - start})
    return matches


static func _replace_regex(text: String, query: String, replacement: String, case_sensitive: bool) -> Dictionary:
    var re := _compile_regex(query, case_sensitive)
    if re == null:
        return {"new_text": text, "count": 0}
    var count := re.search_all(text).size()
    var new_text := re.sub(text, replacement, true)
    return {"new_text": new_text, "count": count}


# ─── Position math ────────────────────────────────────────────────

static func _line_col_for(text: String, idx: int) -> Dictionary:
    var line := 0
    var col := 0
    var limit := mini(idx, text.length())
    for i in range(limit):
        if text[i] == "\n":
            line += 1
            col = 0
        else:
            col += 1
    return {"line": line, "col": col}
```

- [ ] **Step 3a.4: Run, confirm pass**

Expected: 10/10 pass.

### 3b — Replace UI

- [ ] **Step 3b.1: Add Replace row to the editor panel scene**

Modify `addons/gtml/editor/gml_editor_panel.tscn`. After the existing
`SearchBar` HBoxContainer node, add a `ReplaceBar` HBoxContainer with
the same parent (`MainContainer`). Children:

```
ReplaceBar (HBoxContainer, hidden by default)
  ReplaceLabel (Label, text="Replace:")
  ReplaceInput (LineEdit, expand_fill)
  ReplaceButton (Button, text="Replace")
  ReplaceAllButton (Button, text="Replace All")
```

Also add a `RegexCheck` CheckBox in the existing `SearchBar`, after `MatchCaseCheck`, with text=".*" and `tooltip_text="Regex mode"`.

Concrete tscn snippet to insert after the existing `SearchBar` block (the exact line numbers depend on current scene layout — search for `[node name="MatchCountLabel"`):

```gdscript
[node name="RegexCheck" type="CheckBox" parent="MainContainer/SearchBar"]
text = ".*"
tooltip_text = "Regex mode"

[node name="ReplaceBar" type="HBoxContainer" parent="MainContainer"]
visible = false

[node name="ReplaceLabel" type="Label" parent="MainContainer/ReplaceBar"]
text = "Replace:"

[node name="ReplaceInput" type="LineEdit" parent="MainContainer/ReplaceBar"]
size_flags_horizontal = 3

[node name="ReplaceButton" type="Button" parent="MainContainer/ReplaceBar"]
text = "Replace"

[node name="ReplaceAllButton" type="Button" parent="MainContainer/ReplaceBar"]
text = "Replace All"
```

Move both `SearchBar` and `ReplaceBar` so they appear after the toolbar but before the TabContainer.

- [ ] **Step 3b.2: Add onready references + wire replace + regex**

Modify `addons/gtml/editor/gml_editor_panel.gd`. Add to the `#region Node References` block:

```gdscript
@onready var regex_check: CheckBox = $MainContainer/SearchBar/RegexCheck
@onready var replace_bar: HBoxContainer = $MainContainer/ReplaceBar
@onready var replace_input: LineEdit = $MainContainer/ReplaceBar/ReplaceInput
@onready var replace_button: Button = $MainContainer/ReplaceBar/ReplaceButton
@onready var replace_all_button: Button = $MainContainer/ReplaceBar/ReplaceAllButton
```

Add a constant import at the top:

```gdscript
const GmlSearchEngineScript = preload("res://addons/gtml/src/editor/GmlSearchEngine.gd")
```

In `_ready`, connect signals:

```gdscript
    replace_button.pressed.connect(_on_replace_pressed)
    replace_all_button.pressed.connect(_on_replace_all_pressed)
    regex_check.toggled.connect(func(_p): _refresh_search())
```

Add the handlers:

```gdscript
func _toggle_replace_bar(visible: bool) -> void:
    replace_bar.visible = visible
    if visible:
        replace_input.grab_focus()


func _on_replace_pressed() -> void:
    var code_edit := _get_active_code_edit()
    if _search_matches.is_empty() or _current_match_index < 0:
        return
    var m: Dictionary = _search_matches[_current_match_index]
    var text := code_edit.text
    # Recompute absolute offset from line/col for the match
    var off := _line_col_to_offset(text, m["line"], m["col"])
    var new_text := text.substr(0, off) + replace_input.text + text.substr(off + m["length"])
    code_edit.text = new_text
    _refresh_search()
    _on_search_next()


func _on_replace_all_pressed() -> void:
    var code_edit := _get_active_code_edit()
    var result: Dictionary = GmlSearchEngineScript.replace_all(
        code_edit.text,
        search_input.text,
        replace_input.text,
        match_case_check.button_pressed,
        regex_check.button_pressed,
    )
    code_edit.text = result["new_text"]
    match_count_label.text = "Replaced %d" % result["count"]
    _refresh_search()


func _line_col_to_offset(text: String, line: int, col: int) -> int:
    var off := 0
    var current_line := 0
    var i := 0
    while i < text.length() and current_line < line:
        if text[i] == "\n":
            current_line += 1
        i += 1
    return i + col
```

Refactor existing `_refresh_search` (or whatever the search function is called) to delegate to `GmlSearchEngineScript.find_all` so the regex checkbox is honored. Find the existing search function — it probably builds matches inline — and replace its match-building loop with:

```gdscript
    _search_matches = GmlSearchEngineScript.find_all(
        code_edit.text,
        query,
        match_case_check.button_pressed,
        regex_check.button_pressed,
    )
```

- [ ] **Step 3b.3: Wire Ctrl+H to toggle the Replace bar**

Modify the existing `_unhandled_input` / `_input` in `gml_editor_panel.gd` (or add one if absent):

```gdscript
func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed:
        if event.ctrl_pressed and event.keycode == KEY_H:
            _toggle_replace_bar(not replace_bar.visible)
            get_viewport().set_input_as_handled()
```

If there's already an `_input` for Ctrl+F, just add the `KEY_H` branch alongside it.

- [ ] **Step 3b.4: Manual smoke**

Run Godot editor, open the GMTL panel, select a GmlView. Press Ctrl+F → search bar shows. Press Ctrl+H → replace bar appears. Type a query, hit Replace All → text in buffer should update, count appears in the match label.

(No automated UI test here — covered by the engine tests + the integration smoke in Task 7.)

- [ ] **Step 3b.5: Run full suite**

Expected: no regressions; baseline + new tests.

- [ ] **Step 3b.6: Commit**

```bash
git add addons/gtml/src/editor/GmlSearchEngine.gd tests/unit/test_search_engine.gd \
        addons/gtml/editor/gml_editor_panel.tscn addons/gtml/editor/gml_editor_panel.gd
git commit -m "feat(editor): regex find + replace via GmlSearchEngine

GmlSearchEngine.find_all / replace_all operate on raw strings with
flags for case sensitivity and regex mode. Backreferences (\$1, \$2)
work in the regex path. Malformed regex compiles return {count: 0,
new_text: text} so the UI shows zero matches instead of crashing.

Editor panel grows a Replace row (toggled by Ctrl+H) below the search
bar, plus a regex toggle (.*) next to the existing match-case check.
Replace updates the current match + advances; Replace All reports the
count via the existing match-count label.

10 new unit tests for the engine."
```

---

## Task 4: Jump resolver + UI

**Files:**
- Modify: `addons/gtml/src/editor/GmlJumpResolver.gd`
- Create: `tests/unit/test_jump_resolver.gd`
- Modify: `addons/gtml/editor/gml_editor_panel.gd` (wire Ctrl+Click / F12 / Alt+Left + gutter glyph)

### 4a — Resolver TDD

- [ ] **Step 4a.1: Write failing tests**

Create `tests/unit/test_jump_resolver.gd`:

```gdscript
extends GutTest

## Tests for GmlJumpResolver.resolve(ctx) — given a cursor on a jumpable
## token, returns {target_kind, line, col} or null.

func _resolve(kind: String, text: String, line: int, col: int, other: String):
    var ctx = (
        GmlEditorContext.from_html(text, line, col, other) if kind == "html"
        else GmlEditorContext.from_css(text, line, col, other)
    )
    return GmlJumpResolver.resolve(ctx)


func test_html_class_jumps_to_css_rule() -> void:
    var html := '<div class="card"></div>'
    var css := ".card {\n  color: red;\n}\n"
    # Cursor inside "card" on line 0
    var jump = _resolve("html", html, 0, 14, css)
    assert_not_null(jump)
    assert_eq(jump["target_kind"], "css")
    assert_eq(jump["line"], 0)


func test_html_id_jumps_to_css_rule() -> void:
    var html := '<div id="main"></div>'
    var css := ".x {}\n#main {\n  padding: 8px;\n}\n"
    var jump = _resolve("html", html, 0, 11, css)
    assert_not_null(jump)
    assert_eq(jump["target_kind"], "css")
    assert_eq(jump["line"], 1)


func test_css_class_selector_jumps_to_first_html_use() -> void:
    var html := "<div>\n<p class=\"row\">x</p>\n</div>"
    var css := ".row { color: red; }"
    # Cursor inside ".row"
    var jump = _resolve("css", css, 0, 2, html)
    assert_not_null(jump)
    assert_eq(jump["target_kind"], "html")
    assert_eq(jump["line"], 1)


func test_css_id_selector_jumps_to_html_element() -> void:
    var html := "<div>\n<span id=\"target\">x</span>\n</div>"
    var css := "#target {}"
    var jump = _resolve("css", css, 0, 2, html)
    assert_not_null(jump)
    assert_eq(jump["target_kind"], "html")
    assert_eq(jump["line"], 1)


func test_var_use_jumps_to_declaration() -> void:
    var css := ".app { --brand: red; }\n.btn { color: var(--brand); }"
    # Cursor inside "var(--brand)" on line 1
    var jump = _resolve("css", css, 1, 20, "")
    assert_not_null(jump)
    assert_eq(jump["target_kind"], "css")
    assert_eq(jump["line"], 0)


func test_var_declaration_jumps_to_first_use() -> void:
    var css := ".app { --brand: red; }\n.btn { color: var(--brand); }"
    # Cursor inside "--brand:" on line 0
    var jump = _resolve("css", css, 0, 10, "")
    assert_not_null(jump)
    assert_eq(jump["target_kind"], "css")
    assert_eq(jump["line"], 1)


func test_no_jump_on_unknown_token_returns_null() -> void:
    var jump = _resolve("html", "<div>nothing</div>", 0, 8, "")
    assert_null(jump)


func test_html_class_with_no_matching_rule_returns_null() -> void:
    var html := '<div class="missing"></div>'
    var css := ".other {}"
    var jump = _resolve("html", html, 0, 14, css)
    assert_null(jump)
```

- [ ] **Step 4a.2: Run, confirm fail**

- [ ] **Step 4a.3: Implement GmlJumpResolver**

Replace `GmlJumpResolver.gd`:

```gdscript
class_name GmlJumpResolver
extends RefCounted

## Resolves a cursor position to a jump target.
## Returns {target_kind, line, col} or null.

static func resolve(ctx: GmlEditorContext) -> Variant:
    if ctx.kind == "html":
        return _resolve_html(ctx)
    if ctx.kind == "css":
        return _resolve_css(ctx)
    return null


# ─── HTML side ────────────────────────────────────────────────────

static func _resolve_html(ctx: GmlEditorContext) -> Variant:
    var line := ctx.line_at(ctx.cursor_line)
    var token := _token_at(line, ctx.cursor_col, "[\\w-]+")
    if token.is_empty():
        return null

    # Is the token sitting inside an attribute value? Walk back from the
    # cursor on the same line to find the nearest attr name and "=".
    var attr := _attr_around_cursor(line, ctx.cursor_col)
    if attr == "class":
        return _find_in_css(ctx.other_text, "." + token)
    if attr == "id":
        return _find_in_css(ctx.other_text, "#" + token)
    return null


# ─── CSS side ─────────────────────────────────────────────────────

static func _resolve_css(ctx: GmlEditorContext) -> Variant:
    var line := ctx.line_at(ctx.cursor_line)
    var col := ctx.cursor_col

    # var(--name) use → declaration
    var var_name := _var_name_around_cursor(line, col)
    if not var_name.is_empty():
        return _find_var_declaration(ctx.text, var_name, ctx.cursor_line)

    # --name: declaration → first use
    var decl_name := _var_decl_around_cursor(line, col)
    if not decl_name.is_empty():
        return _find_var_use(ctx.text, decl_name, ctx.cursor_line)

    # Selector .class → HTML element
    var class_sel := _selector_token_around_cursor(line, col, ".")
    if not class_sel.is_empty():
        return _find_in_html(ctx.other_text, "class", class_sel)

    # Selector #id → HTML element
    var id_sel := _selector_token_around_cursor(line, col, "#")
    if not id_sel.is_empty():
        return _find_in_html(ctx.other_text, "id", id_sel)

    return null


# ─── Helpers ──────────────────────────────────────────────────────

static func _token_at(line: String, col: int, pattern: String) -> String:
    var re := RegEx.new()
    re.compile(pattern)
    for m in re.search_all(line):
        if col >= m.get_start() and col <= m.get_end():
            return m.get_string()
    return ""


## Walk back from cursor on the same line; find the attribute name whose
## value contains the cursor. Returns "" if cursor isn't inside an attr value.
static func _attr_around_cursor(line: String, col: int) -> String:
    # Find the last quote before col that opens an attribute value
    var i := col - 1
    var in_value := false
    var quote := ""
    while i >= 0:
        var ch := line[i]
        if (ch == "\"" or ch == "'") and not in_value:
            in_value = true
            quote = ch
            i -= 1
            break
        i -= 1
    if not in_value:
        return ""
    # Now find the attribute name immediately before the = that precedes this quote
    var j := i
    while j >= 0 and line[j] != "=":
        j -= 1
    if j < 0:
        return ""
    # Walk back over the attribute name
    var k := j - 1
    while k >= 0 and (line[k].is_valid_identifier() or line[k] == "-" or line[k] == "@"):
        k -= 1
    return line.substr(k + 1, j - k - 1).strip_edges()


static func _var_name_around_cursor(line: String, col: int) -> String:
    var re := RegEx.new()
    re.compile("var\\(\\s*(--[\\w-]+)")
    for m in re.search_all(line):
        if col > m.get_start() and col <= m.get_end():
            return m.get_string(1)
    return ""


static func _var_decl_around_cursor(line: String, col: int) -> String:
    # `--name:` at the start of a declaration
    var re := RegEx.new()
    re.compile("(--[\\w-]+)\\s*:")
    for m in re.search_all(line):
        var name_start := m.get_start()
        var name_end := name_start + m.get_string(1).length()
        if col >= name_start and col <= name_end:
            return m.get_string(1)
    return ""


## Selector token (.class or #id) containing the cursor. Pass "." for class,
## "#" for id. Returns the bare name (no prefix).
static func _selector_token_around_cursor(line: String, col: int, prefix: String) -> String:
    var re := RegEx.new()
    re.compile("\\%s([a-zA-Z_][\\w-]*)" % prefix)
    for m in re.search_all(line):
        if col > m.get_start() and col <= m.get_end():
            return m.get_string(1)
    return ""


static func _find_in_css(css: String, selector: String) -> Variant:
    var lines := css.split("\n")
    # Look for selector followed by optional whitespace then { or , or end
    var re := RegEx.new()
    re.compile("\\%s\\b" % selector)
    for i in range(lines.size()):
        var m := re.search(lines[i])
        if m != null:
            return {"target_kind": "css", "line": i, "col": m.get_start()}
    return null


static func _find_in_html(html: String, attr: String, value: String) -> Variant:
    var lines := html.split("\n")
    var re := RegEx.new()
    if attr == "class":
        # class attribute may have multiple whitespace-separated values
        re.compile('class="[^"]*\\b%s\\b[^"]*"' % value)
    else:
        re.compile('%s="%s"' % [attr, value])
    for i in range(lines.size()):
        var m := re.search(lines[i])
        if m != null:
            return {"target_kind": "html", "line": i, "col": m.get_start()}
    return null


static func _find_var_declaration(css: String, var_name: String, ignore_line: int) -> Variant:
    var lines := css.split("\n")
    var re := RegEx.new()
    re.compile("\\%s\\s*:" % var_name)
    for i in range(lines.size()):
        if i == ignore_line:
            continue
        var m := re.search(lines[i])
        if m != null:
            return {"target_kind": "css", "line": i, "col": m.get_start()}
    return null


static func _find_var_use(css: String, var_name: String, ignore_line: int) -> Variant:
    var lines := css.split("\n")
    var re := RegEx.new()
    re.compile("var\\(\\s*\\%s\\b" % var_name)
    for i in range(lines.size()):
        if i == ignore_line:
            continue
        var m := re.search(lines[i])
        if m != null:
            return {"target_kind": "css", "line": i, "col": m.get_start()}
    return null
```

- [ ] **Step 4a.4: Run, confirm pass**

Expected: 8/8 pass.

### 4b — Wire Ctrl+Click, F12, Alt+Left in the panel

- [ ] **Step 4b.1: Add jump wiring to gml_editor_panel.gd**

At the top of the file, add:

```gdscript
const GmlJumpResolverScript = preload("res://addons/gtml/src/editor/GmlJumpResolver.gd")
const GmlEditorContextScript = preload("res://addons/gtml/src/editor/GmlEditorContext.gd")
```

Add to the state region:

```gdscript
var _jump_history: Array = []   # [{source: "html"|"css", line, col}, ...]
```

Connect both CodeEdits' `gui_input` signals in `_ready`:

```gdscript
    html_code_edit.gui_input.connect(_on_code_edit_input.bind(html_code_edit))
    css_code_edit.gui_input.connect(_on_code_edit_input.bind(css_code_edit))
```

Add the handlers:

```gdscript
func _on_code_edit_input(event: InputEvent, code_edit: CodeEdit) -> void:
    if not (event is InputEventMouseButton):
        if event is InputEventKey and event.pressed:
            if event.keycode == KEY_F12:
                _trigger_jump_at_caret(code_edit)
            elif event.alt_pressed and event.keycode == KEY_LEFT:
                _pop_jump_history()
        return
    if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
        return
    if not event.ctrl_pressed:
        return
    # Caret position at click happens after gui_input — defer one frame.
    await get_tree().process_frame
    _trigger_jump_at_caret(code_edit)


func _trigger_jump_at_caret(code_edit: CodeEdit) -> void:
    var kind: String = "html" if code_edit == html_code_edit else "css"
    var other: String = css_code_edit.text if kind == "html" else html_code_edit.text
    var ctx: GmlEditorContext
    if kind == "html":
        ctx = GmlEditorContextScript.from_html(code_edit.text, code_edit.get_caret_line(), code_edit.get_caret_column(), other)
    else:
        ctx = GmlEditorContextScript.from_css(code_edit.text, code_edit.get_caret_line(), code_edit.get_caret_column(), other)

    var jump = GmlJumpResolverScript.resolve(ctx)
    if jump == null:
        return

    # Push current position to history before jumping
    _jump_history.append({
        "source": kind,
        "line": code_edit.get_caret_line(),
        "col": code_edit.get_caret_column(),
    })

    _go_to(jump["target_kind"], int(jump["line"]), int(jump.get("col", 0)))


func _go_to(target_kind: String, line: int, col: int) -> void:
    var target_edit: CodeEdit = html_code_edit if target_kind == "html" else css_code_edit
    var target_tab: Control = html_tab if target_kind == "html" else css_tab
    var idx: int = tab_container.get_tab_idx_from_control(target_tab)
    if idx >= 0:
        tab_container.current_tab = idx
    target_edit.set_caret_line(line)
    target_edit.set_caret_column(col)
    target_edit.grab_focus()


func _pop_jump_history() -> void:
    if _jump_history.is_empty():
        return
    var prev: Dictionary = _jump_history.pop_back()
    _go_to(prev["source"], int(prev["line"]), int(prev["col"]))
```

- [ ] **Step 4b.2: Manual smoke**

Open editor, open Forge sample. Click into `<input id="workspace-name" class="field-input">`. Cursor in "field-input". Press F12 — should jump to the CSS tab on the `.field-input` rule. Press Alt+Left — should return.

- [ ] **Step 4b.3: Run full suite**

Expected: no regressions.

- [ ] **Step 4b.4: Commit**

```bash
git add addons/gtml/src/editor/GmlJumpResolver.gd tests/unit/test_jump_resolver.gd \
        addons/gtml/editor/gml_editor_panel.gd
git commit -m "feat(editor): jumps (class<->rule, id<->element, var<->decl)

GmlJumpResolver.resolve(ctx) inspects the cursor's token + the paired
buffer and returns a {target_kind, line, col} or null. Six jump types
supported, each TDD'd:

  - HTML class=\"x\" -> first .x rule
  - HTML id=\"x\"    -> #x rule
  - CSS .x selector  -> first <... class=\"x\"> element
  - CSS #x selector  -> <... id=\"x\"> element
  - CSS var(--name)  -> --name declaration
  - CSS --name decl  -> first var(--name) use

Editor panel binds Ctrl+Click + F12 to trigger a jump from the active
CodeEdit. A _jump_history stack supports Alt+Left for return.
8 new resolver tests."
```

---

## Task 5: Color tokens + picker

**Files:**
- Modify: `addons/gtml/src/editor/GmlColorTokens.gd`
- Create: `tests/unit/test_color_tokens.gd`
- Modify: `addons/gtml/editor/gml_editor_panel.gd` (gutter + popup wiring)

### 5a — Scanner TDD

- [ ] **Step 5a.1: Write failing tests**

Create `tests/unit/test_color_tokens.gd`:

```gdscript
extends GutTest

## Tests for GmlColorTokens — scan a buffer for color literals and round-trip
## values back to text.

func test_scan_finds_six_digit_hex() -> void:
    var tokens = GmlColorTokens.scan("color: #ff8800;")
    assert_eq(tokens.size(), 1)
    var t = tokens[0]
    assert_eq(t["kind"], "hex")
    assert_eq(t["length"], 7)
    assert_almost_eq(t["color"].r, 1.0, 0.01)
    assert_almost_eq(t["color"].g, 0.533, 0.01)


func test_scan_finds_three_digit_hex() -> void:
    var tokens = GmlColorTokens.scan(".a { color: #f80; }")
    assert_eq(tokens.size(), 1)
    assert_eq(tokens[0]["length"], 4)


func test_scan_finds_eight_digit_hex_with_alpha() -> void:
    var tokens = GmlColorTokens.scan("bg: #00aaff80;")
    assert_eq(tokens.size(), 1)
    assert_eq(tokens[0]["length"], 9)
    assert_almost_eq(tokens[0]["color"].a, 0.502, 0.01)


func test_scan_finds_rgb_function() -> void:
    var tokens = GmlColorTokens.scan("color: rgb(128, 64, 200);")
    assert_eq(tokens.size(), 1)
    assert_eq(tokens[0]["kind"], "rgb")
    assert_almost_eq(tokens[0]["color"].r, 0.502, 0.01)


func test_scan_finds_rgba_function() -> void:
    var tokens = GmlColorTokens.scan("bg: rgba(255, 0, 0, 0.5);")
    assert_eq(tokens.size(), 1)
    assert_eq(tokens[0]["kind"], "rgba")
    assert_almost_eq(tokens[0]["color"].a, 0.5, 0.01)


func test_scan_multiple_per_line() -> void:
    var tokens = GmlColorTokens.scan("gradient: #ff0000, #00ff00, #0000ff;")
    assert_eq(tokens.size(), 3)


func test_scan_ignores_malformed_hex() -> void:
    var tokens = GmlColorTokens.scan("not-a-color: #xyz; nor: #12;")
    assert_eq(tokens.size(), 0)


func test_format_round_trip_hex() -> void:
    var out := GmlColorTokens.format(Color(1.0, 0.533, 0.0, 1.0), "hex")
    assert_eq(out, "#ff8800")


func test_format_round_trip_rgba_alpha_below_one() -> void:
    var out := GmlColorTokens.format(Color(1.0, 0.0, 0.0, 0.5), "rgba")
    # Allow any reasonable rgba(...) format; just check it leads with rgba(
    assert_string_starts_with(out, "rgba(")
```

- [ ] **Step 5a.2: Run, confirm fail**

- [ ] **Step 5a.3: Implement GmlColorTokens**

Replace `GmlColorTokens.gd`:

```gdscript
class_name GmlColorTokens
extends RefCounted

## Scan a buffer for color literals and format them back.
## Token: {line: int, col: int, length: int, color: Color, kind: String}
## kind ∈ {"hex", "rgb", "rgba"}.

const HEX_RE := "#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\\b"
const RGB_RE := "rgb\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*\\)"
const RGBA_RE := "rgba\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*[\\d.]+\\s*\\)"


static func scan(text: String) -> Array:
    var out: Array = []
    var lines := text.split("\n")
    for line_idx in range(lines.size()):
        var line: String = lines[line_idx]
        _append_matches(out, line, line_idx, HEX_RE, "hex", _hex_to_color)
        _append_matches(out, line, line_idx, RGB_RE, "rgb", _rgb_to_color)
        _append_matches(out, line, line_idx, RGBA_RE, "rgba", _rgba_to_color)
    return out


static func format(color: Color, kind: String) -> String:
    match kind:
        "rgb":
            return "rgb(%d, %d, %d)" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255))]
        "rgba":
            return "rgba(%d, %d, %d, %s)" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255)), str(color.a).pad_decimals(2)]
        _:
            if color.a < 0.999:
                return "#%02x%02x%02x%02x" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255)), int(round(color.a * 255))]
            return "#%02x%02x%02x" % [int(round(color.r * 255)), int(round(color.g * 255)), int(round(color.b * 255))]


# ─── Internals ────────────────────────────────────────────────────

static func _append_matches(out: Array, line: String, line_idx: int, pattern: String, kind: String, color_fn: Callable) -> void:
    var re := RegEx.new()
    re.compile(pattern)
    for m in re.search_all(line):
        var literal := m.get_string()
        var color = color_fn.call(literal)
        if color == null:
            continue
        out.append({
            "line": line_idx,
            "col": m.get_start(),
            "length": m.get_end() - m.get_start(),
            "color": color,
            "kind": kind,
        })


static func _hex_to_color(literal: String) -> Variant:
    var body := literal.substr(1)
    if body.length() == 3:
        body = "%c%c%c%c%c%c" % [body[0].unicode_at(0), body[0].unicode_at(0),
                                  body[1].unicode_at(0), body[1].unicode_at(0),
                                  body[2].unicode_at(0), body[2].unicode_at(0)]
    var r := body.substr(0, 2).hex_to_int() / 255.0
    var g := body.substr(2, 2).hex_to_int() / 255.0
    var b := body.substr(4, 2).hex_to_int() / 255.0
    var a := 1.0
    if body.length() == 8:
        a = body.substr(6, 2).hex_to_int() / 255.0
    return Color(r, g, b, a)


static func _rgb_to_color(literal: String) -> Variant:
    var nums := _extract_nums(literal)
    if nums.size() < 3:
        return null
    return Color(nums[0] / 255.0, nums[1] / 255.0, nums[2] / 255.0, 1.0)


static func _rgba_to_color(literal: String) -> Variant:
    var nums := _extract_nums(literal)
    if nums.size() < 4:
        return null
    return Color(nums[0] / 255.0, nums[1] / 255.0, nums[2] / 255.0, nums[3])


static func _extract_nums(literal: String) -> Array:
    var re := RegEx.new()
    re.compile("[\\d.]+")
    var out: Array = []
    for m in re.search_all(literal):
        out.append(m.get_string().to_float())
    return out
```

- [ ] **Step 5a.4: Run, confirm pass**

Expected: 9/9 pass.

### 5b — Gutter swatch + ColorPicker popup

- [ ] **Step 5b.1: Wire the scanner + gutter in the editor panel**

Add at top of `gml_editor_panel.gd`:

```gdscript
const GmlColorTokensScript = preload("res://addons/gtml/src/editor/GmlColorTokens.gd")

const COLOR_GUTTER_IDX := 0
```

Add state:

```gdscript
var _color_swatch_cache: Dictionary = {}   # color_hash -> Texture2D
var _color_tokens_by_buffer: Dictionary = {"html": [], "css": []}
```

In `_ready`, set up the gutter on both CodeEdits:

```gdscript
    for ce in [html_code_edit, css_code_edit]:
        ce.add_gutter(COLOR_GUTTER_IDX)
        ce.set_gutter_name(COLOR_GUTTER_IDX, "color")
        ce.set_gutter_width(COLOR_GUTTER_IDX, 16)
        ce.set_gutter_clickable(COLOR_GUTTER_IDX, true)
        ce.gutter_clicked.connect(_on_gutter_clicked.bind(ce))
```

Connect text changed to a debounced rescan:

```gdscript
    html_code_edit.text_changed.connect(_schedule_color_rescan.bind("html"))
    css_code_edit.text_changed.connect(_schedule_color_rescan.bind("css"))
```

Add the handlers:

```gdscript
var _color_rescan_timer: SceneTreeTimer = null

func _schedule_color_rescan(kind: String) -> void:
    # 200ms debounce — rescanning a 1000-line buffer is fast but avoid
    # re-running on every keystroke during a fast paste.
    if _color_rescan_timer != null:
        _color_rescan_timer.timeout.disconnect(self._rescan_colors)
    _color_rescan_timer = get_tree().create_timer(0.2)
    _color_rescan_timer.timeout.connect(_rescan_colors.bind(kind), CONNECT_ONE_SHOT)


func _rescan_colors(kind: String) -> void:
    var code_edit: CodeEdit = html_code_edit if kind == "html" else css_code_edit
    var tokens: Array = GmlColorTokensScript.scan(code_edit.text)
    _color_tokens_by_buffer[kind] = tokens
    # Clear all gutter icons first
    for line in range(code_edit.get_line_count()):
        code_edit.set_line_gutter_icon(line, COLOR_GUTTER_IDX, null)
    # Set icons for each line that has at least one color
    for t in tokens:
        var line: int = t["line"]
        code_edit.set_line_gutter_icon(line, COLOR_GUTTER_IDX, _swatch_for(t["color"]))
        code_edit.set_line_gutter_metadata(line, COLOR_GUTTER_IDX, t)


func _swatch_for(color: Color) -> Texture2D:
    var key := color.to_html()
    if _color_swatch_cache.has(key):
        return _color_swatch_cache[key]
    var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
    img.fill(color)
    var tex := ImageTexture.create_from_image(img)
    _color_swatch_cache[key] = tex
    return tex


func _on_gutter_clicked(line: int, gutter: int, code_edit: CodeEdit) -> void:
    if gutter != COLOR_GUTTER_IDX:
        return
    var token = code_edit.get_line_gutter_metadata(line, COLOR_GUTTER_IDX)
    if token == null:
        return
    _open_color_picker(token, code_edit)


func _open_color_picker(token: Dictionary, code_edit: CodeEdit) -> void:
    var popup := PopupPanel.new()
    var picker := ColorPicker.new()
    picker.color = token["color"]
    popup.add_child(picker)
    add_child(popup)

    picker.color_changed.connect(func(new_color: Color):
        _write_back_color(code_edit, token, new_color)
    )

    popup.popup_hide.connect(popup.queue_free)
    popup.popup_centered()


func _write_back_color(code_edit: CodeEdit, token: Dictionary, new_color: Color) -> void:
    var new_literal := GmlColorTokensScript.format(new_color, token["kind"])
    var line: int = token["line"]
    var col: int = token["col"]
    var length: int = token["length"]
    var old_line_text := code_edit.get_line(line)
    var new_line_text := old_line_text.substr(0, col) + new_literal + old_line_text.substr(col + length)
    code_edit.set_line(line, new_line_text)
    # Rescan will run via text_changed debounce
```

- [ ] **Step 5b.2: Trigger an initial scan when a GmlView is loaded**

Find the existing `edit_gml_view` or `_load_files` function in `gml_editor_panel.gd` and after the buffers are populated, call:

```gdscript
    _rescan_colors("html")
    _rescan_colors("css")
```

- [ ] **Step 5b.3: Manual smoke**

Open editor, open atlas/style.css. Color swatches should appear in the gutter next to every line containing a hex literal. Click a swatch → ColorPicker pops up. Change the color → buffer updates.

- [ ] **Step 5b.4: Run full suite**

- [ ] **Step 5b.5: Commit**

```bash
git add addons/gtml/src/editor/GmlColorTokens.gd tests/unit/test_color_tokens.gd \
        addons/gtml/editor/gml_editor_panel.gd
git commit -m "feat(editor): color swatch gutter + ColorPicker popup

GmlColorTokens.scan(text) returns every #rgb / #rrggbb / #rrggbbaa /
rgb(...) / rgba(...) literal with line/col/length/color/kind.
GmlColorTokens.format(color, kind) round-trips back to text in the
literal's original style.

Editor panel adds a 16px gutter to both CodeEdits that renders a 12x12
swatch beside every line containing a color. Click a swatch -> spawns a
ColorPicker popup; on color_changed the buffer is patched in place.
text_changed triggers a 200ms-debounced rescan so the gutter stays in
sync without thrashing.

9 new scanner tests."
```

---

## Task 6: Autocomplete wiring

**Files:**
- Modify: `addons/gtml/editor/gml_editor_panel.gd`

This was deferred from Task 2 so the engine landed without UI surface area. Now wire it.

- [ ] **Step 6.1: Add the autocomplete import + state**

Add at top of `gml_editor_panel.gd`:

```gdscript
const GmlAutocompleteSourceScript = preload("res://addons/gtml/src/editor/GmlAutocompleteSource.gd")
```

In `_ready`, configure both CodeEdits + connect signals:

```gdscript
    for ce in [html_code_edit, css_code_edit]:
        ce.code_completion_enabled = true
        ce.code_completion_prefixes = ["<", " ", "\"", ":", ".", "#", "("]
        ce.code_completion_requested.connect(_on_code_completion_requested.bind(ce))
```

- [ ] **Step 6.2: Implement the request handler**

```gdscript
func _on_code_completion_requested(code_edit: CodeEdit) -> void:
    var kind: String = "html" if code_edit == html_code_edit else "css"
    var other: String = css_code_edit.text if kind == "html" else html_code_edit.text
    var ctx: GmlEditorContext
    if kind == "html":
        ctx = GmlEditorContextScript.from_html(code_edit.text, code_edit.get_caret_line(), code_edit.get_caret_column(), other)
    else:
        ctx = GmlEditorContextScript.from_css(code_edit.text, code_edit.get_caret_line(), code_edit.get_caret_column(), other)

    var candidates: Array = GmlAutocompleteSourceScript.get_candidates(ctx)
    if candidates.is_empty():
        return

    code_edit.cancel_code_completion()
    for c in candidates:
        var kind_const := _completion_kind(c["kind"])
        code_edit.add_code_completion_option(
            kind_const,
            c["label"],
            c["insert_text"],
        )
    code_edit.update_code_completion_options(true)


static func _completion_kind(s: String) -> int:
    match s:
        "tag":
            return CodeEdit.KIND_CLASS
        "attr":
            return CodeEdit.KIND_MEMBER
        "value":
            return CodeEdit.KIND_CONSTANT
        "property":
            return CodeEdit.KIND_VARIABLE
        "var":
            return CodeEdit.KIND_CONSTANT
        "class":
            return CodeEdit.KIND_MEMBER
        _:
            return CodeEdit.KIND_PLAIN_TEXT
```

- [ ] **Step 6.3: Manual smoke**

Open the editor, type `<` in the HTML buffer → completion popup with element tags. Type `<div ` → attribute suggestions. Type `class="` → class names from CSS. Switch to CSS, inside a `{ }` block type `c` → property suggestions including `color`, `cursor`.

- [ ] **Step 6.4: Run full suite**

- [ ] **Step 6.5: Commit**

```bash
git add addons/gtml/editor/gml_editor_panel.gd
git commit -m "feat(editor): wire CodeEdit native autocomplete to engine

Both CodeEdits enable code_completion + register the trigger char set
(< / space / \" / : / . / # / (). On code_completion_requested the panel
builds a GmlEditorContext from the buffer + caret + paired-buffer text,
asks GmlAutocompleteSource for candidates, and feeds them to
add_code_completion_option + update_code_completion_options.

Kind mapping (CodeEdit.KIND_*): tag/attr/value/property/var/class each
get a sensible glyph in the native popup."
```

---

## Task 7: Multi-cursor keybinds + integration smoke

**Files:**
- Modify: `addons/gtml/editor/gml_editor_panel.gd`
- Create: `tests/unit/test_editor_panel_v06.gd`

- [ ] **Step 7.1: Enable multi-cursor on both CodeEdits**

In `_ready`:

```gdscript
    for ce in [html_code_edit, css_code_edit]:
        ce.multiple_carets_enabled = true
```

- [ ] **Step 7.2: Add Ctrl+D / Ctrl+L / Ctrl+Alt+Up/Down handlers**

Extend the existing `_input` (or add one) in `gml_editor_panel.gd`:

```gdscript
func _input(event: InputEvent) -> void:
    if not visible:
        return
    if not (event is InputEventKey) or not event.pressed:
        return
    var code_edit := _get_active_code_edit()
    if code_edit == null or not code_edit.has_focus():
        return

    if event.ctrl_pressed and event.keycode == KEY_D:
        _add_caret_at_next_match(code_edit)
        get_viewport().set_input_as_handled()
    elif event.ctrl_pressed and event.keycode == KEY_L:
        # Select current line under primary caret
        var line := code_edit.get_caret_line()
        code_edit.select(line, 0, line, code_edit.get_line(line).length())
        get_viewport().set_input_as_handled()
    elif event.ctrl_pressed and event.alt_pressed and event.keycode == KEY_DOWN:
        _add_caret_relative(code_edit, 1)
        get_viewport().set_input_as_handled()
    elif event.ctrl_pressed and event.alt_pressed and event.keycode == KEY_UP:
        _add_caret_relative(code_edit, -1)
        get_viewport().set_input_as_handled()


func _add_caret_at_next_match(code_edit: CodeEdit) -> void:
    var selected := code_edit.get_selected_text(0)
    if selected.is_empty():
        # Promote the word under the caret to a selection
        var line := code_edit.get_caret_line()
        var col := code_edit.get_caret_column()
        var line_text := code_edit.get_line(line)
        var word_start := col
        while word_start > 0 and (line_text[word_start - 1].is_valid_identifier() or line_text[word_start - 1] == "-"):
            word_start -= 1
        var word_end := col
        while word_end < line_text.length() and (line_text[word_end].is_valid_identifier() or line_text[word_end] == "-"):
            word_end += 1
        code_edit.select(line, word_start, line, word_end)
        selected = code_edit.get_selected_text(0)
    if selected.is_empty():
        return

    var matches: Array = GmlSearchEngineScript.find_all(code_edit.text, selected, true, false)
    if matches.size() < 2:
        return
    # Find the next match after the primary caret position
    var anchor_line := code_edit.get_caret_line(0)
    var anchor_col := code_edit.get_caret_column(0)
    for m in matches:
        if m["line"] > anchor_line or (m["line"] == anchor_line and m["col"] > anchor_col):
            code_edit.add_caret(m["line"], m["col"])
            return


func _add_caret_relative(code_edit: CodeEdit, delta: int) -> void:
    var line := code_edit.get_caret_line()
    var col := code_edit.get_caret_column()
    var target_line := clampi(line + delta, 0, code_edit.get_line_count() - 1)
    code_edit.add_caret(target_line, col)
```

- [ ] **Step 7.3: Integration smoke tests**

Create `tests/unit/test_editor_panel_v06.gd`:

```gdscript
extends GutTest

## Integration tests for the v0.6 editor pane. Loads the panel scene,
## drives keystrokes / state directly, asserts the new wiring is alive.

const EditorPanelScene = preload("res://addons/gtml/editor/gml_editor_panel.tscn")


func _panel() -> Control:
    var p: Control = EditorPanelScene.instantiate()
    add_child_autofree(p)
    await get_tree().process_frame
    return p


func test_panel_loads_with_v06_nodes() -> void:
    var p := await _panel()
    # Replace bar must exist (added in v0.6)
    assert_not_null(p.get_node_or_null("MainContainer/ReplaceBar"),
        "v0.6 Replace bar must be present in the scene")
    # Regex checkbox must exist
    assert_not_null(p.get_node_or_null("MainContainer/SearchBar/RegexCheck"),
        "v0.6 regex checkbox must be present")


func test_codeedit_autocomplete_enabled() -> void:
    var p := await _panel()
    assert_true(p.html_code_edit.code_completion_enabled)
    assert_true(p.css_code_edit.code_completion_enabled)


func test_codeedit_multiple_carets_enabled() -> void:
    var p := await _panel()
    assert_true(p.html_code_edit.multiple_carets_enabled)
    assert_true(p.css_code_edit.multiple_carets_enabled)


func test_color_gutter_present() -> void:
    var p := await _panel()
    # COLOR_GUTTER_IDX is 0 — both edits should report at least one gutter
    assert_gt(p.html_code_edit.get_gutter_count(), 0)
    assert_gt(p.css_code_edit.get_gutter_count(), 0)


func test_replace_all_through_panel() -> void:
    var p := await _panel()
    p.css_code_edit.text = ".a { color: red; } .a { color: red; }"
    p.search_input.text = "red"
    p.replace_input.text = "blue"
    p.tab_container.current_tab = p.tab_container.get_tab_idx_from_control(p.css_tab)
    p._on_replace_all_pressed()
    assert_eq(p.css_code_edit.text, ".a { color: blue; } .a { color: blue; }")
```

- [ ] **Step 7.4: Run new tests**

```bash
timeout 60 godot --headless --import 2>&1 | tail -3
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://tests/unit/test_editor_panel_v06.gd 2>&1 | tail -10
```

Expected: 5/5 pass.

- [ ] **Step 7.5: Manual smoke**

Open editor, select text, press Ctrl+D → second caret on next occurrence. Press Ctrl+L → entire current line selected.

- [ ] **Step 7.6: Run full suite**

Expected: baseline + all new tests pass (~5 integration + 9 color + 8 jump + 10 search + 12 autocomplete + 4 context = ~48 new tests; total ≈ 210).

- [ ] **Step 7.7: Commit**

```bash
git add addons/gtml/editor/gml_editor_panel.gd tests/unit/test_editor_panel_v06.gd
git commit -m "feat(editor): multi-cursor keybinds + integration tests

Both CodeEdits enable multiple_carets_enabled. Panel binds:
  - Ctrl+D: add caret at next match of selected (or word-under-caret) text
  - Ctrl+L: select current line under primary caret
  - Ctrl+Alt+Down: add caret one line below primary
  - Ctrl+Alt+Up: add caret one line above primary

Integration test scaffold (test_editor_panel_v06.gd) loads the panel
scene and asserts the v0.6 surface area is wired: Replace bar present,
regex checkbox present, autocomplete enabled, multi-cursor enabled,
color gutter present, and a smoke test that Replace All through the
public method round-trips text correctly. 5 new tests."
```

---

## Task 8: Version bump + CHANGELOG + docs

**Files:**
- Modify: `addons/gtml/plugin.cfg`
- Modify: `CHANGELOG.md`
- Create: `docs/editor.md`
- Modify: `docs/getting-started.md`

- [ ] **Step 8.1: Bump version**

Edit `addons/gtml/plugin.cfg`, change `version="0.5.0"` to `version="0.6.0"`.

- [ ] **Step 8.2: Write CHANGELOG entry**

Insert at the top of `CHANGELOG.md`, after `# Changelog`:

```markdown
## 0.6.0

### Features — Editor pane "professional upgrade"

- **Autocomplete** (HTML + CSS): element tags, tag-specific attributes,
  enumerated attribute values, CSS property names, value keywords per
  property, `var(--name)` declarations scanned from the buffer, and
  class names scanned from the paired buffer. Triggered by typing
  `<`, ` `, `"`, `:`, `.`, `#`, `(` or by Ctrl+Space.
- **Find & Replace** (Ctrl+H toggles the Replace row). Regex toggle
  (`.*`) and the existing match-case toggle apply to both find and
  replace. Replace All reports the count via the match label.
- **Jumps**: Ctrl+Click or F12 jumps between
  - `class="x"` ↔ `.x` rule
  - `id="x"` ↔ `#x` rule
  - `var(--name)` ↔ `--name: ...;` declaration
  Alt+Left returns to the previous position via a panel-local history
  stack.
- **Color picker on hex / rgb / rgba literals**: a 16px gutter renders
  a swatch next to every line containing a color. Click → ColorPicker
  popup; changes round-trip back to the buffer in the literal's
  original kind (hex stays hex, rgba stays rgba).
- **Multi-cursor + selection** (CodeEdit's native multiple_carets
  enabled):
  - Ctrl+D adds caret at next match
  - Ctrl+L selects current line
  - Ctrl+Alt+Up/Down adds caret one line above/below

### Architecture

Five new pure-data engines under `addons/gtml/src/editor/` so the panel
script stays a thin wiring layer (~900 LOC) and the intelligence is
unit-testable without instantiating Godot UI:

- `GmlEditorContext.gd` — shared {text, cursor, other_text, kind} struct
- `GmlAutocompleteSource.gd` — candidate generator
- `GmlJumpResolver.gd` — cursor-context → jump target
- `GmlSearchEngine.gd` — find / replace_all ops with regex flag
- `GmlColorTokens.gd` — color-literal scanner + formatter

44 new tests covering all five engines plus 5 integration tests
against the loaded panel scene.

### Deferred / not yet supported

- Live rendered preview pane (use existing GmlView scene + hot reload).
- Cross-buffer find (only the active tab).
- Code formatting / prettify.
- Snippet library beyond the implicit tag→`<tag></tag>` completion.
- LSP / external protocol support.
- Multi-tab file open (only the active GmlView's pair).
```

- [ ] **Step 8.3: Write docs/editor.md**

Create `docs/editor.md`:

```markdown
# The GML Editor Pane

GTML ships an in-editor pane (visible when a `GmlView` node is selected)
that lets you edit the HTML and CSS files attached to that view without
leaving Godot. As of v0.6 it includes the power-tools you expect from
modern code editors.

## Autocomplete

Triggered automatically when you type one of the prefix characters
(`<`, ` `, `"`, `:`, `.`, `#`, `(`), or manually with **Ctrl+Space**.

Context-aware:

| You type… | You get… |
|---|---|
| `<` in HTML | Element tag names |
| `<tag ` in HTML | Attributes valid for `tag` |
| `class="` in HTML | Class names declared in the paired CSS buffer |
| `type="` in `<input` | The supported input-type keywords |
| Inside a CSS `{ }` block | CSS property names |
| After `: ` on a CSS line | Value keywords for that property |
| `var(` in CSS | `--*` declarations scanned from the buffer |

## Find & Replace

- **Ctrl+F** opens the Find bar.
- **Ctrl+H** also opens the Replace row.
- Toggle **Aa** for case sensitivity, **.\*** for regex mode.
- Replace updates the current match and advances; Replace All reports the
  count.

## Jumps

- **Ctrl+Click** or **F12** on a jumpable token follows it:
  - HTML `class="card"` → first `.card` rule in the CSS tab
  - HTML `id="x"` → `#x` rule
  - CSS `var(--brand)` → `--brand: ...;` declaration
  - CSS `--brand: ...;` declaration → first `var(--brand)` use
  - CSS `.card` / `#x` selector → first matching HTML element
- **Alt+Left** returns to the previous position.

## Color picker

Color literals (`#rrggbb`, `#rrggbbaa`, `rgb(…)`, `rgba(…)`) get a swatch
in the line gutter. Click the swatch → ColorPicker popup. Picked colors
round-trip back to the buffer in the literal's original kind.

## Multi-cursor

- **Ctrl+D** — add caret at the next occurrence of the selection (or word
  under the caret if there's no selection).
- **Ctrl+L** — select the current line.
- **Ctrl+Alt+Up** / **Ctrl+Alt+Down** — add a caret one line above /
  below.
- All standard CodeEdit multi-caret edits work once multiple carets
  exist.

## Parse warnings overlay

(Carries over from v0.4.) Save your file with **Ctrl+S** — if the HTML
or CSS parser emits a warning, a panel appears at the bottom listing
each one. Click an entry to jump the caret to that line.
```

- [ ] **Step 8.4: Link from getting-started.md**

In `docs/getting-started.md`, add to the "Next Steps" list:

```markdown
- [The Editor Pane](editor.md) - Autocomplete, jumps, color picker, multi-cursor
```

- [ ] **Step 8.5: Run full suite one last time**

```bash
timeout 60 godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep "Tests \|Passing\|Failing"
```

Expected: green, count ≈ baseline + 48.

- [ ] **Step 8.6: Commit**

```bash
git add addons/gtml/plugin.cfg CHANGELOG.md docs/editor.md docs/getting-started.md
git commit -m "chore(v0.6.0): version bump + CHANGELOG + editor docs

Documents the autocomplete + find/replace + jumps + color picker +
multi-cursor work and adds docs/editor.md as the user-facing reference
for the editor pane."
```

---

## Pre-PR review

After Task 8, before opening the PR, launch the same review-agent pattern
used in v0.2-v0.5 (see those PR descriptions for the prompt shape).
Address any blockers, then open the PR as `v0.6` with the CHANGELOG entry
as the body summary.

---

## Self-Review

**Spec coverage:**
- §1 Autocomplete (spec) → Task 2 (5 sub-stages) + Task 6 wiring ✓
- §2 Find & Replace (spec) → Task 3 ✓
- §3 Jumps (spec) → Task 4 ✓
- §4 Color picker (spec) → Task 5 ✓
- §5 Multi-cursor (spec) → Task 7 ✓
- Testing (spec) → tests in every task ✓
- File budget (spec) → enforced via 5 single-purpose modules + extracted state in panel ✓
- Phasing (spec) → 8 tasks matching the spec's 8 commits ✓
- Version bump + CHANGELOG + docs → Task 8 ✓

**Placeholders:** none. Each code block contains the actual code, each
test contains the actual assertions.

**Type consistency:** GmlEditorContext API is `from_html(text, line, col, css_text)` and `from_css(text, line, col, html_text)` consistently across tasks. Autocomplete kind values (tag/attr/value/property/var/class) are used consistently in Task 2's tests, engine, and Task 6's wiring. Jump return shape `{target_kind, line, col}` consistent across Task 4 engine and panel wiring.

**Known limitation in Step 2b's _trailing_property_name vs _trailing_attr_name:** intentionally separate; HTML attr names allow `@` (for `@click`/`@keydown`), CSS property names don't. Both helpers documented inline.
