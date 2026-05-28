extends Control

## Foundry — "Commit Idle". A fully reactive idle game built on GTML.
## demo.gd is the source of truth; pure functions operate on the fields below
## and never touch `view`. Only _ready/_process/_derive/_show_toast and the
## signal handlers push into view.state.

@onready var view: GtmlView = $GtmlView

const GENERATORS := [
	{"id": "intern",   "name": "Intern",         "desc": "Writes commits while you sleep.", "cost": 10,     "rate": 0.5},
	{"id": "compiler", "name": "Compiler",       "desc": "Turns coffee into builds.",       "cost": 120,    "rate": 4.0},
	{"id": "ci_farm",  "name": "CI Farm",        "desc": "Green checks, all day.",          "cost": 1500,   "rate": 25.0},
	{"id": "render",   "name": "Render Server",  "desc": "Bakes lightmaps on the side.",    "cost": 20000,  "rate": 160.0},
	{"id": "linter",   "name": "Quantum Linter", "desc": "Fixes bugs in superposition.",    "cost": 250000, "rate": 1000.0},
]

const UPGRADES := [
	{"id": "keyboard",  "name": "Mechanical Keyboard", "desc": "Per-click x2.",       "cost": 100,    "kind": "click", "factor": 2.0, "gate_commits": 50},
	{"id": "hotreload", "name": "Hot Reload",          "desc": "Intern output x2.",   "cost": 500,    "kind": "gen",   "factor": 2.0, "target": "intern",   "gate_gen": "intern",   "gate_n": 5},
	{"id": "ssd",       "name": "NVMe Array",          "desc": "Compiler output x2.", "cost": 4000,   "kind": "gen",   "factor": 2.0, "target": "compiler", "gate_gen": "compiler", "gate_n": 5},
	{"id": "distcc",    "name": "Distributed Build",   "desc": "CI Farm output x2.",  "cost": 25000,  "kind": "gen",   "factor": 2.0, "target": "ci_farm",  "gate_gen": "ci_farm",  "gate_n": 5},
	{"id": "caffeine",  "name": "Infinite Caffeine",   "desc": "Per-click x3.",       "cost": 8000,   "kind": "click", "factor": 3.0, "gate_commits": 5000},
	{"id": "gpu",       "name": "GPU Cluster",         "desc": "Render output x2.",   "cost": 120000, "kind": "gen",   "factor": 2.0, "target": "render",   "gate_gen": "render",   "gate_n": 5},
]

const ACHIEVEMENTS := [
	{"id": "first",          "name": "First Commit",   "desc": "Write your first commit."},
	{"id": "ten_interns",    "name": "Onboarding",     "desc": "Own 10 Interns."},
	{"id": "kilo",           "name": "Kilocommit",     "desc": "Reach 1,000 commits."},
	{"id": "mega",           "name": "Megacommit",     "desc": "Reach 1,000,000 commits."},
	{"id": "first_refactor", "name": "Tech Debt Paid", "desc": "Refactor once."},
	{"id": "five_gens",      "name": "Full Stack",     "desc": "Own every generator type."},
	{"id": "upgrader",       "name": "Optimizer",      "desc": "Buy 3 upgrades."},
	{"id": "insightful",     "name": "Enlightened",    "desc": "Reach 10 Insight."},
]

const DERIVE_INTERVAL := 0.1

var commits: float = 0.0
var total_this_run: float = 0.0
var per_click: float = 1.0
var insight: int = 0
var refactored: int = 0
var gen_owned: Dictionary = {}   # id -> int
var purchased: Dictionary = {}   # upgrade id -> true
var earned: Dictionary = {}      # achievement id -> true
var _derive_accum: float = 0.0


func fmt(n: float) -> String:
	if absf(n) < 1000.0:
		return str(int(n))
	var units := ["K", "M", "B", "T"]
	var idx := -1
	var v := n
	while absf(v) >= 1000.0 and idx < units.size() - 1:
		v /= 1000.0
		idx += 1
	return "%.2f%s" % [v, units[idx]]


func _gen_def(id: String) -> Dictionary:
	for g in GENERATORS:
		if g.id == id:
			return g
	return {}

func _owned(id: String) -> int:
	return int(gen_owned.get(id, 0))

func cost_of(id: String) -> int:
	var base: float = float(_gen_def(id).get("cost", 0))
	return int(floor(base * pow(1.15, _owned(id))))

func global_mult() -> float:
	return 1.0 + insight * 0.02

func _gen_factor(id: String) -> float:
	var f := 1.0
	for u in UPGRADES:
		if u.kind == "gen" and u.get("target", "") == id and purchased.has(u.id):
			f *= float(u.factor)
	return f

func effective_rate(id: String) -> float:
	return float(_gen_def(id).get("rate", 0.0)) * _owned(id) * _gen_factor(id) * global_mult()

func per_sec() -> float:
	var s := 0.0
	for g in GENERATORS:
		s += effective_rate(g.id)
	return s

func click_value() -> float:
	return per_click * global_mult()

func can_afford(amount: float) -> bool:
	return commits >= amount


func buy_generator(id: String) -> bool:
	var c := cost_of(id)
	if not can_afford(c):
		return false
	commits -= c
	gen_owned[id] = _owned(id) + 1
	return true


