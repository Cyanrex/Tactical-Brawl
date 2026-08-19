class_name WallaceKit
extends HeroKit


const DASH_HITBOX := preload("res://scenes/combat/hitboxes/DashHitbox.tscn")
const WHIP_SCENE := preload("res://scenes/combat/projectiles/BloodWhip.tscn")
const VORTEX_SCENE := preload("res://scenes/combat/hitboxes/VortexBarrage.tscn")

const DASH_SPEED := 950.0
const RECAST_WINDOW := 2.0
const TETHER_SNAP_MULTIPLIER := 9.0
const TETHER_SLOW_FACTOR := 0.4
const TETHER_SLOW_DURATION := 3.0
const TETHER_BONUS_MULTIPLIER := 1.2
const STANCE_DURATION := 1.0
const STANCE_CRIT_MULTIPLIER := 12.0
const BLEED_DPS_RATIO := 3.0
const BLEED_DURATION := 3.0
const VORTEX_HEAL_PER_HIT := 240.0
const VORTEX_CC_IMMUNE_DURATION := 4.0

var _recast_start: Vector2 = Vector2.ZERO
var _recast_active: bool = false
var _recast_timer: Timer = null
var _tether: BloodTether = null
var _stance_active: bool = false
var _stance_end_timer: Timer = null


func _init(owner_hero: Hero) -> void:
	super(owner_hero)
	_recast_timer = Timer.new()
	_recast_timer.one_shot = true
	_recast_timer.wait_time = RECAST_WINDOW
	_recast_timer.timeout.connect(_on_recast_expired)
	hero.add_child(_recast_timer)
	_stance_end_timer = Timer.new()
	_stance_end_timer.one_shot = true
	_stance_end_timer.wait_time = STANCE_DURATION
	_stance_end_timer.timeout.connect(_end_stance)
	hero.add_child(_stance_end_timer)
	hero.invulnerable_hit.connect(_on_counter_proc)


