class_name VoidAnchor
extends Node2D


const BASIC_HITBOX := preload("res://scenes/combat/hitboxes/BasicAttackHitbox.tscn")

var hero: Hero = null
var damage_multiplier: float = 7.2
var explosion_radius: float = 170.0
var knockback_strength: float = 200.0

var _line: Line2D = null
var _visual: Polygon2D = null
var _exploded: bool = false
var _pulse: float = 0.0

func _ready() -> void:
	_line = Line2D.new()
	_line.width = 2.5
	_line.default_color = Color(0.62, 0.35, 0.95, 0.75)
	_line.add_point(global_position)
	_line.add_point(hero.global_position if hero != null else global_position)
	add_child(_line)
	_visual = Polygon2D.new()
	_visual.color = Color(0.62, 0.35, 0.95, 0.9)
	_visual.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(10, -6), Vector2(0, 4), Vector2(-10, -6),
	])
	add_child(_visual)

func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		queue_free()
		return
	_pulse += delta * 4.0
	_visual.rotation = _pulse * 0.5
	var pulse_scale := 1.0 + sin(_pulse) * 0.15
	_visual.scale = Vector2(pulse_scale, pulse_scale)
	_line.set_point_position(0, global_position)
	_line.set_point_position(1, hero.global_position)

func is_exploded() -> bool:
	return _exploded

func explode(teleport_hero: bool) -> void:
	if _exploded:
		return
	_exploded = true
	var burst_point := global_position
	if teleport_hero and hero != null and is_instance_valid(hero) and not hero.is_dead():
		burst_point = global_position
		hero.global_position = burst_point
		hero.dash_remaining = 0.0
		hero.dash_velocity = Vector2.ZERO
		if hero.state == CombatUnit.UnitState.CAST_SKILL:
			hero.state = CombatUnit.UnitState.IDLE
		hero.attack_lock_timer.stop()
	elif hero != null and is_instance_valid(hero):
		burst_point = hero.global_position
	_spawn_burst(burst_point)
	queue_free()

func _spawn_burst(at: Vector2) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var hitbox: AttackHitbox = BASIC_HITBOX.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.damage_multiplier = damage_multiplier
	hitbox.knockback_strength = knockback_strength
	hitbox.lifetime = 0.3
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 4 if hero.faction == &"ally" else 2
	hitbox.scale = Vector2(explosion_radius / 40.0, explosion_radius / 40.0)
	hitbox.global_position = at
	hero.get_tree().current_scene.add_child(hitbox)
