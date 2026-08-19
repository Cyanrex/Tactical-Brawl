class_name GorredWhirlwind
extends Area2D


var source: CombatUnit = null
var tick_damage: float = 15.0
var radius: float = 140.0
var duration: float = 1.2
var tick_interval: float = 0.2
var pull_speed: float = 200.0

var _tick_timer: Timer = null


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
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	_tick_timer = Timer.new()
	_tick_timer.wait_time = tick_interval
	_tick_timer.timeout.connect(_apply_tick)
	add_child(_tick_timer)
	_tick_timer.start()
	_apply_tick()
	get_tree().create_timer(duration).timeout.connect(_end_whirlwind)


func _on_source_died(_unit: CombatUnit) -> void:
	_end_whirlwind()


func _apply_tick() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		_end_whirlwind()
		return
	for body in get_overlapping_bodies():
		_strike(body)


func _strike(target: Node) -> void:
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
	var unit := target as CombatUnit
	if unit != null:
		unit.take_damage(tick_damage, Vector2.ZERO, source)
		unit.global_position = unit.global_position.move_toward(global_position, pull_speed * tick_interval)
	else:
		target.take_damage(tick_damage)


func _end_whirlwind() -> void:
	if _tick_timer != null:
		_tick_timer.stop()
	queue_free()
