class_name CombatUnit
extends CharacterBody2D

enum UnitState {
	IDLE,
	MOVE,
	ATTACK,
	CAST_SKILL,
	RETREAT,
	STUNNED,
	DEAD
}

signal health_changed(current_hp: float, max_hp: float)
signal damaged(amount: float)
signal died(unit: CombatUnit)
signal attack_started()
signal skill_used(skill_id: StringName)
signal invulnerable_hit(source: Node)

@export var max_hp: float = 5000.0
@export var attack: float = 150.0
@export var move_speed: float = 200.0
@export var faction: StringName = &"ally"
@export var level: int = 1
@export var exp: float = 0.0
@export var exp_value: float = 10.0
@export var hit_stun_duration: float = 0.25
@export var knockback_friction: float = 1200.0
@export var basic_attack_scene: PackedScene
@export var attack_lock_duration: float = 0.35
@export var can_attack_while_moving: bool = false
@export var basic_attack_range: float = -1.0
@export var basic_attack_projectile: PackedScene = null
@export var basic_attack_kite_range: float = -1.0

const SEEKING_BASIC_PROJECTILE_SPEED := 620.0
const SEEKING_BASIC_PROJECTILE_TURN_SPEED := 12.0

var hp: float = 5000.0
var state: UnitState = UnitState.IDLE
var facing_direction: int = 1
var last_hit_source: CombatUnit = null
var damage_contributions: Dictionary = {}

var spawn_slot_offset: Vector2 = Vector2.ZERO

var buff_attack_multiplier: float = 1.0
var damage_dealt_multiplier: float = 1.0
var _incoming_damage_modifiers: Dictionary = {}
var lifesteal_fraction: float = 0.0
var move_speed_multiplier: float = 1.0
var move_speed_buff_multiplier: float = 1.0
var invulnerable: bool = false
var cc_immunity: bool = false

var _slow_timer: Timer = null
var _slow_active: bool = false
var _slow_factor: float = 0.0
var _root_active: bool = false
var _root_timer: Timer = null

var _default_collision_layer: int = 0
var _default_collision_mask: int = 0

@onready var hit_stun_timer: Timer = $HitStunTimer
@onready var attack_origin: Marker2D = $AttackOrigin
@onready var attack_lock_timer: Timer = $AttackLockTimer

func _ready() -> void:
	var enemy_unit_layer := 4 if faction == &"ally" else 2
	var enemy_tower_layer := 32 if faction == &"ally" else 64
	collision_mask = collision_mask & ~enemy_unit_layer & ~32
	collision_mask = collision_mask | enemy_tower_layer
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	hp = max_hp
	hit_stun_timer.timeout.connect(_on_hit_stun_finished)
	attack_lock_timer.timeout.connect(_on_attack_lock_finished)
	_setup_health_bar()
	health_changed.emit(hp, max_hp)
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.register_combatant(self)

func _setup_health_bar() -> void:
	if self is PlayerHero or not self is Hero:
		return
	var bar := HealthBar2D.new()
	bar.name = "HealthBar"
	bar.fill_color = Color(0.85, 0.25, 0.22) if faction == &"enemy" else Color(0.32, 0.85, 0.38)
	add_child(bar)
	bar.update_value(hp, max_hp)
	health_changed.connect(func(current_hp: float, max_hp_value: float) -> void:
		if is_instance_valid(bar):
			bar.update_value(current_hp, max_hp_value))

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, source: CombatUnit = null) -> void:
	if state == UnitState.DEAD:
		return
	if invulnerable:
		invulnerable_hit.emit(source)
		return
	last_hit_source = source
	amount = _apply_incoming_damage_modifiers(amount, source)
	var hp_before := hp
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, max_hp)
	var damage_dealt := minf(amount, hp_before)
	if damage_dealt > 0.0 and source is Hero and is_instance_valid(source) and not source.is_dead() and source.faction != faction:
		damage_contributions[source] = float(damage_contributions.get(source, 0.0)) + damage_dealt
	damaged.emit(amount)
	if amount > 0.0:
		var ft := FloatingText.ensure_in(get_tree())
		if ft != null:
			ft.show_damage(self, amount)
	if knockback != Vector2.ZERO:
		apply_hit_stun(knockback)
	if hp <= 0.0:
		die()

func add_incoming_damage_modifier(modifier_id: int, modifier: Callable) -> void:
	_incoming_damage_modifiers[modifier_id] = modifier