func _upg_def(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

func upgrade_cost(id: String) -> int:
	return int(_upg_def(id).get("cost", 0))

func upgrade_unlocked(u: Dictionary) -> bool:
	if u.is_empty() or purchased.has(u.id):
		return false
	if u.has("gate_gen") and _owned(u.gate_gen) < int(u.gate_n):
		return false
	if u.has("gate_commits") and total_this_run < float(u.gate_commits):
		return false
	return true

func buy_upgrade(id: String) -> bool:
	if purchased.has(id):
		return false
	var c := upgrade_cost(id)
	if not can_afford(c):
		return false
	commits -= c
	purchased[id] = true
	var u := _upg_def(id)
	if u.get("kind", "") == "click":
		per_click *= float(u.factor)
	return true

func build_upgrades_view() -> Array:
	var out := []
	for u in UPGRADES:
		if not upgrade_unlocked(u):
			continue
		var c := upgrade_cost(u.id)
		out.append({
			"id": u.id, "name": u.name, "desc": u.desc,
			"cost_display": fmt(c), "affordable": can_afford(c),
		})
	return out


func _all_gens_owned() -> bool:
	for g in GENERATORS:
		if _owned(g.id) <= 0:
			return false
	return true

func _check_achievements() -> Array:
	var conds := {
		"first": commits >= 1.0,
		"ten_interns": _owned("intern") >= 10,
		"kilo": commits >= 1000.0,
		"mega": commits >= 1000000.0,
		"first_refactor": refactored >= 1,
		"five_gens": _all_gens_owned(),
		"upgrader": purchased.size() >= 3,
		"insightful": insight >= 10,
	}
	var newly := []
	for a in ACHIEVEMENTS:
		if conds.get(a.id, false) and not earned.has(a.id):
			earned[a.id] = true
			newly.append(a.id)
	return newly

func _ach_name(id: String) -> String:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a.name
	return id

func build_achievements_view() -> Array:
	var out := []
	for a in ACHIEVEMENTS:
		out.append({"id": a.id, "name": a.name, "desc": a.desc, "earned": earned.has(a.id)})
	return out


func refactor_gain() -> int:
	return int(floor(sqrt(total_this_run / 10000.0)))

func do_refactor() -> void:
	insight += refactor_gain()
	refactored += 1
	commits = 0.0
	total_this_run = 0.0
	per_click = 1.0
	gen_owned.clear()
	purchased.clear()
	# insight + earned achievements intentionally persist.


func build_generators_view() -> Array:
	var out := []
	for g in GENERATORS:
		var c := cost_of(g.id)
		out.append({
			"id": g.id, "name": g.name, "desc": g.desc,
			"owned": _owned(g.id),
			"cost_display": fmt(c),
			"rate_display": fmt(effective_rate(g.id)),
			"affordable": can_afford(c),
		})
	return out


func _ready() -> void:
	view.state.set_state({
		"commits_display": fmt(commits),
		"per_sec_display": fmt(per_sec()),
		"per_click_display": fmt(click_value()),
		"insight": insight,
		"mult_display": "%.2f" % global_mult(),
		"generators": build_generators_view(),
		"upgrades": build_upgrades_view(),
		"no_upgrades": build_upgrades_view().is_empty(),
		"achievements": build_achievements_view(),
		"toast": "",
		"show_toast": false,
		"show_refactor": false,
		"refactor_gain": str(refactor_gain()),
	})
	view.button_clicked.connect(_on_button)
	view.item_clicked.connect(_on_item)


func _process(delta: float) -> void:
	if view == null:
		return
	var rate := per_sec()
	var earnings := rate * delta
	commits += earnings
	total_this_run += earnings
	view.state.set("commits_display", fmt(commits))
	view.state.set("per_sec_display", fmt(rate))
	_derive_accum += delta
	if _derive_accum >= DERIVE_INTERVAL:
		_derive_accum = 0.0
		_derive()


func _derive() -> void:
	if view == null:
		return
	var ups := build_upgrades_view()
	view.state.set("generators", build_generators_view())
	view.state.set("upgrades", ups)
	view.state.set("no_upgrades", ups.is_empty())
	view.state.set("per_click_display", fmt(click_value()))
	view.state.set("refactor_gain", str(refactor_gain()))
	var newly := _check_achievements()
	if not newly.is_empty():
		view.state.set("achievements", build_achievements_view())
		_show_toast(_ach_name(newly[0]))


func _show_toast(text: String) -> void:
	view.state.set("toast", text)
	view.state.set("show_toast", true)
	await get_tree().create_timer(3.0).timeout
	if view != null:
		view.state.set("show_toast", false)


func _on_button(method: String) -> void:
	match method:
		"tap":
			var v := click_value()
			commits += v
			total_this_run += v
			_derive()
		"open_refactor":
			view.state.set("refactor_gain", str(refactor_gain()))
			view.state.set("show_refactor", true)
		"confirm_refactor":
			do_refactor()
			view.state.set("show_refactor", false)
			_refresh_all()
		"cancel_refactor":
			view.state.set("show_refactor", false)


func _on_item(handler: String, args: Array) -> void:
	var id := str(args[0]) if args.size() > 0 else ""
	match handler:
		"buy":
			if buy_generator(id):
				_derive()
		"buy_upgrade":
			if buy_upgrade(id):
				_derive()


func _refresh_all() -> void:
	view.state.set("insight", insight)
	view.state.set("mult_display", "%.2f" % global_mult())
	view.state.set("achievements", build_achievements_view())
	_derive()
