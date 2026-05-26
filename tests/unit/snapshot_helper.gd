class_name GtmlSnapshotHelper
extends RefCounted

## Test helper for serializing GTML parser/resolver outputs to JSON-comparable form
## and comparing against on-disk golden snapshots.
##
## Snapshots live under tests/snapshots/<name>.json. When a snapshot is missing the
## helper writes it (auto-bootstrap on first run) and the test fails with a notice
## telling the developer to review and commit. On subsequent runs the helper diffs
## against the committed file.

const SNAPSHOT_DIR := "res://tests/snapshots/"
const ACTUAL_DIR := "res://tests/snapshots/.actual/"


static func serialize_dom(node) -> Variant:
	if node == null:
		return null
	if node.is_text_node:
		return {"_t": "text", "v": node.text}
	var out: Dictionary = {"_t": "el", "tag": node.tag, "attrs": _sort_dict(node.attrs)}
	var kids: Array = []
	for c in node.children:
		kids.append(serialize_dom(c))
	out["children"] = kids
	return out


static func serialize_styles(root, styles: Dictionary) -> Array:
	var rows: Array = []
	_walk_styles(root, styles, rows, "")
	return rows


static func _walk_styles(node, styles: Dictionary, rows: Array, path: String) -> void:
	if node == null or node.is_text_node:
		return
	var label: String = node.tag
	var id_attr: String = node.get_attr("id", "")
	if not id_attr.is_empty():
		label += "#" + id_attr
	var class_attr: String = node.get_attr("class", "")
	if not class_attr.is_empty():
		label += "." + class_attr.replace(" ", ".")
	var node_path: String = (path + " > " + label) if not path.is_empty() else label

	if styles.has(node):
		rows.append({"path": node_path, "style": _serialize_style_props(styles[node])})

	for c in node.children:
		_walk_styles(c, styles, rows, node_path)


static func _serialize_style_props(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = props.keys()
	keys.sort()
	for k in keys:
		out[k] = _serialize_value(props[k])
	return out


static func _serialize_value(v: Variant) -> Variant:
	if v is Color:
		var c: Color = v
		return "Color(%.4f,%.4f,%.4f,%.4f)" % [c.r, c.g, c.b, c.a]
	if v is Dictionary:
		return _serialize_style_props(v)
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_serialize_value(x))
		return arr
	return v


static func _sort_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = d.keys()
	keys.sort()
	for k in keys:
		out[k] = d[k]
	return out


static func match_snapshot(name: String, value: Variant) -> Dictionary:
	var json_text: String = JSON.stringify(value, "  ", false)
	var path: String = SNAPSHOT_DIR + name + ".json"

	if not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_DIR))
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return {"status": "error", "msg": "cannot write snapshot to %s" % path}
		f.store_string(json_text + "\n")
		f.close()
		return {"status": "bootstrapped", "path": path}

	var f2 := FileAccess.open(path, FileAccess.READ)
	if f2 == null:
		return {"status": "error", "msg": "cannot read snapshot at %s" % path}
	var expected: String = f2.get_as_text().strip_edges()
	f2.close()
	var actual: String = json_text.strip_edges()
	if expected == actual:
		return {"status": "match"}

	# Write the full actual output to tests/snapshots/.actual/<name>.json so
	# the developer can diff it against the committed snapshot with their
	# own tools instead of relying on the truncated console preview. The
	# .actual/ directory is gitignored.
	var actual_path := ACTUAL_DIR + name + ".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTUAL_DIR))
	var af := FileAccess.open(actual_path, FileAccess.WRITE)
	if af != null:
		af.store_string(actual + "\n")
		af.close()

	return {"status": "diff", "expected": expected, "actual": actual, "actual_path": actual_path}
