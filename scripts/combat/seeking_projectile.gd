class_name SeekingProjectile
extends Area2D

@export var speed: float = 340.0
@export var lifetime: float = 4.0
@export var aoe_radius: float = 90.0
@export var turn_speed: float = 6.0
@export var target_scan_range: float = 700.0

var source: CombatUnit = null
var faction: StringName = &"ally"
var target: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var knockback_strength: float = 120.0
var can_damage_towers: bool = false
var _exploded: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or _is_dead(target):
		target = _retarget()
	if target != null:
		var desired := global_position.direction_to(target.global_position)
		direction = direction.lerp(desired, turn_speed * delta).normalized()
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not body.has_method("take_damage"):
		queue_free()
		return
	if body is Tower and not can_damage_towers:
		return
	if body.get("faction") == faction:
		return
	_exploded = true
	_explode()
	queue_free()

func _explode() -> void:
	for group in [&"heroes", &"troops", &"structures"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get("faction") == faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if global_position.distance_to(node.global_position) <= aoe_radius:
				_damage(node)

func _damage(node: Node) -> void:
	if node is Tower and not can_damage_towers:
		return
	var unit := node as CombatUnit
	var knockback: Vector2 = (node.global_position - global_position).normalized() * knockback_strength
	if unit != null:
		unit.take_damage(damage, knockback, source)
	else:
		node.take_damage(damage, knockback)

func _retarget() -> Node2D:
	var hero_target := _nearest_enemy_hero()
	if hero_target != null:
		return hero_target
	return _nearest_enemy_troop()

func _nearest_enemy_hero() -> Node2D:
	var best: Node2D = null
	var best_distance := target_scan_range
	for node in get_tree().get_nodes_in_group(&"heroes"):
		if node.get("faction") == faction:
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

func _nearest_enemy_troop() -> Node2D:
	var best: Node2D = null
	var best_distance := target_scan_range
	for node in get_tree().get_nodes_in_group(&"troops"):
		if node.get("faction") == faction:
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

func _is_dead(target: Node2D) -> bool:
	return target.has_method("is_dead") and target.is_dead()
