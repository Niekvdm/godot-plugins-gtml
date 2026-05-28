extends Control

## Foundry — "Commit Idle" as an interactive terminal (REPL).
## Game logic lives in pure functions (fmt .. build_*_view, never touch `view`).
## The view layer renders a scrollback `log` + a live status line; actions run
## as commands (typed via the <input>, or clicked as command tokens / log lines).

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
const LOG_CAP := 28

var commits: float = 0.0
var total_this_run: float = 0.0
var per_click: float = 1.0
var insight: int = 0
var refactored: int = 0
var gen_owned: Dictionary = {}   # id -> int
var purchased: Dictionary = {}   # upgrade id -> true
var earned: Dictionary = {}      # achievement id -> true
var _derive_accum: float = 0.0
var _log_lines: Array = []       # scrollback entries (capped)
var _log_id: int = 0


# ── number formatting ─────────────────────────────────────
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


# ── generators ────────────────────────────────────────────
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


# ── upgrades ───────────────────────────────────────────────
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
		out.append({"id": u.id, "name": u.name, "desc": u.desc, "cost_display": fmt(upgrade_cost(u.id)), "affordable": can_afford(upgrade_cost(u.id))})
	return out


# ── achievements ───────────────────────────────────────────
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
		var is_earned: bool = earned.has(a.id)
		out.append({"id": a.id, "name": a.name, "desc": a.desc, "earned": is_earned, "mark": "[x]" if is_earned else "[ ]"})
	return out


# ── prestige ───────────────────────────────────────────────
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
		out.append({"id": g.id, "name": g.name, "desc": g.desc, "owned": _owned(g.id), "cost_display": fmt(cost_of(g.id)), "rate_display": fmt(effective_rate(g.id)), "affordable": can_afford(cost_of(g.id))})
	return out


# ══ view layer (terminal REPL) ════════════════════════════
func _ready() -> void:
	view.state.set_state({
		"commits_display": fmt(commits),
		"per_sec_display": fmt(per_sec()),
		"per_click_display": fmt(click_value()),
		"insight": insight,
		"mult_display": "%.2f" % global_mult(),
		"log": [],
		"cmd": "",
	})
	view.item_clicked.connect(_on_item)
	view.key_pressed.connect(_on_key)
	_seed_log()


# Make the command input read like a terminal prompt: a blinking green caret
# that moves with the text, no text-box chrome (styled away in CSS). GtmlView
# builds deferred, so the LineEdit isn't registered during _ready — wire it on
# the first tick once it exists.
var _caret_inited := false
var _screen_scroll: ScrollContainer = null
var _scroll_frames := 0

func _init_caret() -> void:
	var le := view.get_element_by_id("cmdline")
	if le is LineEdit:
		le.caret_blink = true
		le.caret_blink_interval = 0.6
		le.add_theme_color_override("caret_color", Color("#9ece6a"))
		le.grab_focus()
		_screen_scroll = _find_scroll(view)
		_caret_inited = true

func _find_scroll(n: Node) -> ScrollContainer:
	for c in n.get_children():
		if c is ScrollContainer:
			return c
		var r := _find_scroll(c)
		if r != null:
			return r
	return null


func _process(delta: float) -> void:
	if view == null:
		return
	if not _caret_inited:
		_init_caret()
	# Auto-scroll the scrollback to the newest line. Done over a few frames
	# after new content so the layout has settled before we pin to the bottom.
	if _screen_scroll != null and _scroll_frames > 0:
		_screen_scroll.scroll_vertical = 1000000
		_scroll_frames -= 1
	var rate := per_sec()
	var earnings := rate * delta
	commits += earnings
	total_this_run += earnings
	view.state.set("commits_display", fmt(commits))
	view.state.set("per_sec_display", fmt(rate))
	_derive_accum += delta
	if _derive_accum >= DERIVE_INTERVAL:
		_derive_accum = 0.0
		view.state.set("per_click_display", fmt(click_value()))
		view.state.set("insight", insight)
		view.state.set("mult_display", "%.2f" % global_mult())
		var newly := _check_achievements()
		if not newly.is_empty():
			for aid in newly:
				_log("ok", ">> unlocked: " + _ach_name(aid))
			_push_log()


# ── scrollback log ─────────────────────────────────────────
func _log(kind: String, text: String, actionable: bool = false, ref: String = "") -> void:
	_log_id += 1
	_log_lines.append({"id": _log_id, "kind": kind, "text": text, "actionable": actionable, "ref": ref})
	while _log_lines.size() > LOG_CAP:
		_log_lines.pop_front()

func _push_log() -> void:
	if view != null:
		view.state.set("log", _log_lines.duplicate())
		_scroll_frames = 3  # follow to the newest line once layout settles

func _seed_log() -> void:
	_log("sys", "foundry v0.8 — idle commit console")
	_log("sys", "press <enter> to commit · type a command (try: help)")
	_push_log()


