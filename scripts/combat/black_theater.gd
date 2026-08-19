class_name BlackTheater
extends Area2D


const SHADOW_CLONE := preload("res://scenes/actors/troops/ShadowClone.tscn")

var source: CombatUnit = null
var slow_factor: float = 0.35
var slow_duration: float = 1.0
var tick_interval: float = 0.5
var duration: float = 8.0
var radius: float = 260.0
var clone_count: int = 3
var clone_damage_ratio: float = 0.4
var attack_bonus: float = 0.5

var _tick_timer: Timer = null
var _clones: Array = []
var _bonus_applied: bool = false
var _visual: Polygon2D = null


func _ready() -> void:
	if source == null:
		queue_free()
		return
	collision_layer = 8 if source.faction == &"ally" else 16
	collision_mask = 4 if source.faction == &"ally" else 2
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var circle := shape_node.shape as CircleShape2D
		if circle != null:
			circle.radius = radius
	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual != null:
		_visual.polygon = _circle_polygon(radius, 24)
	body_entered.connect(_slow_target)
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	_tick_timer = Timer.new()
	_tick_timer.wait_time = tick_interval
	_tick_timer.timeout.connect(_apply_tick)
	add_child(_tick_timer)
	_tick_timer.start()
	_apply_tick()
	_apply_bonus()
	_spawn_clones()
	get_tree().create_timer(duration).timeout.connect(_end_theater)


func _physics_process(_delta: float) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	global_position = source.global_position
	for body in get_overlapping_bodies():
		_slow_target(body)
	if global_position.distance_to(source.global_position) <= radius:
		if not _bonus_applied:
			_apply_bonus()
	else:
		if _bonus_applied:
			_remove_bonus()


func _on_source_died(_unit: CombatUnit) -> void:
	_teardown()


func _apply_tick() -> void:
	if source == null or not is_instance_valid(source):
		return
	for body in get_overlapping_bodies():
		_slow_target(body)


func _slow_target(target: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	if not target.has_method("take_damage"):
		return
	if target is Tower:
		return
	if target.get("faction") == source.faction:
		return
	if target.has_method("is_dead") and target.is_dead():
		return
	if target.has_method("apply_slow"):
		target.apply_slow(slow_factor, slow_duration)


func _apply_bonus() -> void:
	if _bonus_applied:
		return
	source.buff_attack_multiplier += attack_bonus
	_bonus_applied = true


func _remove_bonus() -> void:
	if not _bonus_applied:
		return
	source.buff_attack_multiplier = maxf(source.buff_attack_multiplier - attack_bonus, 0.0)
	_bonus_applied = false


func _spawn_clones() -> void:
	for i in clone_count:
		var clone: ShadowClone = SHADOW_CLONE.instantiate()
		clone.faction = source.faction
		clone.attack = source.get_attack() * clone_damage_ratio
		clone.lifespan = duration
		var angle := TAU * float(i) / float(clone_count)
		clone.global_position = global_position + Vector2.RIGHT.rotated(angle) * radius * 0.45
		get_tree().current_scene.add_child(clone)
		_clones.append(clone)


func _end_theater() -> void:
	_teardown()


func _teardown() -> void:
	for clone in _clones:
		if clone != null and is_instance_valid(clone):
			clone.queue_free()
	_clones.clear()
	_remove_bonus()
	if _tick_timer != null:
		_tick_timer.stop()
	queue_free()


func _circle_polygon(rad: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * rad)
	return points
