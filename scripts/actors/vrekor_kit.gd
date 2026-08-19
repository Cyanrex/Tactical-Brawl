class_name VrekorKit
extends HeroKit


const BOUNCY_BOMB := preload("res://scenes/combat/projectiles/BouncyBomb.tscn")
const MINE_SCENE := preload("res://scenes/combat/hitboxes/BlastMine.tscn")
const GRAND_BOMB := preload("res://scenes/combat/projectiles/GrandBomb.tscn")
const BASIC_HITBOX := preload("res://scenes/combat/hitboxes/BasicAttackHitbox.tscn")

const BOUNCE_COUNT := 3
const BOUNCE_SPREAD_DEG := 24.0
const BOUNCE_SPEED := 320.0
const BOUNCE_ACCELERATION := 200.0
const BOUNCE_MAX_SPEED := 900.0
const BOUNCE_BLAST_RADIUS := 120.0
const MINE_COUNT := 4
const MINE_BLAST_RADIUS := 70.0
const MINE_OFFSETS := [Vector2(40.0, -20.0), Vector2(70.0, 0.0), Vector2(40.0, 20.0), Vector2(95.0, 0.0)]
const KICK_HITBOX_RADIUS := 110.0
const KICK_DASH_SPEED := 900.0
const GRAND_SPEED := 110.0
const GRAND_KNOCKBACK := 420.0

var _grand_bomb: GrandBomb = null


func cast_skill(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.BOUNCE:
			_bouncy_bomb(skill, aim_position)
			return true
		SkillData.SkillType.MINE:
			_minefield(skill)
			return true
		SkillData.SkillType.RECOIL:
			_rocket_kick(skill, aim_position)
			return true
		SkillData.SkillType.GRAND_BOMB:
			_grand_finale(skill, aim_position)
			return true
	return false


func try_recast(slot: int) -> bool:
	if slot == 4 and _grand_bomb != null and is_instance_valid(_grand_bomb):
		_grand_bomb.detonate_early()
		return true
	return false


func _bouncy_bomb(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	var aim_dir := _aim_direction(aim_position)
	hero.facing_direction = 1 if aim_dir.x >= 0.0 else -1
	hero.attack_origin.position = aim_dir * 30.0
	for i in BOUNCE_COUNT:
		var angle := deg_to_rad((float(i) - float(BOUNCE_COUNT - 1) / 2.0) * BOUNCE_SPREAD_DEG)
		var dir := aim_dir.rotated(angle)
		var bomb: BouncyBomb = BOUNCY_BOMB.instantiate()
		bomb.source = hero
		bomb.direction = dir
		bomb.speed = BOUNCE_SPEED
		bomb.acceleration = BOUNCE_ACCELERATION
		bomb.max_speed = BOUNCE_MAX_SPEED
		bomb.damage_multiplier = skill.damage_multiplier
		bomb.blast_radius = BOUNCE_BLAST_RADIUS
		bomb.knockback_strength = skill.knockback
		bomb.global_position = hero.attack_origin.global_position
		hero.get_tree().current_scene.add_child(bomb)


func _minefield(skill: SkillData) -> void:
	for i in MINE_COUNT:
		var offset: Vector2 = MINE_OFFSETS[i % MINE_OFFSETS.size()]
		var mine: BlastMine = MINE_SCENE.instantiate()
		mine.source = hero
		mine.damage_multiplier = skill.damage_multiplier
		mine.knockback_strength = skill.knockback
		mine.blast_radius = MINE_BLAST_RADIUS
		mine.lifetime = skill.lifetime
		mine.global_position = hero.global_position + Vector2(offset.x * hero.facing_direction, offset.y)
		hero.get_tree().current_scene.add_child(mine)


func _rocket_kick(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	var dir := _aim_direction(aim_position)
	hero.facing_direction = 1 if dir.x >= 0.0 else -1
	var hitbox: AttackHitbox = BASIC_HITBOX.instantiate()
	hitbox.source = hero
	hitbox.direction = hero.facing_direction
	hitbox.aim_direction = dir
	hitbox.damage_multiplier = skill.damage_multiplier
	hitbox.knockback_strength = skill.knockback
	hitbox.lifetime = skill.lifetime
	hitbox.collision_layer = 8 if hero.faction == &"ally" else 16
	hitbox.collision_mask = 4 if hero.faction == &"ally" else 2
	hitbox.scale = Vector2(KICK_HITBOX_RADIUS / 40.0, KICK_HITBOX_RADIUS / 40.0)
	hitbox.global_position = hero.global_position + dir * 55.0
	hero.get_tree().current_scene.add_child(hitbox)
	var dash_time := skill.range / KICK_DASH_SPEED
	hero.start_dash(-dir, KICK_DASH_SPEED, dash_time)


func _grand_finale(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	var dir := _aim_direction(aim_position)
	hero.facing_direction = 1 if dir.x >= 0.0 else -1
	var bomb: GrandBomb = GRAND_BOMB.instantiate()
	bomb.source = hero
	bomb.direction = dir
	bomb.speed = GRAND_SPEED
	bomb.travel_time = skill.lifetime
	bomb.damage_multiplier = skill.damage_multiplier
	bomb.blast_radius = skill.range
	bomb.knockback_strength = GRAND_KNOCKBACK
	bomb.detonated.connect(_on_bomb_detonated)
	bomb.global_position = hero.global_position + dir * 40.0
	hero.get_tree().current_scene.add_child(bomb)
	_grand_bomb = bomb


func _on_bomb_detonated() -> void:
	_grand_bomb = null

func reset_respawn_effects() -> void:
	if _grand_bomb != null and is_instance_valid(_grand_bomb):
		_grand_bomb.queue_free()
	_grand_bomb = null


func _aim_direction(aim_position: Vector2) -> Vector2:
	if aim_position.is_finite():
		var to_target := aim_position - hero.global_position
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		return hero.global_position.direction_to(target.global_position)
	return Vector2(hero.facing_direction, 0.0)