func remove_incoming_damage_modifier(modifier_id: int) -> void:
	_incoming_damage_modifiers.erase(modifier_id)

func _apply_incoming_damage_modifiers(amount: float, source: CombatUnit) -> float:
	for modifier in _incoming_damage_modifiers.values():
		amount = modifier.call(amount, source)
	return amount

func reset_respawn_effects() -> void:
	if hit_stun_timer != null:
		hit_stun_timer.stop()
	if attack_lock_timer != null:
		attack_lock_timer.stop()
	if _slow_timer != null:
		_slow_timer.stop()
	if _root_timer != null:
		_root_timer.stop()
	_slow_active = false
	_slow_factor = 0.0
	_root_active = false
	_bleed_dps = 0.0
	_bleed_source = null
	if _bleed_tick_timer != null:
		_bleed_tick_timer.stop()
	if _bleed_end_timer != null:
		_bleed_end_timer.stop()
	_incoming_damage_modifiers.clear()
	buff_attack_multiplier = 1.0
	damage_dealt_multiplier = 1.0
	lifesteal_fraction = 0.0
	move_speed_multiplier = 1.0
	move_speed_buff_multiplier = 1.0
	invulnerable = false
	cc_immunity = false

func apply_hit_stun(knockback: Vector2) -> void:
	if cc_immunity:
		return
	state = UnitState.STUNNED
	velocity = knockback
	hit_stun_timer.start(hit_stun_duration)

func _on_hit_stun_finished() -> void:
	if state == UnitState.STUNNED:
		state = UnitState.IDLE

func is_dead() -> bool:
	return state == UnitState.DEAD

func is_match_over() -> bool:
	var mm := get_tree().root.get_node_or_null("MatchManager")
	return mm != null and mm.is_match_over()

func get_attack() -> float:
	return attack * buff_attack_multiplier * damage_dealt_multiplier

func get_move_speed() -> float:
	return move_speed * move_speed_multiplier * move_speed_buff_multiplier

func apply_slow(factor: float, duration: float) -> void:
	if state == UnitState.DEAD:
		return
	_slow_active = true
	_slow_factor = factor
	move_speed_multiplier = 1.0 - factor if not _root_active else 0.0
	if _slow_timer == null:
		_slow_timer = Timer.new()
		_slow_timer.one_shot = true
		_slow_timer.timeout.connect(_on_slow_finished)
		add_child(_slow_timer)
	_slow_timer.start(duration)

func _on_slow_finished() -> void:
	_slow_active = false
	if _root_active:
		return
	move_speed_multiplier = 1.0

func apply_root(duration: float) -> void:
	if state == UnitState.DEAD:
		return
	_root_active = true
	move_speed_multiplier = 0.0
	if _root_timer == null:
		_root_timer = Timer.new()
		_root_timer.one_shot = true
		_root_timer.timeout.connect(_on_root_finished)
		add_child(_root_timer)
	_root_timer.start(duration)

func _on_root_finished() -> void:
	_root_active = false
	move_speed_multiplier = 1.0 - _slow_factor if _slow_active else 1.0

var _bleed_dps: float = 0.0
var _bleed_source: CombatUnit = null
var _bleed_tick_timer: Timer = null
var _bleed_end_timer: Timer = null

func apply_bleed(dps: float, duration: float, source: CombatUnit = null) -> void:
	if state == UnitState.DEAD:
		return
	_bleed_dps = maxf(_bleed_dps, dps)
	_bleed_source = source if source != null else last_hit_source
	if _bleed_tick_timer == null:
		_bleed_tick_timer = Timer.new()
		_bleed_tick_timer.wait_time = 0.5
		_bleed_tick_timer.timeout.connect(_on_bleed_tick)
		add_child(_bleed_tick_timer)
		_bleed_tick_timer.start()
	if _bleed_end_timer == null:
		_bleed_end_timer = Timer.new()
		_bleed_end_timer.one_shot = true
		_bleed_end_timer.timeout.connect(_on_bleed_finished)
		add_child(_bleed_end_timer)
	_bleed_end_timer.start(duration)

func _on_bleed_tick() -> void:
	if state == UnitState.DEAD:
		return
	take_damage(_bleed_dps * 0.5, Vector2.ZERO, _bleed_source)

func _on_bleed_finished() -> void:
	_bleed_dps = 0.0
	_bleed_source = null
	if _bleed_tick_timer != null:
		_bleed_tick_timer.stop()

