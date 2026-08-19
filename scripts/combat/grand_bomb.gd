class_name GrandBomb
extends CharacterBody2D


signal detonated

var source: CombatUnit = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 110.0
var travel_time: float = 2.5
var damage_multiplier: float = 2.5
var blast_radius: float = 260.0
var knockback_strength: float = 420.0

var _exploded: bool = false
var _stopped: bool = false


func _ready() -> void:
	if source == null:
		queue_free()
		return
	collision_layer = 0
	collision_mask = 1
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	get_tree().create_timer(travel_time).timeout.connect(_explode)


func _on_source_died(_unit: CombatUnit) -> void:
	_explode()


func _physics_process(delta: float) -> void:
	if _exploded or _stopped:
		return
	if source == null or not is_instance_valid(source):
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision != null:
		_stopped = true


func detonate_early() -> void:
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	if source == null or not is_instance_valid(source):
		detonated.emit()
		queue_free()
		return
	var damage := source.get_attack() * damage_multiplier
	for group in [&"heroes", &"troops"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			if not node is CombatUnit:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if global_position.distance_to(node.global_position) > blast_radius:
				continue
			var dir: Vector2 = (node.global_position - global_position).normalized()
			if dir.length_squared() < 0.0001:
				dir = Vector2.UP
			var unit := node as CombatUnit
			if node.get("faction") == source.faction:
				unit.apply_hit_stun(dir * knockback_strength * 0.8)
			else:
				unit.take_damage(damage, dir * knockback_strength, source)
	detonated.emit()
	queue_free()
