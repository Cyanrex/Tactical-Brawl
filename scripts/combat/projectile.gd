class_name Projectile
extends Area2D

signal projectile_hit(target: Node)

@export var speed: float = 400.0
@export var lifetime: float = 2.0
@export var seeking: bool = false
@export var turn_speed: float = 10.0
@export var target_scan_range: float = 900.0

var source: CombatUnit = null
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var knockback_strength: float = 0.0
var can_damage_towers: bool = false
var hit_targets: Dictionary = {}
var target_node: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if seeking:
		_update_seek(delta)
	global_position += direction * speed * delta

func _update_seek(delta: float) -> void:
	if target_node == null or not is_instance_valid(target_node) or _is_dead(target_node):
		target_node = _retarget()
	if target_node != null:
		var desired := global_position.direction_to(target_node.global_position)
		direction = direction.lerp(desired, turn_speed * delta).normalized()

func _retarget() -> Node2D:
	if source == null or not is_instance_valid(source):
		return null
	var best: Node2D = null
	var best_distance := target_scan_range
	for group in [&"heroes", &"troops", &"structures"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node == source:
				continue
			if node.get("faction") == source.faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if source != null and is_instance_valid(source) and not BotTactics.can_see(source, node):
				continue
			var distance := global_position.distance_to(node.global_position)
			if distance <= best_distance:
				best_distance = distance
				best = node
	return best

func _is_dead(node: Node2D) -> bool:
	return node.has_method("is_dead") and node.is_dead()

func _on_body_entered(target: Node) -> void:
	try_hit(target)

func try_hit(target: Node) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not target.has_method("take_damage"):
		queue_free()
		return
	if target is Tower and not can_damage_towers:
		return
	if target.get("faction") == source.faction:
		return
	if target.has_method("is_dead") and target.is_dead():
		return
	var id := target.get_instance_id()
	if hit_targets.has(id):
		return
	hit_targets[id] = true
	var unit := target as CombatUnit
	if unit != null:
		unit.take_damage(damage, direction * knockback_strength, source)
	elif target is Tower:
		(target as Tower).take_damage(damage, direction * knockback_strength, can_damage_towers)
	else:
		target.take_damage(damage, direction * knockback_strength)
	projectile_hit.emit(target)
	queue_free()
