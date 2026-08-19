class_name ZhalrethAura
extends Area2D

var source: CombatUnit = null
var damage_per_tick: float = 0.0
var slow_factor: float = 0.4
var slow_duration: float = 1.0
var tick_interval: float = 0.5
var duration: float = 6.0
var radius: float = 150.0

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
	body_entered.connect(_damage_target)
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	_tick_timer = Timer.new()
	_tick_timer.wait_time = tick_interval
	_tick_timer.timeout.connect(_apply_tick)
	add_child(_tick_timer)
	_tick_timer.start()
	_apply_tick()
	get_tree().create_timer(duration).timeout.connect(queue_free)

func _on_source_died(_unit: CombatUnit) -> void:
	queue_free()

func _apply_tick() -> void:
	for body in get_overlapping_bodies():
		_damage_target(body)

func _damage_target(target: Node) -> void:
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
	if target is CombatUnit:
		target.take_damage(damage_per_tick, Vector2.ZERO, source)
	else:
		target.take_damage(damage_per_tick)
	if source.lifesteal_fraction > 0.0:
		source.ai_regenerate(damage_per_tick * source.lifesteal_fraction)
	if target.has_method("apply_slow"):
		target.apply_slow(slow_factor, slow_duration)
