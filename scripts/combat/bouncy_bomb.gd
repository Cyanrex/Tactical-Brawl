class_name BouncyBomb
extends CharacterBody2D


const FAILSAFE_LIFETIME := 15.0
const TRAIL_INTERVAL := 0.05
const TRAIL_LIFETIME := 0.5

var source: CombatUnit = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var acceleration: float = 200.0
var max_speed: float = 900.0
var damage_multiplier: float = 1.6
var blast_radius: float = 120.0
var knockback_strength: float = 200.0

var _exploded: bool = false
var _trail_cooldown: float = 0.0


func _ready() -> void:
	if source == null:
		queue_free()
		return
	collision_layer = 0
	collision_mask = 1 | (4 if source.faction == &"ally" else 2)
	if source is CombatUnit:
		source.died.connect(_on_source_died)
	get_tree().create_timer(FAILSAFE_LIFETIME).timeout.connect(queue_free)


func _on_source_died(_unit: CombatUnit) -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	if _exploded or source == null or not is_instance_valid(source):
		return
	speed = minf(speed + acceleration * delta, max_speed)
	_trail_cooldown -= delta
	if _trail_cooldown <= 0.0:
		_trail_cooldown = TRAIL_INTERVAL
		_spawn_smoke_puff()
	var collision := move_and_collide(direction * speed * delta)
	if collision == null:
		return
	var body := collision.get_collider()
	if _is_damageable_enemy(body):
		_explode()
		return
	direction = direction.bounce(collision.get_normal())


func _is_damageable_enemy(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not body.has_method("take_damage"):
		return false
	if body is Tower:
		return false
	if body.get("faction") == source.faction:
		return false
	if body.has_method("is_dead") and body.is_dead():
		return false
	return true


func _spawn_smoke_puff() -> void:
	var puff := Polygon2D.new()
	puff.polygon = _circle_polygon(randf_range(4.0, 6.0), 8)
	puff.color = Color(0.4, 0.38, 0.4, 0.24)
	puff.position = global_position - direction * 12.0
	puff.z_index = -1
	get_tree().current_scene.add_child(puff)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector2(1.8, 1.8), TRAIL_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "color:a", 0.0, TRAIL_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(puff.queue_free)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var damage := source.get_attack() * damage_multiplier
	for group in [&"heroes", &"troops"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get("faction") == source.faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if global_position.distance_to(node.global_position) > blast_radius:
				continue
			var dir: Vector2 = (node.global_position - global_position).normalized()
			if dir.length_squared() < 0.0001:
				dir = Vector2.UP
			if node is CombatUnit:
				(node as CombatUnit).take_damage(damage, dir * knockback_strength, source)
			else:
				node.take_damage(damage)
	queue_free()


func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
