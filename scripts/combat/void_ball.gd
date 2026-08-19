class_name VoidBall
extends Node2D


var hero: Hero = null
var duration: float = 6.0
var tether_range: float = 260.0
var max_links: int = 3
var damage_reduction_factor: float = 0.25
var reflect_factor: float = 0.6
var orbit_radius: float = 90.0

var _orbit_angle: float = 0.0
var _lines: Dictionary = {}
var _refresh_timer: Timer = null
var _end_timer: Timer = null

func _ready() -> void:
	if hero == null or not is_instance_valid(hero):
		queue_free()
		return
	hero.died.connect(_on_hero_died)
	hero.add_incoming_damage_modifier(get_instance_id(), _modify_incoming_damage)
	hero.damaged.connect(_on_hero_damaged)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.timeout.connect(_refresh_links)
	add_child(_refresh_timer)
	_refresh_timer.start()
	_end_timer = Timer.new()
	_end_timer.one_shot = true
	_end_timer.wait_time = duration
	_end_timer.timeout.connect(_on_expired)
	add_child(_end_timer)
	_end_timer.start()
	_refresh_links()

func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		queue_free()
		return
	_orbit_angle += delta * 0.9
	global_position = hero.global_position + Vector2.from_angle(_orbit_angle) * orbit_radius
	var keys := _lines.keys()
	for id in keys:
		var line: Line2D = _lines[id]
		if line == null or not is_instance_valid(line):
			continue
		var target := instance_from_id(id) as Node2D
		line.set_point_position(0, global_position)
		if target != null and is_instance_valid(target):
			line.set_point_position(1, target.global_position)

func _modify_incoming_damage(amount: float, source: CombatUnit = null) -> float:
	if source != null and is_instance_valid(source) and _lines.has(source.get_instance_id()):
		amount *= damage_reduction_factor
	return amount

func _on_hero_damaged(amount: float) -> void:
	if amount <= 0.0:
		return
	var reflected := amount * reflect_factor
	if reflected <= 0.0:
		return
	for id in _lines.keys():
		var target := instance_from_id(id) as CombatUnit
		if target == null or not is_instance_valid(target) or target.is_dead():
			continue
		target.take_damage(reflected, Vector2.ZERO, hero)

func _refresh_links() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var keys := _lines.keys()
	for id in keys:
		var target := instance_from_id(id) as Node2D
		if target == null or not is_instance_valid(target):
			_unlink(id)
			continue
		if target.has_method("is_dead") and target.is_dead():
			_unlink(id)
			continue
		if hero.global_position.distance_to(target.global_position) > tether_range:
			_unlink(id)
			continue
		if not BotTactics.can_see(hero, target):
			_unlink(id)
	if _lines.size() >= max_links:
		return
	var candidates: Array[CombatUnit] = []
	for group in [&"heroes", &"troops"]:
		for node in hero.get_tree().get_nodes_in_group(group):
			if not node is CombatUnit:
				continue
			var unit := node as CombatUnit
			if unit.faction == hero.faction:
				continue
			if unit.is_dead():
				continue
			if _lines.has(unit.get_instance_id()):
				continue
			if hero.global_position.distance_to(unit.global_position) > tether_range:
				continue
			if not BotTactics.can_see(hero, unit):
				continue
			candidates.append(unit)
	candidates.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		return hero.global_position.distance_to(a.global_position) < hero.global_position.distance_to(b.global_position))
	for unit in candidates:
		if _lines.size() >= max_links:
			break
		_link(unit)

func _link(target: CombatUnit) -> void:
	var line := Line2D.new()
	line.width = 2.5
	line.default_color = Color(0.7, 0.4, 1.0, 0.8)
	line.add_point(global_position)
	line.add_point(target.global_position)
	add_child(line)
	_lines[target.get_instance_id()] = line

func _unlink(id: int) -> void:
	var line: Line2D = _lines.get(id)
	if line != null and is_instance_valid(line):
		line.queue_free()
	_lines.erase(id)

func _on_hero_died(_unit: CombatUnit) -> void:
	queue_free()

func _on_expired() -> void:
	queue_free()

func _exit_tree() -> void:
	if hero != null and is_instance_valid(hero):
		hero.remove_incoming_damage_modifier(get_instance_id())
		if hero.damaged.is_connected(_on_hero_damaged):
			hero.damaged.disconnect(_on_hero_damaged)
	for id in _lines.keys():
		var line: Line2D = _lines[id]
		if line != null and is_instance_valid(line):
			line.queue_free()
	_lines.clear()
