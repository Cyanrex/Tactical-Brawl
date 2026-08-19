class_name VoidSpike
extends Node2D


const BOLT_SCENE := preload("res://scenes/combat/projectiles/VoidBolt.tscn")

var hero: Hero = null
var orbit_angle: float = 0.0
var orbit_radius: float = 62.0
var attack_interval: float = 1.0
var bolt_damage_multiplier: float = 1.0
var bolt_speed: float = 620.0
var stagger: float = 0.0

var _cooldown: float = 0.0

func _ready() -> void:
	_cooldown = stagger

func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		queue_free()
		return
	orbit_angle += delta * 1.6
	global_position = hero.global_position + Vector2.from_angle(orbit_angle) * orbit_radius
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = attack_interval
		_fire()

func _fire() -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		return
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target == null:
		return
	var bolt: Projectile = BOLT_SCENE.instantiate()
	bolt.source = hero
	bolt.direction = global_position.direction_to(target.global_position)
	bolt.damage = hero.get_attack() * bolt_damage_multiplier
	bolt.knockback_strength = 60.0
	bolt.collision_layer = 8 if hero.faction == &"ally" else 16
	bolt.collision_mask = 5 if hero.faction == &"ally" else 3
	bolt.global_position = global_position
	hero.get_tree().current_scene.add_child(bolt)