func get_ai_attack_range() -> float:
	if is_ranged_basic_attack():
		return get_basic_attack_range()
	return 50.0


func get_basic_attack_range() -> float:
	return basic_attack_range


func is_ranged_basic_attack() -> bool:
	return get_basic_attack_range() > 0.0


func get_basic_attack_kite_range() -> float:
	if basic_attack_kite_range >= 0.0:
		return basic_attack_kite_range
	return maxf(get_basic_attack_range() * 0.35, 40.0)

func ai_regenerate(amount: float) -> void:
	if state == UnitState.DEAD or amount <= 0.0:
		return
	var previous_hp := hp
	hp = minf(hp + amount, max_hp)
	if hp != previous_hp:
		health_changed.emit(hp, max_hp)

func get_ai_home_position() -> Vector2:
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm == null:
		return global_position
	return mm.ally_spawn_point if faction == &"ally" else mm.enemy_spawn_point

func update_facing(direction: Vector2) -> void:
	if direction.x > 0.0:
		facing_direction = 1
	elif direction.x < 0.0:
		facing_direction = -1

func die() -> void:
	if state == UnitState.DEAD:
		return
	state = UnitState.DEAD
	velocity = Vector2.ZERO
	died.emit(self)

func resolve_aim_direction(aim_position: Vector2) -> Vector2:
	if aim_position.is_finite():
		var to_target := aim_position - global_position
		if to_target.length_squared() > 0.0001:
			var aim_dir := to_target.normalized()
			update_facing(aim_dir)
			return aim_dir
	return Vector2(facing_direction, 0.0)


func perform_basic_attack(aim_position: Vector2 = Vector2.INF) -> bool:
	if is_match_over():
		return false
	if state in [UnitState.ATTACK, UnitState.CAST_SKILL, UnitState.STUNNED, UnitState.DEAD]:
		return false
	if basic_attack_scene == null and not is_ranged_basic_attack():
		return false
	if not attack_lock_timer.is_stopped():
		return false
	start_basic_attack_lock()
	var aim_dir := resolve_aim_direction(aim_position)
	attack_origin.position = aim_dir * 30.0
	if is_ranged_basic_attack():
		return _fire_basic_projectile(aim_dir)
	var hitbox: AttackHitbox = basic_attack_scene.instantiate()
	hitbox.source = self
	hitbox.direction = facing_direction
	hitbox.aim_direction = aim_dir
	hitbox.knockback_strength = 0.0
	hitbox.can_damage_towers = true
	hitbox.collision_layer = 8 if faction == &"ally" else 16
	hitbox.collision_mask = 36 if faction == &"ally" else 98
	hitbox.global_position = attack_origin.global_position
	get_tree().current_scene.add_child(hitbox)
	return true


func _fire_basic_projectile(aim_dir: Vector2) -> bool:
	var scene := basic_attack_projectile
	if scene == null:
		scene = preload("res://scenes/combat/projectiles/Projectile.tscn")
	var projectile: Projectile = scene.instantiate()
	projectile.source = self
	projectile.direction = aim_dir
	projectile.damage = get_attack()
	projectile.knockback_strength = 0.0
	projectile.can_damage_towers = true
	projectile.collision_layer = 8 if faction == &"ally" else 16
	projectile.collision_mask = 37 if faction == &"ally" else 99
	if self is Hero and (self as Hero).uses_seeking_basic_attack():
		var seek_target := BotTactics.pick_target(self, 9999.0) as Node2D
		if seek_target != null:
			projectile.seeking = true
			projectile.target_node = seek_target
			projectile.speed = SEEKING_BASIC_PROJECTILE_SPEED
			projectile.turn_speed = SEEKING_BASIC_PROJECTILE_TURN_SPEED
			projectile.direction = global_position.direction_to(seek_target.global_position)
	projectile.global_position = attack_origin.global_position
	get_tree().current_scene.add_child(projectile)
	return true

func start_basic_attack_lock() -> void:
	attack_lock_timer.start(attack_lock_duration)
	attack_started.emit()
	if can_attack_while_moving:
		return
	state = UnitState.ATTACK
	velocity = Vector2.ZERO

func _on_attack_lock_finished() -> void:
	if state == UnitState.ATTACK or state == UnitState.CAST_SKILL:
		state = UnitState.IDLE

func _physics_process(delta: float) -> void:
	if state == UnitState.STUNNED:
		velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		move_and_slide()
