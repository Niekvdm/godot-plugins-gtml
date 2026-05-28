class_name GtmlPercentSizing
extends RefCounted

## Runtime helpers that keep a Control's size in sync with percentage-based
## width/height/max-width/max-height values stored as metadata.
##
## Percentage dimensions are recomputed whenever the containing GtmlView (or,
## as a fallback, the parent Control) resizes. Max-size enforcement is a
## separate pass triggered by the control's own resize signal because it must
## clamp values that arrive via Container layout passes too.
##
## Meta keys consumed (set by GtmlDimensions during initial style application):
##   width_percent, height_percent          - fractions in (0, 1)
##   max_width, max_height                  - pixel ceilings (int)
##   max_width_percent, max_height_percent  - fractional ceilings


## Schedule percent-size wiring for a control once it enters the scene tree.
static func attach(control: Control) -> void:
	if control == null:
		return
	var ref := weakref(control)
	control.tree_entered.connect(func():
		var c = ref.get_ref()
		if c == null or not is_instance_valid(c):
			return
		c.get_tree().process_frame.connect(func():
			var c2 = ref.get_ref()
			if c2 != null and is_instance_valid(c2):
				_setup(c2)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)


## Schedule max-size enforcement for a control once it enters the scene tree.
static func attach_max_size(control: Control) -> void:
	if control == null:
		return
	var ref := weakref(control)
	control.tree_entered.connect(func():
		var c = ref.get_ref()
		if c == null or not is_instance_valid(c):
			return
		c.get_tree().process_frame.connect(func():
			var c2 = ref.get_ref()
			if c2 != null and is_instance_valid(c2):
				_setup_max(c2)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)


static func _setup(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var parent: Node = control.get_parent()
	if parent == null or not (parent is Control):
		return
	if not parent.resized.is_connected(_on_resize.bind(control)):
		parent.resized.connect(_on_resize.bind(control))
	var view := find_gtml_view(control)
	if view != null and not view.resized.is_connected(_on_resize.bind(control)):
		view.resized.connect(_on_resize.bind(control))
	update_size(control)


static func _setup_max(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if not control.resized.is_connected(_on_max_resize.bind(control)):
		control.resized.connect(_on_max_resize.bind(control))
	var parent: Node = control.get_parent()
	if parent is Control and not parent.resized.is_connected(_on_max_resize.bind(control)):
		parent.resized.connect(_on_max_resize.bind(control))
	enforce_max(control)


static func _on_resize(control: Control) -> void:
	if is_instance_valid(control):
		update_size(control)


static func _on_max_resize(control: Control) -> void:
	if is_instance_valid(control):
		enforce_max(control)


## Find the nearest GtmlView ancestor (or null) of a control.
static func find_gtml_view(control: Control) -> Control:
	var current: Node = control.get_parent()
	while current != null:
		var s := current.get_script()
		if s != null and s.resource_path.ends_with("GtmlView.gd"):
			return current
		current = current.get_parent()
	return null


## Recompute width/height from percent metas. Respects max-width/max-height.
static func update_size(control: Control) -> void:
	if not is_instance_valid(control):
		return

	var ref_size := _reference_size(control)
	if ref_size == Vector2.ZERO:
		return

	var width_percent: float = control.get_meta("width_percent", -1.0)
	var height_percent: float = control.get_meta("height_percent", -1.0)
	var new_size: Vector2 = control.custom_minimum_size

	if width_percent > 0 and width_percent < 1.0:
		new_size.x = ref_size.x * width_percent
	if height_percent > 0 and height_percent < 1.0:
		new_size.y = ref_size.y * height_percent

	new_size = _clamp_to_max(control, new_size, ref_size)

	control.custom_minimum_size = new_size
	control.size = new_size


## Clamp a Control's size to its max-width/max-height (both fixed and percent).
static func enforce_max(control: Control) -> void:
	if not is_instance_valid(control):
		return

	var max_w: float = control.get_meta("max_width", -1.0)
	var max_h: float = control.get_meta("max_height", -1.0)
	var max_w_pct: float = control.get_meta("max_width_percent", -1.0)
	var max_h_pct: float = control.get_meta("max_height_percent", -1.0)

	if max_w_pct > 0 or max_h_pct > 0:
		var ref_size := _reference_size(control)
		if ref_size != Vector2.ZERO:
			if max_w_pct > 0:
				var pct_max_w: float = ref_size.x * max_w_pct
				max_w = minf(max_w, pct_max_w) if max_w > 0 else pct_max_w
			if max_h_pct > 0:
				var pct_max_h: float = ref_size.y * max_h_pct
				max_h = minf(max_h, pct_max_h) if max_h > 0 else pct_max_h

	if max_w <= 0 and max_h <= 0:
		return

	var new_size: Vector2 = control.size
	var new_min: Vector2 = control.custom_minimum_size
	if max_w > 0:
		new_size.x = minf(new_size.x, max_w)
		new_min.x = minf(new_min.x, max_w)
	if max_h > 0:
		new_size.y = minf(new_size.y, max_h)
		new_min.y = minf(new_min.y, max_h)

	control.custom_minimum_size = new_min
	control.size = new_size


static func _reference_size(control: Control) -> Vector2:
	var view := find_gtml_view(control)
	if view != null:
		return view.size
	var parent: Node = control.get_parent()
	if parent is Control:
		return (parent as Control).size
	return Vector2.ZERO


static func _clamp_to_max(control: Control, new_size: Vector2, ref_size: Vector2) -> Vector2:
	var max_width: float = control.get_meta("max_width", -1.0)
	var max_width_pct: float = control.get_meta("max_width_percent", -1.0)
	if max_width_pct > 0:
		var pct_max: float = ref_size.x * max_width_pct
		max_width = minf(max_width, pct_max) if max_width > 0 else pct_max
	if max_width > 0 and new_size.x > max_width:
		new_size.x = max_width

	var max_height: float = control.get_meta("max_height", -1.0)
	var max_height_pct: float = control.get_meta("max_height_percent", -1.0)
	if max_height_pct > 0:
		var pct_max: float = ref_size.y * max_height_pct
		max_height = minf(max_height, pct_max) if max_height > 0 else pct_max
	if max_height > 0 and new_size.y > max_height:
		new_size.y = max_height

	return new_size
