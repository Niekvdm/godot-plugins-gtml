@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"GmlView",
		"Control",
		preload("res://addons/gml/src/GmlView.gd"),
		preload("res://addons/gml/icons/gml_view.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("GmlView")
