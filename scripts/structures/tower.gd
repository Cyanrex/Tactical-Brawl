class_name Tower
extends StaticBody2D

signal health_changed(current_hp: float, max_hp: float)
signal died(tower: Tower)

@export var max_hp: float = 35000.0
@export var faction: StringName = &"enemy"
@export var is_main: bool = false
@export var heal_radius: float = 260.0
@export var heal_rate: float = 100.0
@export var heal_percent_per_tick: float = 0.30
@export var heal_tick_interval: float = 1.0
@export var main_heal_radius: float = 600.0
@export var main_heal_radius_cap: float = 790.0
@export var damage_alert_duration: float = 4.0

var hp: float = 35000.0
var dead: bool = false
var _damage_alert_until_msec: int = 0

var _heal_timer: Timer = null

func _ready() -> void:
	add_to_group("structures")
	hp = max_hp
	collision_layer = 64 if faction == &"ally" else 32
	health_changed.emit(hp, max_hp)
	if is_main:
		heal_radius = minf(main_heal_radius, main_heal_radius_cap)
		_heal_timer = Timer.new()
		_heal_timer.wait_time = heal_tick_interval
		_heal_timer.timeout.connect(_on_heal_tick)
		add_child(_heal_timer)
		_heal_timer.start()
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.register_tower(self)

func _physics_process(delta: float) -> void:
	if dead or not _is_playing() or is_main:
		return
	var heal_amount := heal_rate * delta
	if heal_amount <= 0.0:
		return
	_heal_units(heal_amount)

func _on_heal_tick() -> void:
	if dead or not _is_playing():
		return
	for group in [&"heroes", &"troops"]:
		for unit in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(unit):
				continue
			if unit.get("faction") != faction:
				continue
			if global_position.distance_to(unit.global_position) > heal_radius:
				continue
			if not unit.has_method("ai_regenerate"):
				_warn_heal_skip(unit, group)
				continue
			var unit_max_hp: float = unit.get("max_hp")
			if unit_max_hp > 0.0:
				unit.ai_regenerate(unit_max_hp * heal_percent_per_tick)

func _heal_units(flat_amount: float) -> void:
	for group in [&"heroes", &"troops"]:
		for unit in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(unit):
				continue
			if unit.get("faction") != faction:
				continue
			if global_position.distance_to(unit.global_position) > heal_radius:
				continue
			if not unit.has_method("ai_regenerate"):
				_warn_heal_skip(unit, group)
				continue
			unit.ai_regenerate(flat_amount)

var _heal_skip_warned: Dictionary = {}

func _warn_heal_skip(unit: Node, group: StringName) -> void:
	var id := unit.get_instance_id()
	if _heal_skip_warned.has(id):
		return
	_heal_skip_warned[id] = true
	var scr: Script = unit.get_script()
	var script_desc := "none"
	if scr != null:
		script_desc = scr.resource_path if not scr.resource_path.is_empty() else "ANONYMOUS(%s)" % str(scr.get_instance_id())
	var pos: Vector2 = (unit as Node2D).global_position if unit is Node2D else Vector2.INF
	push_warning("Tower heal skipped non-combatant %s in group '%s' (class=%s script=%s pos=%s)" % [unit.name, group, unit.get_class(), script_desc, pos])

func _is_playing() -> bool:
	var mm := get_tree().root.get_node_or_null("MatchManager")
	return mm != null and mm.match_state == MatchManager.MatchState.PLAYING

func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO, is_basic_attack: bool = false) -> void:
	if dead or not is_basic_attack:
		return
	hp = maxf(hp - amount, 0.0)
	if amount > 0.0:
		_damage_alert_until_msec = Time.get_ticks_msec() + int(maxf(damage_alert_duration, 0.0) * 1000.0)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		die()

func is_under_attack() -> bool:
	return not dead and Time.get_ticks_msec() < _damage_alert_until_msec

func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	hide()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

func is_dead() -> bool:
	return dead
