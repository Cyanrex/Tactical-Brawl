class_name ShadowClone
extends Troop


const SHADOW_BOLT := preload("res://scenes/combat/projectiles/ShadowBolt.tscn")
const BOLT_SPEED := 480.0

@export var tether_range: float = 200.0
@export var lifespan: float = 8.0

var _anchor: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_anchor = global_position
	var sprite := get_node_or_null("MinionSprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(0.62, 0.42, 0.95, 0.72)
	remove_from_group("troops")
	invulnerable = true
	collision_layer = 0
	collision_mask = 0
	attack_range = tether_range
	get_tree().create_timer(lifespan).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if is_match_over():
		velocity = Vector2.ZERO
		state = UnitState.IDLE
		move_and_slide()
		return
	if state in [UnitState.STUNNED, UnitState.DEAD]:
		super._physics_process(delta)
		return
	if state in [UnitState.ATTACK, UnitState.CAST_SKILL]:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	velocity = Vector2.ZERO
	state = UnitState.IDLE
	move_and_slide()
	var target := _nearest_enemy()
	if target != null:
		perform_basic_attack(target.global_position)


func perform_basic_attack(aim_position: Vector2 = Vector2.INF) -> bool:
	if not _attack_ready:
		return false
	_attack_ready = false
	attack_cooldown_timer.start(attack_cooldown)
	var dir := resolve_aim_direction(aim_position)
	var bolt: ShadowBolt = SHADOW_BOLT.instantiate()
	bolt.source = self
	bolt.direction = dir
	bolt.damage = get_attack()
	bolt.knockback_strength = 0.0
	bolt.can_damage_towers = true
	bolt.speed = BOLT_SPEED
	bolt.anchor = _anchor
	bolt.max_range = tether_range
	bolt.collision_layer = 8 if faction == &"ally" else 16
	bolt.collision_mask = 37 if faction == &"ally" else 99
	bolt.global_position = global_position + dir * 24.0
	get_tree().current_scene.add_child(bolt)
	return true


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := tether_range
	for group in [&"heroes", &"troops"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			if node == self or node.get("faction") == faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if _anchor.distance_to(node.global_position) > tether_range:
				continue
			var distance := global_position.distance_to(node.global_position)
			if distance <= best_distance:
				best_distance = distance
				best = node
	return best
