class_name Hero
extends CombatUnit

const ROLE_FIGHTER_TANK := 0
const ROLE_ASSASSIN := 1
const ROLE_MAGE := 2
const ROLE_SUPPORT := 3
const DEFAULT_RANGED_BASIC_ATTACK_RANGE := 300.0
const HERO_SPRITE_PATHS := {
	"Kael": "res://resources/assets/kael/kael.png",
	"Lorvath": "res://resources/assets/lorvath/lorvath.png",
	"Zhalreth": "res://resources/assets/zhalreth/zhalreth.png",
	"Wallace": "res://resources/assets/wallace/wallace.png",
	"Ren": "res://resources/assets/ren/ren.png",
	"Vrekor": "res://resources/assets/vrekor/vrekor.png",
	"Nyxara": "res://resources/assets/nyxana/nyxana.png",
	"Dorian": "res://resources/assets/dorian/dorian.png",
	"Gorred": "res://resources/assets/gorred/gorred.png",
}

@export_enum("Fighter/Tank", "Assassin", "Mage", "Support") var role: int = ROLE_FIGHTER_TANK
@export var close_range_basic_attack: bool = false

signal leveled_up(new_level: int)
signal exp_changed(current_exp: float, required_exp: float, current_level: int)
signal stats_changed(kills: int, deaths: int, minion_kills: int)

@export var exp_to_next_level: int = 100
@export var max_level: int = 6
@export var hp_per_level: float = 2500.0
@export var attack_per_level: float = 25.0
@export var skill_1: SkillData
@export var skill_2: SkillData
@export var skill_3: SkillData
@export var ultimate: SkillData

@export var ai_cast_ranges: Array[float] = []

var cooldown_reduction_fraction: float = 0.0

@export var kit_script: Script

var kill_count: int = 0
var death_count: int = 0
var minion_kill_count: int = 0
var _kit: HeroKit = null

func _init() -> void:
	can_attack_while_moving = true

func is_ranged_basic_attack() -> bool:
	if close_range_basic_attack:
		return false
	if role in [ROLE_MAGE, ROLE_SUPPORT]:
		return true
	return super.is_ranged_basic_attack()

func get_basic_attack_range() -> float:
	if basic_attack_range > 0.0:
		return basic_attack_range
	if not close_range_basic_attack and role in [ROLE_MAGE, ROLE_SUPPORT]:
		return DEFAULT_RANGED_BASIC_ATTACK_RANGE
	return basic_attack_range

func uses_seeking_basic_attack() -> bool:
	return is_ranged_basic_attack() and role in [ROLE_MAGE, ROLE_SUPPORT]

var dash_velocity: Vector2 = Vector2.ZERO
var dash_remaining: float = 0.0

func start_dash(direction: Vector2, speed: float, duration: float) -> void:
	dash_velocity = direction * speed
	dash_remaining = duration

@onready var skill_1_timer: Timer = $Skill1Timer
@onready var skill_2_timer: Timer = $Skill2Timer
@onready var skill_3_timer: Timer = $Skill3Timer
@onready var ultimate_timer: Timer = $UltimateTimer

func _ready() -> void:
	super._ready()
	add_to_group("heroes")
	_setup_character_sprite()
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.register_hero(self)
	if kit_script != null:
		_kit = kit_script.new(self)

