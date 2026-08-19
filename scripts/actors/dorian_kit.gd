class_name DorianKit
extends HeroKit


const DASH_HITBOX := preload("res://scenes/combat/hitboxes/DashHitbox.tscn")
const BASIC_HITBOX := preload("res://scenes/combat/hitboxes/BasicAttackHitbox.tscn")
const AURA_SCENE := preload("res://scenes/combat/hitboxes/TideAura.tscn")

const DASH_SPEED := 950.0
const SLOW_FACTOR := 0.7
const SLOW_DURATION := 3.0
const AURA_SLOW_FACTOR := 0.4
const AURA_SLOW_DURATION := 1.0
const AURA_TICK_INTERVAL := 0.5
const AURA_DAMAGE_PER_TICK := 1.32
const BUFF_ATTACK_MULTIPLIER := 1.5
const BUFF_LIFESTEAL := 0.3
const BUFF_DURATION := 6.0
const BUFF_COLOR := Color(0.1, 0.7, 0.75)

var _original_body_color: Color = Color.WHITE
var _color_captured: bool = false
var _buff_timer: Timer = null

func cast_skill(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.DASH:
			_dash(skill)
			return true
		SkillData.SkillType.AOE_SLOW:
			_crushing_wave(skill, aim_position)
			return true
		SkillData.SkillType.BUFF:
			_raging_tide(skill)
			return true
		SkillData.SkillType.AURA:
			_maelstrom(skill)
			return true
	return false

func _dash(skill: SkillData) -> void:
	var dir := _dash_direction()
	hero.facing_direction = 1 if dir.x >= 0.0 else -1
	var dash_time := skill.range / DASH_SPEED
	hero.start_dash(dir.normalized(), DASH_SPEED, dash_time)
	var hitbox: AttackHitbox = DASH_HITBOX.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.aim_direction = dir.normalized()
	hitbox.damage_multiplier = skill.damage_multiplier
	hitbox.knockback_strength = skill.knockback
	hitbox.lifetime = dash_time + 0.1
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 4 if hero.faction == &"ally" else 2
	hero.add_child(hitbox)

func _dash_direction() -> Vector2:
	if hero is PlayerHero:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			return input_dir
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		return hero.global_position.direction_to(target.global_position)
	return Vector2(hero.facing_direction, 0.0)

func _crushing_wave(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	var hitbox: AttackHitbox = BASIC_HITBOX.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.aim_direction = hero.resolve_aim_direction(aim_position)
	hitbox.damage_multiplier = skill.damage_multiplier
	hitbox.knockback_strength = skill.knockback
	hitbox.lifetime = skill.lifetime
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 4 if hero.faction == &"ally" else 2
	hitbox.scale = Vector2(skill.range / 40.0, skill.range / 40.0)
	hitbox.hit_landed.connect(_apply_slow)
	hitbox.global_position = hero.global_position
	hero.get_tree().current_scene.add_child(hitbox)

func _apply_slow(target: Node, _damage: float) -> void:
	if target.has_method("apply_slow"):
		target.apply_slow(SLOW_FACTOR, SLOW_DURATION)

func _raging_tide(_skill: SkillData) -> void:
	hero.buff_attack_multiplier = BUFF_ATTACK_MULTIPLIER
	hero.lifesteal_fraction = BUFF_LIFESTEAL
	var body := hero.get_node_or_null("Body") as Polygon2D
	if body != null:
		if not _color_captured:
			_original_body_color = body.color
			_color_captured = true
		body.color = BUFF_COLOR
	if _buff_timer == null:
		_buff_timer = Timer.new()
		_buff_timer.one_shot = true
		_buff_timer.wait_time = BUFF_DURATION
		_buff_timer.timeout.connect(_end_raging_tide)
		hero.add_child(_buff_timer)
	_buff_timer.start()

func _end_raging_tide() -> void:
	hero.buff_attack_multiplier = 1.0
	hero.lifesteal_fraction = 0.0
	var body := hero.get_node_or_null("Body") as Polygon2D
	if body != null and is_instance_valid(body):
		body.color = _original_body_color
	_color_captured = false

func reset_respawn_effects() -> void:
	if _buff_timer != null:
		_buff_timer.stop()
	_end_raging_tide()

func _maelstrom(skill: SkillData) -> void:
	var aura: ZhalrethAura = AURA_SCENE.instantiate()
	aura.source = hero
	aura.damage_per_tick = hero.get_attack() * AURA_DAMAGE_PER_TICK
	aura.slow_factor = AURA_SLOW_FACTOR
	aura.slow_duration = AURA_SLOW_DURATION
	aura.tick_interval = AURA_TICK_INTERVAL
	aura.duration = skill.lifetime
	aura.radius = skill.range
	hero.add_child(aura)