func cast_skill(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.DASH:
			_phase_dash(skill)
			return true
		SkillData.SkillType.TETHER:
			_blood_whip(skill, aim_position)
			return true
		SkillData.SkillType.COUNTER:
			_counter_stance()
			return true
		SkillData.SkillType.VORTEX:
			_blood_vortex(skill)
			return true
	return false


func try_recast(slot: int) -> bool:
	if slot == 1 and _recast_active:
		_blink_back()
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
	hitbox.damage_multiplier = TETHER_BONUS_MULTIPLIER if _has_active_tether() else 1.0
	hitbox.knockback_strength = 0.0
	hitbox.can_damage_towers = true
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 36 if hero.faction == &"ally" else 98
	hitbox.global_position = hero.attack_origin.global_position
	hero.get_tree().current_scene.add_child(hitbox)
	return true


func _phase_dash(skill: SkillData) -> void:
	_recast_active = false
	var dir := _dash_direction()
	hero.facing_direction = 1 if dir.x >= 0.0 else -1
	var dash_time := skill.range / DASH_SPEED
	_recast_start = hero.global_position
	hero.start_dash(dir.normalized(), DASH_SPEED, dash_time)
	var hitbox: AttackHitbox = DASH_HITBOX.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.aim_direction = dir.normalized()
	hitbox.damage_multiplier = skill.damage_multiplier
	hitbox.knockback_strength = skill.knockback
	hitbox.lifetime = dash_time + 0.1
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 36 if hero.faction == &"ally" else 98
	hitbox.hit_landed.connect(_on_dash_hit)
	hero.add_child(hitbox)


func _on_dash_hit(_target: Node, _damage: float) -> void:
	if _recast_active:
		return
	_recast_active = true
	_recast_timer.start()


func _on_recast_expired() -> void:
	_recast_active = false


func _blink_back() -> void:
	_recast_active = false
	_recast_timer.stop()
	hero.global_position = _recast_start
	hero.dash_remaining = 0.0
	hero.dash_velocity = Vector2.ZERO
	if hero.state == CombatUnit.UnitState.CAST_SKILL:
		hero.state = CombatUnit.UnitState.IDLE
	hero.attack_lock_timer.stop()


func _dash_direction() -> Vector2:
	if hero is PlayerHero:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			return input_dir
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		return hero.global_position.direction_to(target.global_position)
	return Vector2(hero.facing_direction, 0.0)


func _blood_whip(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	_clear_tether()
	var dir := _aim_direction(aim_position)
	hero.attack_origin.position = dir * 30.0
	var whip: Projectile = WHIP_SCENE.instantiate()
	whip.source = hero
	whip.direction = dir
	whip.damage = hero.get_attack() * skill.damage_multiplier
	whip.knockback_strength = skill.knockback
	whip.collision_layer = 8 if hero.faction == &"ally" else 16
	whip.collision_mask = 5 if hero.faction == &"ally" else 3
	whip.global_position = hero.attack_origin.global_position
	whip.projectile_hit.connect(_on_whip_hit)
	hero.get_tree().current_scene.add_child(whip)


func _on_whip_hit(target: Node) -> void:
	_clear_tether()
	if target == null or not target is Node2D:
		return
	if not is_instance_valid(target):
		return
	var tether := BloodTether.new()
	tether.hero = hero
	tether.target = target as Node2D
	var skill := hero.get_skill(2)
	tether.snap_range = skill.range if skill != null else 420.0
	tether.snap_damage_multiplier = TETHER_SNAP_MULTIPLIER
	tether.slow_factor = TETHER_SLOW_FACTOR
	tether.slow_duration = TETHER_SLOW_DURATION
	tether.duration = TETHER_SLOW_DURATION
	hero.get_tree().current_scene.add_child(tether)
	_tether = tether


func _clear_tether() -> void:
	if _tether != null and is_instance_valid(_tether):
		_tether.queue_free()
	_tether = null


func _has_active_tether() -> bool:
	return _tether != null and is_instance_valid(_tether)


func _counter_stance() -> void:
	_stance_active = true
	hero.invulnerable = true
	_stance_end_timer.start()


func _on_counter_proc(source: Node) -> void:
	if not _stance_active:
		return
	_stance_active = false
	hero.invulnerable = false
	_stance_end_timer.stop()
	var attacker := source as Node2D
	if attacker == null or not is_instance_valid(attacker):
		return
	var dir := hero.global_position.direction_to(attacker.global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2(hero.facing_direction, 0.0)
	hero.global_position = attacker.global_position + dir * 45.0
	hero.update_facing(-dir)
	if not attacker.has_method("take_damage"):
		return
	var crit := hero.get_attack() * STANCE_CRIT_MULTIPLIER
	if attacker is CombatUnit:
		(attacker as CombatUnit).take_damage(crit, -dir * 260.0, hero)
	else:
		attacker.take_damage(crit)
	if attacker.has_method("apply_bleed"):
		attacker.apply_bleed(hero.get_attack() * BLEED_DPS_RATIO, BLEED_DURATION, hero)


func _end_stance() -> void:
	_stance_active = false
	hero.invulnerable = false


func _blood_vortex(skill: SkillData) -> void:
	var vortex: VortexBarrage = VORTEX_SCENE.instantiate()
	vortex.source = hero
	vortex.slash_damage = hero.get_attack() * skill.damage_multiplier
	vortex.heal_per_hit = VORTEX_HEAL_PER_HIT
	vortex.radius = skill.range
	vortex.duration = skill.lifetime
	vortex.cc_immune_duration = VORTEX_CC_IMMUNE_DURATION
	hero.add_child(vortex)

func reset_respawn_effects() -> void:
	_recast_active = false
	_recast_start = Vector2.ZERO
	if _recast_timer != null:
		_recast_timer.stop()
	_clear_tether()
	_stance_active = false
	if _stance_end_timer != null:
		_stance_end_timer.stop()


func _aim_direction(aim_position: Vector2) -> Vector2:
	if aim_position.is_finite():
		var to_target := aim_position - hero.global_position
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		return hero.global_position.direction_to(target.global_position)
	return Vector2(hero.facing_direction, 0.0)
