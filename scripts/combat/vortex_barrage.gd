class_name VortexBarrage
extends Area2D


var source: CombatUnit = null
var slash_damage: float = 8.0
var heal_per_hit: float = 4.0
var radius: float = 200.0
var duration: float = 2.0
var cc_immune_duration: float = 4.0
var pull_speed: float = 180.0

var _slash_interval: float = 0.1667
var _slash_timer: Timer = null
var _immune_timer: Timer = null


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
	source.cc_immunity = true
	_immune_timer = Timer.new()
	_immune_timer.one_shot = true
	_immune_timer.wait_time = cc_immune_duration
	_immune_timer.timeout.connect(_clear_immunity)
	source.add_child(_immune_timer)
	_immune_timer.start()
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	_slash_timer = Timer.new()
	_slash_timer.wait_time = _slash_interval
	_slash_timer.timeout.connect(_apply_slash)
	add_child(_slash_timer)
	_slash_timer.start()
	_apply_slash()
	get_tree().create_timer(duration).timeout.connect(_end_vortex)


func _on_source_died(_unit: CombatUnit) -> void:
	_clear_immunity()
	_end_vortex()


func _clear_immunity() -> void:
	if source != null and is_instance_valid(source):
		source.cc_immunity = false
	if _immune_timer != null and is_instance_valid(_immune_timer):
		_immune_timer.stop()


func _end_vortex() -> void:
	if _slash_timer != null:
		_slash_timer.stop()
	queue_free()


func _apply_slash() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	for body in get_overlapping_bodies():
		_slash(body)


func _slash(target: Node) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not target.has_method("take_damage"):
		return
	if target is Tower:
		return
	if target.get("faction") == source.faction:
		return
	if target.has_method("is_dead") and target.is_dead():
		return
	if target is CombatUnit:
		(target as CombatUnit).take_damage(slash_damage, Vector2.ZERO, source)
	else:
		target.take_damage(slash_damage)
	source.ai_regenerate(heal_per_hit)
	if target is CombatUnit:
		var unit := target as CombatUnit
		var dir := global_position.direction_to(unit.global_position)
		if dir.length_squared() > 0.0001:
			unit.velocity = unit.velocity.move_toward(dir * pull_speed, pull_speed * 0.4)
