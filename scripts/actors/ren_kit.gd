class_name RenKit
extends HeroKit


const SPIKE_SCENE := preload("res://scenes/combat/projectiles/ShadowSpike.tscn")
const SNARE_SCENE := preload("res://scenes/combat/hitboxes/ShadeSnare.tscn")
const THEATER_SCENE := preload("res://scenes/combat/hitboxes/BlackTheater.tscn")

const SPIKE_SPEED := 700.0
const SPIKE_ROOT_DURATION := 1.2
const SNARE_TRIGGER_RADIUS := 42.0
const SNARE_PULL_RADIUS := 130.0
const SNARE_ROOT_DURATION := 1.2
const STEALTH_DURATION := 4.0
const STEALTH_SPEED_MULTIPLIER := 1.45
const STEALTH_ALPHA := 0.15
const EMPOWER_MULTIPLIER := 8.0
const THEATER_SLOW_FACTOR := 0.35
const THEATER_SLOW_DURATION := 1.0
const THEATER_CLONE_COUNT := 3
const THEATER_CLONE_DAMAGE_RATIO := 2.4
const THEATER_ATTACK_BONUS := 0.5

var _stealth_active: bool = false
var _empowered: bool = false
var _stealth_timer: Timer = null
var _body: Polygon2D = null
var _original_alpha: float = 1.0


func _init(owner_hero: Hero) -> void:
	super(owner_hero)
	_stealth_timer = Timer.new()
	_stealth_timer.one_shot = true
	_stealth_timer.wait_time = STEALTH_DURATION
	_stealth_timer.timeout.connect(_end_stealth)
	hero.add_child(_stealth_timer)
	_body = hero.get_node_or_null("Body") as Polygon2D
	if _body != null:
		_original_alpha = _body.color.a
	hero.died.connect(_on_hero_died)


func cast_skill(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.LINE:
			_shadow_spike(skill, aim_position)
			return true
		SkillData.SkillType.TRAP:
			_shade_snare(skill, aim_position)
			return true
		SkillData.SkillType.STEALTH:
			_shadow_step()
			return true
		SkillData.SkillType.DOMAIN:
			_black_theater(skill)
			return true
	return false


func perform_basic_attack(aim_position: Vector2 = Vector2.INF) -> bool:
	if hero.is_match_over():
		return false
	if hero.state in [CombatUnit.UnitState.ATTACK, CombatUnit.UnitState.CAST_SKILL, CombatUnit.UnitState.STUNNED, CombatUnit.UnitState.DEAD]:
		return false
	if hero.basic_attack_scene == null:
		return false
	if not hero.attack_lock_timer.is_stopped():
		return false
	hero.start_basic_attack_lock()
	var aim_dir := hero.resolve_aim_direction(aim_position)
	hero.attack_origin.position = aim_dir * 30.0
	var hitbox: AttackHitbox = hero.basic_attack_scene.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.aim_direction = aim_dir
	hitbox.damage_multiplier = EMPOWER_MULTIPLIER if _empowered else 1.0
	hitbox.knockback_strength = 0.0
	hitbox.can_damage_towers = true
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 36 if hero.faction == &"ally" else 98
	hitbox.global_position = hero.attack_origin.global_position
	hero.get_tree().current_scene.add_child(hitbox)
	if _empowered:
		_empowered = false
		if _stealth_active:
			_end_stealth()
	return true


func _shadow_spike(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	var dir := _aim_direction(aim_position)
	hero.facing_direction = 1 if dir.x >= 0.0 else -1
	hero.attack_origin.position = dir * 30.0
	var spike: ShadowSpike = SPIKE_SCENE.instantiate()
	spike.source = hero
	spike.direction = dir
	spike.damage = hero.get_attack() * skill.damage_multiplier
	spike.knockback_strength = skill.knockback
	spike.speed = SPIKE_SPEED
	spike.root_duration = SPIKE_ROOT_DURATION
	spike.collision_layer = 8 if hero.faction == &"ally" else 16
	spike.collision_mask = 5 if hero.faction == &"ally" else 3
	spike.global_position = hero.attack_origin.global_position
	hero.get_tree().current_scene.add_child(spike)


func _shade_snare(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	var snare: ShadeSnare = SNARE_SCENE.instantiate()
	snare.source = hero
	snare.trigger_radius = SNARE_TRIGGER_RADIUS
	snare.pull_radius = SNARE_PULL_RADIUS
	snare.damage_multiplier = skill.damage_multiplier
	snare.root_duration = SNARE_ROOT_DURATION
	snare.lifetime = skill.lifetime
	snare.global_position = _snare_position(aim_position, skill.range)
	hero.get_tree().current_scene.add_child(snare)


func _snare_position(aim_position: Vector2, max_range: float) -> Vector2:
	if aim_position.is_finite():
		var offset := aim_position - hero.global_position
		if offset.length_squared() > 0.0001:
			return hero.global_position + offset.limit_length(max_range)
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		var to_target := target.global_position - hero.global_position
		if to_target.length_squared() > 0.0001:
			return target.global_position
	return hero.global_position + Vector2(hero.facing_direction, 0.0) * max_range


func _shadow_step() -> void:
	_stealth_active = true
	_empowered = true
	hero.move_speed_buff_multiplier = STEALTH_SPEED_MULTIPLIER
	if _body != null and is_instance_valid(_body):
		_body.color.a = STEALTH_ALPHA
	_stealth_timer.start()


func _end_stealth() -> void:
	if not _stealth_active:
		return
	_stealth_active = false
	hero.move_speed_buff_multiplier = 1.0
	if _body != null and is_instance_valid(_body):
		_body.color.a = _original_alpha
	_stealth_timer.stop()

func reset_respawn_effects() -> void:
	_empowered = false
	_stealth_active = false
	if _stealth_timer != null:
		_stealth_timer.stop()
	if _body != null and is_instance_valid(_body):
		_body.color.a = _original_alpha


func _on_hero_died(_unit: CombatUnit) -> void:
	_empowered = false
	if _stealth_active:
		_end_stealth()


func _black_theater(skill: SkillData) -> void:
	var theater: BlackTheater = THEATER_SCENE.instantiate()
	theater.source = hero
	theater.radius = skill.range
	theater.duration = skill.lifetime
	theater.slow_factor = THEATER_SLOW_FACTOR
	theater.slow_duration = THEATER_SLOW_DURATION
	theater.clone_count = THEATER_CLONE_COUNT
	theater.clone_damage_ratio = THEATER_CLONE_DAMAGE_RATIO
	theater.attack_bonus = THEATER_ATTACK_BONUS
	hero.add_child(theater)


func _aim_direction(aim_position: Vector2) -> Vector2:
	if aim_position.is_finite():
		var to_target := aim_position - hero.global_position
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		return hero.global_position.direction_to(target.global_position)
	return Vector2(hero.facing_direction, 0.0)
