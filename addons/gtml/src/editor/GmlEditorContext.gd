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
