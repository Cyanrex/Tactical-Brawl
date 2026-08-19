class_name HeroKit
extends RefCounted

var hero: Hero

func _init(owner_hero: Hero) -> void:
	hero = owner_hero

func cast_skill(_skill: SkillData, _aim_position: Vector2 = Vector2.INF) -> bool:
	return false

func ai_manage_toggles() -> void:
	pass

func try_recast(_slot: int) -> bool:
	return false

func perform_basic_attack(_aim_position: Vector2 = Vector2.INF) -> bool:
	return false

func reset_respawn_effects() -> void:
	pass
