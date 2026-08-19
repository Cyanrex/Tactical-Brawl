class_name BloodTether
extends Node2D


var hero: CombatUnit = null
var target: Node2D = null
var snap_range: float = 420.0
var snap_damage_multiplier: float = 1.5
var slow_factor: float = 0.4
var slow_duration: float = 3.0
var duration: float = 3.0

var _line: Line2D = null
var _end_timer: Timer = null


func _ready() -> void:
	if hero == null or target == null or not is_instance_valid(target):
		queue_free()
		return
	if target.has_method("apply_slow"):
		target.apply_slow(slow_factor, slow_duration)
	_line = Line2D.new()
	_line.width = 3.0
	_line.default_color = Color(0.75, 0.05, 0.1, 0.8)
	_line.add_point(hero.global_position)
	_line.add_point(target.global_position)
	add_child(_line)
	_end_timer = Timer.new()
	_end_timer.one_shot = true
	_end_timer.wait_time = duration
	_end_timer.timeout.connect(_expire)
	add_child(_end_timer)
	_end_timer.start()


func _physics_process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.is_dead():
		queue_free()
		return
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	if target.has_method("is_dead") and target.is_dead():
		queue_free()
		return
	if hero.global_position.distance_to(target.global_position) > snap_range:
		_snap()
		return
	_line.set_point_position(0, hero.global_position)
	_line.set_point_position(1, target.global_position)


func _snap() -> void:
	if target != null and is_instance_valid(target) and not (target.has_method("is_dead") and target.is_dead()):
		if target.has_method("take_damage"):
			var damage := hero.get_attack() * snap_damage_multiplier
			var dir := hero.global_position.direction_to(target.global_position)
			if target is CombatUnit:
				(target as CombatUnit).take_damage(damage, dir * 260.0, hero)
			else:
				target.take_damage(damage)
	queue_free()


func _expire() -> void:
	queue_free()
