class_name FloatingText
extends CanvasLayer

const LIFETIME := 1.6
const RISE_HEIGHT := 42.0
const STACK_SPACING := 13.0
const MAX_STACK := 4
const MAX_POPUPS := 48
const FONT_SIZE := 15
const JITTER_RANGE := 6.0

var _popups: Dictionary = {}
var _order: Array = []

static func ensure_in(tree: SceneTree) -> FloatingText:
	var scene := tree.current_scene
	if scene == null:
		return null
	var existing := scene.get_node_or_null("FloatingText") as FloatingText
	if existing == null:
		existing = FloatingText.new()
		existing.name = "FloatingText"
		existing.layer = 100
		scene.add_child(existing)
	return existing

func show_damage(target: CombatUnit, amount: float) -> void:
	var id := target.get_instance_id()
	if _popups.has(id):
		var entry: Dictionary = _popups[id]
		var label: Label = entry.label
		label.text = str(roundi(amount))
		entry.elapsed = 0.0
		entry.stack = mini(entry.stack + 1, MAX_STACK)
		entry.pop = 1.0
		entry.target = target
		entry.last_world_pos = target.global_position
		return
	var new_label := _make_label()
	new_label.text = str(roundi(amount))
	var new_entry := {
		"label": new_label,
		"elapsed": 0.0,
		"stack": 0,
		"pop": 0.0,
		"jitter": randf_range(-JITTER_RANGE, JITTER_RANGE),
		"target": target,
		"last_world_pos": target.global_position,
	}
	_popups[id] = new_entry
	_order.append(id)

func _make_label() -> Label:
	var settings := LabelSettings.new()
	settings.font_size = FONT_SIZE
	settings.font_color = Color(1.0, 1.0, 1.0, 1.0)
	settings.outline_size = 4
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	var label := Label.new()
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _process(delta: float) -> void:
	var canvas_transform := get_viewport().get_canvas_transform()
	var expired: Array = []
	for id: int in _popups:
		var entry: Dictionary = _popups[id]
		var label: Label = entry.label
		var elapsed: float = entry.elapsed + delta
		entry.elapsed = elapsed
		var t: float = elapsed / LIFETIME
		if t >= 1.0:
			expired.append(id)
			continue
		var target: Variant = entry.target
		if is_instance_valid(target):
			entry.last_world_pos = target.global_position
		var screen_pos: Vector2 = canvas_transform * entry.last_world_pos
		var rise: float = RISE_HEIGHT * (t * (2.0 - t)) + entry.stack * STACK_SPACING
		entry.pop = maxf(entry.pop - delta * 4.0, 0.0)
		label.modulate.a = 1.0 if t < 0.55 else 1.0 - (t - 0.55) / 0.45
		label.scale = Vector2.ONE * (1.0 + 0.35 * entry.pop)
		label.position = screen_pos + Vector2(entry.jitter, -rise)
		label.position.x -= label.size.x * 0.5
	for id: int in expired:
		_remove(id)
	while _order.size() > MAX_POPUPS:
		_remove(_order[0])

func _remove(id: int) -> void:
	if not _popups.has(id):
		return
	var entry: Dictionary = _popups[id]
	var label: Label = entry.label
	if is_instance_valid(label):
		label.queue_free()
	_popups.erase(id)
	_order.erase(id)