func _setup_character_sprite() -> void:
	if has_node("KaelSprite") or has_node("HeroSprite"):
		return
	var hero_name := String(name)
	if hero_name.begins_with("Player"):
		hero_name = hero_name.trim_prefix("Player")
	elif hero_name.begins_with("Enemy"):
		hero_name = hero_name.trim_prefix("Enemy")
	var texture_path: String = HERO_SPRITE_PATHS.get(hero_name, "")
	if texture_path.is_empty():
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var body := get_node_or_null("Body") as Polygon2D
	if body != null:
		body.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "HeroSprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.1, 2.1)
	if hero_name == "Kael":
		sprite.vframes = 2
	add_child(sprite)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "HeroSpriteAnimation"
	add_child(animation_player)
	var animation := Animation.new()
	animation.length = 4.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, NodePath("HeroSprite:position"))
	animation.track_set_interpolation_type(position_track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(position_track, 0.0, Vector2(-10.0, 0.0))
	animation.track_insert_key(position_track, 2.0, Vector2(10.0, 0.0))
	animation.track_insert_key(position_track, 4.0, Vector2(-10.0, 0.0))
	var flip_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(flip_track, NodePath("HeroSprite:flip_h"))
	animation.track_set_interpolation_type(flip_track, Animation.INTERPOLATION_NEAREST)
	animation.track_insert_key(flip_track, 0.0, true)
	animation.track_insert_key(flip_track, 2.0, false)
	animation.track_insert_key(flip_track, 4.0, true)
	var library := AnimationLibrary.new()
	library.add_animation(&"walk_back_and_forth", animation)
	animation_player.add_animation_library(&"", library)
	animation_player.play(&"walk_back_and_forth")

func perform_basic_attack(aim_position: Vector2 = Vector2.INF) -> bool:
	if uses_seeking_basic_attack():
		return super.perform_basic_attack(aim_position)
	if _kit != null and _kit.perform_basic_attack(aim_position):
		return true
	return super.perform_basic_attack(aim_position)

func ai_manage_toggles() -> void:
	if _kit != null:
		_kit.ai_manage_toggles()

func reset_respawn_effects() -> void:
	if _kit != null:
		_kit.reset_respawn_effects()
	super.reset_respawn_effects()
	cooldown_reduction_fraction = 0.0

func get_skill(slot: int) -> SkillData:
	match slot:
		1:
			return skill_1
		2:
			return skill_2
		3:
			return skill_3
		4:
			return ultimate
	return null

func register_kill(victim: CombatUnit = null) -> void:
	if victim is Troop:
		minion_kill_count += 1
	elif victim is Hero:
		kill_count += 1
	stats_changed.emit(kill_count, death_count, minion_kill_count)

func register_death() -> void:
	death_count += 1
	stats_changed.emit(kill_count, death_count, minion_kill_count)

func get_ai_cast_range(slot: int, fallback: float) -> float:
	if ai_cast_ranges.is_empty():
		return fallback
	var idx := slot - 1
	if idx < 0 or idx >= ai_cast_ranges.size():
		return fallback
	return ai_cast_ranges[idx]

func get_skill_timer(slot: int) -> Timer:
	match slot:
		1:
			return skill_1_timer
		2:
			return skill_2_timer
		3:
			return skill_3_timer
		4:
			return ultimate_timer
	return null

func try_use_skill(slot: int, aim_position: Vector2 = Vector2.INF) -> bool:
	var skill := get_skill(slot)
	if skill == null:
		return false
	if is_match_over() or state == UnitState.DEAD:
		return false
	if _kit != null and _kit.try_recast(slot):
		return true
	if level < skill.unlock_level:
		return false
	if state in [UnitState.ATTACK, UnitState.CAST_SKILL, UnitState.STUNNED, UnitState.DEAD]:
		return false
	var timer := get_skill_timer(slot)
	if timer == null or not timer.is_stopped():
		return false
	state = UnitState.CAST_SKILL
	velocity = Vector2.ZERO
	attack_lock_timer.start(maxf(skill.cast_time, attack_lock_duration))
	timer.start(maxf(skill.cooldown * (1.0 - cooldown_reduction_fraction), 0.05))
	skill_used.emit(skill.skill_name)
	_cast_skill(skill, aim_position)
	return true

func _cast_skill(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	if _kit != null and _kit.cast_skill(skill, aim_position):
		return
	match skill.skill_type:
		SkillData.SkillType.MELEE:
			var aim_dir := resolve_aim_direction(aim_position)
			attack_origin.position = aim_dir * 30.0
			_spawn_skill_hitbox(skill, attack_origin.global_position, skill.range, aim_dir)
		SkillData.SkillType.AOE_SELF:
			_spawn_skill_hitbox(skill, global_position, skill.range, Vector2.ZERO)
		SkillData.SkillType.PROJECTILE:
			_spawn_projectile(skill, aim_position)

func _spawn_skill_hitbox(skill: SkillData, at: Vector2, size: float, aim_dir: Vector2 = Vector2.ZERO) -> void:
	if skill.hitbox_scene == null:
		return
	var hitbox: AttackHitbox = skill.hitbox_scene.instantiate()
	hitbox.source = self
	hitbox.direction = facing_direction
	hitbox.aim_direction = aim_dir
	hitbox.damage_multiplier = skill.damage_multiplier
	hitbox.knockback_strength = skill.knockback
	hitbox.lifetime = skill.lifetime
	hitbox.collision_layer = 8 if faction == &"ally" else 16
	hitbox.collision_mask = 4 if faction == &"ally" else 2
	hitbox.scale = Vector2(size / 40.0, size / 40.0)
	hitbox.global_position = at
	get_tree().current_scene.add_child(hitbox)

func _spawn_projectile(skill: SkillData, aim_position: Vector2 = Vector2.INF) -> void:
	if skill.projectile_scene == null:
		return
	var aim_dir := resolve_aim_direction(aim_position)
	attack_origin.position = aim_dir * 30.0
	var projectile: Projectile = skill.projectile_scene.instantiate()
	projectile.source = self
	projectile.direction = aim_dir
	projectile.damage = get_attack() * skill.damage_multiplier
	projectile.knockback_strength = skill.knockback
	projectile.collision_layer = 8 if faction == &"ally" else 16
	projectile.collision_mask = 5 if faction == &"ally" else 3
	projectile.global_position = attack_origin.global_position
	get_tree().current_scene.add_child(projectile)

func add_exp(amount: float) -> void:
	if amount <= 0.0:
		return
	if level >= max_level:
		exp = 0.0
		exp_changed.emit(exp, exp_required_for_next_level(), level)
		return
	exp += amount
	while level < max_level:
		var required := exp_required_for_next_level()
		if exp < required:
			break
		exp -= required
		level_up()
	if level >= max_level:
		exp = 0.0
	exp_changed.emit(exp, exp_required_for_next_level(), level)

func exp_required_for_next_level() -> float:
	if level >= max_level:
		return 0.0
	return 100.0 * level

func level_up() -> void:
	if level >= max_level:
		return
	level += 1
	max_hp += hp_per_level
	attack += attack_per_level
	hp = minf(hp + hp_per_level, max_hp)
	health_changed.emit(hp, max_hp)
	leveled_up.emit(level)
