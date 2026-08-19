class_name VoidLink
extends Node2D


var hero: Hero = null
var ally: Hero = null
var damage_multiplier: float = 1.25
var cdr_fraction: float = 0.2

var _line: Line2D = null
var _released: bool = false

func _ready() -> void:
	if hero == null or not is_instance_valid(hero) or ally == null or not is_instance_valid(ally):
		queue_free()
		return
	ally.damage_dealt_multiplier *= damage_multiplier
	ally.cooldown_reduction_fraction += cdr_fraction
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(0.45, 0.28, 0.9, 0.65)
	_line.add_point(hero.global_position)
	_line.add_point(ally.global_position)
	add_child(_line)

func _physics_process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		_release_and_free()
		return
	if ally == null or not is_instance_valid(ally) or ally.is_dead():
		_release_and_free()
		return
	if not BotTactics.can_see(hero, ally):
		_release_and_free()
		return
	_line.set_point_position(0, hero.global_position)
	_line.set_point_position(1, ally.global_position)

func _release_and_free() -> void:
	if _released:
		return
	_released = true
	if ally != null and is_instance_valid(ally):
		ally.damage_dealt_multiplier /= damage_multiplier
		ally.cooldown_reduction_fraction = maxf(ally.cooldown_reduction_fraction - cdr_fraction, 0.0)
	queue_free()

func _exit_tree() -> void:
	if not _released and ally != null and is_instance_valid(ally):
		ally.damage_dealt_multiplier /= damage_multiplier
		ally.cooldown_reduction_fraction = maxf(ally.cooldown_reduction_fraction - cdr_fraction, 0.0)
	_released = true
