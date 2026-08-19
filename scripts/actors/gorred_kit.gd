class_name GorredKit
extends HeroKit


const BASIC_HITBOX := preload("res://scenes/combat/hitboxes/BasicAttackHitbox.tscn")
const CHAIN_SCENE := preload("res://scenes/combat/hitboxes/GorredChain.tscn")
const WHIRLWIND_SCENE := preload("res://scenes/combat/hitboxes/GorredWhirlwind.tscn")

const SLASH_COUNT := 10
const BLEED_DPS_RATIO := 0.2
const BLEED_DURATION := 10.0
const FRENZY_ATTACK_MULTIPLIER := 1.35
const FRENZY_SPEED_MULTIPLIER := 1.4
const FRENZY_COLOR := Color(1.0, 0.45, 0.2)
const ULT_STRIKE_RADIUS := 60.0
const ULT_LAND_OFFSET := 35.0
const ULT_KILL_BONUS := 0.2
const ULT_BONUS_CAP := 0.8

var _original_body_color: Color = Color.WHITE
var _color_captured: bool = false
var _buff_timer: Timer = null
var _ult_bonus: float = 0.0
var _ult_target: Node = null


func _init(owner_hero: Hero) -> void:
	super(owner_hero)
	var body := hero.get_node_or_null("Body") as Polygon2D
	if body != null:
		_original_body_color = body.color
	hero.died.connect(_on_hero_died)


func cast_skill(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.BARRAGE:
			_blood_flurry(skill, aim_position)
			return true
		SkillData.SkillType.WHIRL:
			_whirlwind(skill)
			return true
		SkillData.SkillType.BUFF:
			_frenzy(skill)
			return true
		SkillData.SkillType.EXECUTE:
			_blood_hunt(skill)
			return true
	return false


func _blood_flurry(skill: SkillData, _aim_position: Vector2 = Vector2.INF) -> void:
	var chain: GorredChain = CHAIN_SCENE.instantiate()
	chain.source = hero
	chain.max_chains = SLASH_COUNT
	chain.chain_range = skill.range
	chain.strike_damage = hero.get_attack() * skill.damage_multiplier / SLASH_COUNT
	chain.bleed_dps_ratio = BLEED_DPS_RATIO
	chain.bleed_duration = BLEED_DURATION
	chain.finished.connect(_on_chain_finished)
	hero.add_child(chain)


func _on_chain_finished(ended_early: bool) -> void:
	if not ended_early:
		return
	var timer := hero.get_skill_timer(1)
	if timer == null or timer.is_stopped():
		return
	var remaining := timer.time_left
	timer.stop()
	timer.start(remaining * 0.5)


func _whirlwind(skill: SkillData) -> void:
	var whirlwind: GorredWhirlwind = WHIRLWIND_SCENE.instantiate()
	whirlwind.source = hero
	whirlwind.tick_damage = hero.get_attack() * skill.damage_multiplier
	whirlwind.radius = skill.range
	whirlwind.duration = skill.lifetime
	hero.add_child(whirlwind)


func _frenzy(skill: SkillData) -> void:
	hero.buff_attack_multiplier = FRENZY_ATTACK_MULTIPLIER
	hero.move_speed_buff_multiplier = FRENZY_SPEED_MULTIPLIER
	var body := hero.get_node_or_null("Body") as Polygon2D
	if body != null:
		if not _color_captured:
			_original_body_color = body.color
			_color_captured = true
		body.color = FRENZY_COLOR
	if _buff_timer == null:
		_buff_timer = Timer.new()
		_buff_timer.one_shot = true
		_buff_timer.timeout.connect(_end_frenzy)
		hero.add_child(_buff_timer)
	_buff_timer.start(skill.lifetime)


func _end_frenzy() -> void:
	hero.buff_attack_multiplier = 1.0
	hero.move_speed_buff_multiplier = 1.0
	var body := hero.get_node_or_null("Body") as Polygon2D
	if body != null and is_instance_valid(body):
		body.color = _original_body_color
	_color_captured = false


func _blood_hunt(skill: SkillData) -> void:
	var target := _ult_target_candidate(skill.range)
	if target == null:
		var timer := hero.get_skill_timer(4)
		if timer != null and not timer.is_stopped():
			timer.stop()
		return
	_track_ult_target(target)
	var dir := hero.global_position.direction_to(target.global_position)
	if dir.length_squared() < 0.0001:
		dir = Vector2(hero.facing_direction, 0.0)
	hero.global_position = target.global_position - dir * ULT_LAND_OFFSET
	hero.update_facing(dir)
	var hitbox: AttackHitbox = BASIC_HITBOX.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.aim_direction = dir
	hitbox.damage_multiplier = skill.damage_multiplier * (1.0 + _ult_bonus)
	hitbox.knockback_strength = skill.knockback
	hitbox.lifetime = skill.lifetime
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 4 if hero.faction == &"ally" else 2
	hitbox.scale = Vector2(ULT_STRIKE_RADIUS / 40.0, ULT_STRIKE_RADIUS / 40.0)
	hitbox.global_position = target.global_position
	hero.get_tree().current_scene.add_child(hitbox)


func _ult_target_candidate(max_range: float) -> Node:
	for group in [&"heroes", &"troops"]:
		var candidate := BotTactics.nearest_enemy_of_type(hero, group, max_range)
		if candidate != null:
			return candidate
	return null


func _track_ult_target(target: Node) -> void:
	if _ult_target != null and is_instance_valid(_ult_target):
		if _ult_target.died.is_connected(_on_ult_target_died):
			_ult_target.died.disconnect(_on_ult_target_died)
	_ult_target = target
	if target != null and is_instance_valid(target):
		if not target.died.is_connected(_on_ult_target_died):
			target.died.connect(_on_ult_target_died)


func _on_ult_target_died(unit: Node) -> void:
	if unit != null and is_instance_valid(unit):
		if unit.died.is_connected(_on_ult_target_died):
			unit.died.disconnect(_on_ult_target_died)
	_ult_target = null
	_ult_bonus = minf(_ult_bonus + ULT_KILL_BONUS, ULT_BONUS_CAP)
	var timer := hero.get_skill_timer(4)
	if timer != null and not timer.is_stopped():
		timer.stop()


func _on_hero_died(_unit: CombatUnit) -> void:
	_ult_bonus = 0.0
	if _ult_target != null and is_instance_valid(_ult_target):
		if _ult_target.died.is_connected(_on_ult_target_died):
			_ult_target.died.disconnect(_on_ult_target_died)
	_ult_target = null

func reset_respawn_effects() -> void:
	if _buff_timer != null:
		_buff_timer.stop()
	_end_frenzy()
	_ult_bonus = 0.0
	if _ult_target != null and is_instance_valid(_ult_target):
		if _ult_target.died.is_connected(_on_ult_target_died):
			_ult_target.died.disconnect(_on_ult_target_died)
	_ult_target = null
