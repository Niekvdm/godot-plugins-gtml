class_name GmlBindingParser
extends RefCounted

## Scans HTML text + attributes for binding markers.
##
## Two responsibilities:
##   1. find_interpolations(text) splits a text string into a sequence of
##      {literal, value} and {interp, expr} spans.
##   2. classify_attribute(name) tags an attribute name as one of:
##      v-bind | v-on | v-if | v-show | v-for | v-model | passthrough
##      plus the "target" (the part after the prefix).


## Returns Array of spans:
##   {type: "literal", value: String}
##   {type: "interp",  expr: Dictionary (from GmlBindingExpr.parse)}
static func find_interpolations(text: String) -> Array:
	var out: Array = []
	var i: int = 0
	var n: int = text.length()
	var literal_start: int = 0
	while i < n - 1:
		if text[i] == "{" and text[i + 1] == "{":
			if i > literal_start:
				out.append({"type": "literal", "value": text.substr(literal_start, i - literal_start)})
			var close: int = text.find("}}", i + 2)
			if close < 0:
				out.append({"type": "literal", "value": text.substr(i)})
				return out
			var src: String = text.substr(i + 2, close - i - 2).strip_edges()
			var expr: Dictionary = GmlBindingExpr.parse(src)
			out.append({"type": "interp", "expr": expr})
			i = close + 2
			literal_start = i
		else:
			i += 1
	if literal_start < n:
		out.append({"type": "literal", "value": text.substr(literal_start)})
	if out.is_empty():
		out.append({"type": "literal", "value": text})
	return out


## Returns {kind: String, target: String}.
## kind ∈ {"v-bind", "v-on", "v-if", "v-show", "v-for", "v-model", "passthrough"}.
## target is the part after the prefix (the attr being bound, or the event name).
static func classify_attribute(name: String) -> Dictionary:
	if name.begins_with(":"):
		return {"kind": "v-bind", "target": name.substr(1)}
	if name.begins_with("@"):
		return {"kind": "v-on", "target": name.substr(1)}
	if name.begins_with("v-bind:"):
		return {"kind": "v-bind", "target": name.substr(7)}
	if name.begins_with("v-on:"):
		return {"kind": "v-on", "target": name.substr(5)}
	if name == "v-if" or name == "v-show" or name == "v-for" or name == "v-model":
		return {"kind": name, "target": ""}
	return {"kind": "passthrough", "target": name}
