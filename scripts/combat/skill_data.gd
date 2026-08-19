@tool
class_name SkillData
extends Resource

enum SkillType {
	MELEE,
	PROJECTILE,
	AOE_SELF,
	SUMMON,
	SEEKING,
	CLONE,
	REVIVE,
	DASH,
	AOE_SLOW,
	BUFF,
	AURA,
	TETHER,
	COUNTER,
	VORTEX,
	LINE,
	TRAP,
	STEALTH,
	DOMAIN,
	BOUNCE,
	MINE,
	RECOIL,
	GRAND_BOMB,
	BARRAGE,
	WHIRL,
	EXECUTE,
	TOGGLE,
	VOID_BALL
}

@export var skill_name: StringName = &"Skill"
@export var skill_type: SkillType = SkillType.MELEE
@export var unlock_level: int = 1
@export var cooldown: float = 5.0
@export var cast_time: float = 0.0
@export var damage_multiplier: float = 1.5
@export var range: float = 80.0
@export var knockback: float = 120.0
@export var lifetime: float = 0.25
@export var hitbox_scene: PackedScene
@export var projectile_scene: PackedScene
@export var animation_name: StringName = &"skill"
