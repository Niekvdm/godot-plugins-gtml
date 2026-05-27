extends Control

## Inventory demo — v0.7 binding integration.
## First showcase with a real game-side script. Atlas, Atelier, Forge,
## and Kitchen are pure HTML+CSS. This one shows how state.set(),
## state_changed, and item_clicked compose to make a fully reactive UI
## without per-element binding code.

@onready var view: GmlView = $GmlView

const ITEMS := [
	{"id": "sword",    "name": "Iron Sword",    "type": "weapon", "rarity": "common", "icon": "[S]", "qty": 1, "desc": "A reliable iron blade."},
	{"id": "bow",      "name": "Hunting Bow",   "type": "weapon", "rarity": "common", "icon": "[B]", "qty": 1, "desc": "Quick and quiet."},
	{"id": "axe",      "name": "War Axe",       "type": "weapon", "rarity": "rare",   "icon": "[A]", "qty": 1, "desc": "Heavy. Devastating."},
	{"id": "potion_s", "name": "Small Potion",  "type": "potion", "rarity": "common", "icon": "[p]", "qty": 5, "desc": "Restores 25 HP."},
	{"id": "potion_l", "name": "Large Potion",  "type": "potion", "rarity": "rare",   "icon": "[P]", "qty": 2, "desc": "Restores 75 HP."},
	{"id": "key",      "name": "Brass Key",     "type": "misc",   "rarity": "common", "icon": "[K]", "qty": 1, "desc": "Opens... something."},
]

const HOTBAR := ["[S]", "[p]", "[B]", "[K]"]

var _current_filter: String = "all"


func _ready() -> void:
	view.state.set_state({
		"gold": 1247,
		"search": "",
		"items": ITEMS,
		"filtered_items": ITEMS,
		"selected_item": null,
		"selected_name": "",
		"selected_rarity": "",
		"selected_desc": "",
		"has_selection": false,
		"empty": false,
		"is_filter_all": true,
		"is_filter_weapon": false,
		"is_filter_potion": false,
		"hotbar": HOTBAR,
	})
	view.state.state_changed.connect(_on_state_changed)
	view.item_clicked.connect(_on_item_clicked)


func _on_state_changed(key: String, _new_value, _old_value) -> void:
	if key == "search":
		_apply_filter()


func _on_item_clicked(handler: String, args: Array) -> void:
	match handler:
		"select":
			var item = args[0] if args.size() > 0 else null
			if item == null:
				return
			view.state.set_state({
				"selected_item": item,
				"selected_name": item["name"],
				"selected_rarity": item["rarity"],
				"selected_desc": item["desc"],
				"has_selection": true,
			})
		"set_filter":
			_current_filter = str(args[0]) if args.size() > 0 else "all"
			view.state.set_state({
				"is_filter_all": _current_filter == "all",
				"is_filter_weapon": _current_filter == "weapon",
				"is_filter_potion": _current_filter == "potion",
			})
			_apply_filter()
		"use_item":
			# Demo only — would consume the selected item in a real game.
			pass


func _apply_filter() -> void:
	var query: String = str(view.state.get("search")).to_lower()
	var out: Array = []
	for item in ITEMS:
		if _current_filter != "all" and item["type"] != _current_filter:
			continue
		if not query.is_empty() and not item["name"].to_lower().contains(query):
			continue
		out.append(item)
	view.state.set("filtered_items", out)
	view.state.set("empty", out.is_empty())
