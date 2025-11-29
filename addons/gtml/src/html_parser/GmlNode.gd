class_name GmlNode
extends RefCounted

## Represents a node in the GML DOM tree.
## Can be either an element node (with tag) or a text node.

## The tag name (e.g., "div", "p", "button"). Empty for text nodes.
var tag: String = ""

## Attributes dictionary (e.g., {"id": "main", "class": "container", "@click": "handle_click"})
var attrs: Dictionary = {}

## Child nodes
var children: Array = []

## Text content (for text nodes only)
var text: String = ""

## Whether this is a text node (no tag, just text content)
var is_text_node: bool = false


## Create an element node with the given tag name.
static func create_element(tag_name: String, attributes: Dictionary = {}):
	var node := GmlNode.new()
	node.tag = tag_name.to_lower()
	node.attrs = attributes
	node.is_text_node = false
	return node


## Create a text node with the given content.
static func create_text(content: String):
	var node := GmlNode.new()
	node.text = content
	node.is_text_node = true
	return node


## Add a child node.
func add_child(child) -> void:
	children.append(child)


## Get attribute value, or default if not found.
func get_attr(name: String, default: String = "") -> String:
	return attrs.get(name, default)


## Check if node has a specific attribute.
func has_attr(name: String) -> bool:
	return attrs.has(name)


## Get all classes as an array.
func get_classes() -> PackedStringArray:
	var class_attr := get_attr("class", "")
	if class_attr.is_empty():
		return PackedStringArray()
	return class_attr.split(" ", false)


## Check if node has a specific class.
func has_class(cls_name: String) -> bool:
	return cls_name in get_classes()


## Get the id attribute.
func get_id() -> String:
	return get_attr("id", "")


## Get text content of this node and all descendants.
func get_text_content() -> String:
	if is_text_node:
		return text

	var result := ""
	for child in children:
		result += child.get_text_content()
	return result


## Debug string representation.
func _to_string() -> String:
	if is_text_node:
		return "TextNode(\"%s\")" % text.substr(0, 20)
	return "<%s%s>" % [tag, " ..." if not attrs.is_empty() else ""]
