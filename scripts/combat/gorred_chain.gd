class_name GorredChain
extends Node2D


signal finished(ended_early: bool)

var source: CombatUnit = null
var max_chains: int = 10
var chain_range: float = 260.0
var strike_radius: float = 60.0
var strike_damage: float = 140.0
var bleed_dps_ratio: float = 0.2
var bleed_duration: float = 10.0
var dash_speed: float = 950.0

var _current: Node2D = null
var _chain_count: int = 0
var _hit_ids: Dictionary = {}
var _finished: bool = false


func _ready() -> void:
	if source == null:
		queue_free()
		return
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	_current = _next_enemy()
	if _current == null:
		_finish(true)
		return
	_start_leap()


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	if source == null or not is_instance_valid(source) or source.is_dead():
		_finish(false)
		return
	if _current == null:
		return
	if not is_instance_valid(_current) or _is_dead(_current):
		_advance()
		return
	if source.global_position.distance_to(_current.global_position) <= strike_radius:
		_strike(_current)
		_chain_count += 1
		if _chain_count >= max_chains:
			_finish(false)
			return
		_advance()


func _advance() -> void:
	_current = _next_enemy()
	if _current == null:
		_finish(true)
		return
	_start_leap()


func _next_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := chain_range
	for group in [&"heroes", &"troops"]:
		for node in source.get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node == source:
				continue
			if node.get("faction") == source.faction:
				continue
			if _is_dead(node):
				continue
			if _hit_ids.has(node.get_instance_id()):
				continue
			var distance := source.global_position.distance_to(node.global_position)
			if distance <= best_distance:
				best_distance = distance
				best = node as Node2D
	return best


func _start_leap() -> void:
	if _current == null:
		return
	var dir := source.global_position.direction_to(_current.global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2(source.facing_direction, 0.0)
	source.facing_direction = 1 if dir.x >= 0.0 else -1
	var distance := source.global_position.distance_to(_current.global_position)
	source.start_dash(dir, dash_speed, distance / dash_speed)


func _strike(target: Node2D) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not target.has_method("take_damage"):
		return
	_hit_ids[target.get_instance_id()] = true
	var unit := target as CombatUnit
	if unit != null:
		unit.take_damage(strike_damage, Vector2.ZERO, source)
		if unit.has_method("apply_bleed"):
			unit.apply_bleed(source.get_attack() * bleed_dps_ratio, bleed_duration, source)
	else:
		target.take_damage(strike_damage)


func _is_dead(node: Node) -> bool:
	return node.has_method("is_dead") and node.is_dead()


func _on_source_died(_unit: CombatUnit) -> void:
	_finish(false)


func _finish(ended_early: bool) -> void:
	if _finished:
		return
	_finished = true
	source.dash_remaining = 0.0
	source.dash_velocity = Vector2.ZERO
	if source.state == CombatUnit.UnitState.CAST_SKILL:
		source.state = CombatUnit.UnitState.IDLE
	source.attack_lock_timer.stop()
	finished.emit(ended_early)
	queue_free()