# ── command runner ─────────────────────────────────────────
func _on_key(handler: String, event: InputEvent) -> void:
	if handler != "submit" or not (event is InputEventKey):
		return
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		return
	var raw: String = str(view.state.get("cmd")).strip_edges()
	view.state.set("cmd", "")
	# Empty enter = commit (hold/spam enter to write commits, like clicking).
	if raw.is_empty():
		run_command("commit")
	else:
		run_command(raw)


func cmd_token(name: String) -> void:
	run_command(name)


func run_command(raw: String) -> void:
	var parts := raw.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0].to_lower()
	var arg: String = parts[1] if parts.size() > 1 else ""
	# `commit` is the core action and gets spammed — skip the "$ cmd" echo for
	# it so the log stays readable; everything else echoes like a real shell.
	if cmd != "commit" and cmd != "c":
		_log("cmd", "$ " + raw)
	match cmd:
		"commit", "c":
			var v := click_value()
			commits += v
			total_this_run += v
			_log("ok", "> commit +%s  (%s total)" % [fmt(v), fmt(commits)])
		"help":
			_log("info", "commands:")
			_log("info", "  <enter>    write a commit (empty input)")
			_log("info", "  commit (c) write a commit by hand")
			_log("info", "  buy [id]   list generators / buy one")
			_log("info", "  upgrades   list available upgrades")
			_log("info", "  ach        list achievements")
			_log("info", "  stats      show run stats")
			_log("info", "  prestige   refactor for insight")
			_log("info", "  clear      clear the screen")
		"buy":
			if arg.is_empty():
				_list_generators()
			else:
				_buy_by_id(arg)
		"upgrades", "upg":
			_list_upgrades()
		"ach", "achievements":
			_list_achievements()
		"stats":
			_show_stats()
		"prestige", "refactor":
			_show_prestige()
		"clear":
			_log_lines.clear()
		_:
			_log("warn", "command not found: " + cmd + " — try help")
	_push_log()


func _list_generators() -> void:
	for g in build_generators_view():
		_log("buy_gen", "%-16s #%-4d %7s/s  [%s]" % [g.id, g.owned, g.rate_display, g.cost_display], true, g.id)

func _list_upgrades() -> void:
	var ups := build_upgrades_view()
	if ups.is_empty():
		_log("info", "(no upgrades available — unlock more generators first)")
		return
	for u in ups:
		_log("buy_upg", "%-24s [%s]" % [u.id, u.cost_display], true, u.id)

func _list_achievements() -> void:
	for a in build_achievements_view():
		_log("ok" if a.earned else "info", "%s %-16s %s" % [a.mark, a.name, a.desc])

func _show_stats() -> void:
	_log("info", "commits     %s" % fmt(commits))
	_log("info", "per click   %s" % fmt(click_value()))
	_log("info", "per second  %s" % fmt(per_sec()))
	_log("info", "insight     %d  (x%.2f)" % [insight, global_mult()])
	_log("info", "refactors   %d" % refactored)
	for g in GENERATORS:
		_log("info", "  %-16s %d" % [g.id, _owned(g.id)])

func _show_prestige() -> void:
	var gain := refactor_gain()
	if gain >= 1:
		_log("info", "refactor wipes this run for permanent insight (+2%% output each)")
		_log("confirm", "[ confirm refactor — +%d insight ]" % gain, true, "")
	else:
		_log("warn", "not worth refactoring yet (0 insight) — keep committing")

func _buy_by_id(id: String) -> void:
	if not _gen_def(id).is_empty():
		_run_buy_gen(id)
	elif not _upg_def(id).is_empty():
		_run_buy_upg(id)
	else:
		_log("warn", "unknown id: " + id)


# ── clickable log-line actions ─────────────────────────────
func run_line(kind: String, ref: String) -> void:
	match kind:
		"buy_gen":
			_run_buy_gen(ref)
		"buy_upg":
			_run_buy_upg(ref)
		"confirm":
			_run_refactor()
		_:
			return
	_push_log()

func _run_buy_gen(id: String) -> void:
	var nm: String = _gen_def(id).get("name", id)
	var cost := cost_of(id)
	if buy_generator(id):
		_log("ok", "> hired %s (#%d) — +%s/s" % [nm, _owned(id), fmt(float(_gen_def(id).rate))])
	else:
		_log("warn", "> can't afford %s (need %s)" % [nm, fmt(cost)])

func _run_buy_upg(id: String) -> void:
	var nm: String = _upg_def(id).get("name", id)
	if buy_upgrade(id):
		_log("ok", "> installed %s" % nm)
	else:
		_log("warn", "> can't buy %s" % nm)

func _run_refactor() -> void:
	var gain := refactor_gain()
	if gain < 1:
		_log("warn", "> nothing to refactor yet")
		return
	do_refactor()
	_log("ok", "> refactored — +%d insight (now x%.2f)" % [gain, global_mult()])
	view.state.set("insight", insight)
	view.state.set("mult_display", "%.2f" % global_mult())


func _on_item(handler: String, args: Array) -> void:
	match handler:
		"run_line":
			run_line(str(args[0]) if args.size() > 0 else "", str(args[1]) if args.size() > 1 else "")
		"cmd_token":
			cmd_token(str(args[0]) if args.size() > 0 else "")
