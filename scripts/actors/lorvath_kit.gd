class_name LorvathKit
extends HeroKit

const SEEKER_SCENE := preload("res://scenes/combat/projectiles/SkullSeeker.tscn")
const CLONE_SCENE := preload("res://scenes/actors/troops/CloneUnit.tscn")
const RAISE_COUNT := 4
const REVIVE_COST_RATIO := 0.7
const RAISE_OFFSETS := [Vector2(-45.0, -35.0), Vector2(-45.0, 15.0), Vector2(45.0, -35.0), Vector2(45.0, 15.0)]
func cast_skill(skill: SkillData, _aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.SUMMON:
			_raise_minions()
			return true
		SkillData.SkillType.SEEKING:
			_launch_seekers(skill)
			return true
		SkillData.SkillType.CLONE:
			_spawn_clone()
			return true
		SkillData.SkillType.REVIVE:
			_mass_revive()
			return true
	return false

func _raise_minions() -> void:
	var scene := _troop_scene()
	if scene == null:
		return
	for offset in RAISE_OFFSETS:
		var troop: Troop = scene.instantiate()
		troop.global_position = hero.global_position + Vector2(offset.x * hero.facing_direction, offset.y)
		hero.get_tree().current_scene.add_child(troop)

func _launch_seekers(skill: SkillData) -> void:
	var primary := BotTactics.pick_target(hero, 9999.0) as Node2D
	hero.attack_origin.position = Vector2(30.0 * hero.facing_direction, 0.0)
	for i in 2:
		var seeker: SeekingProjectile = SEEKER_SCENE.instantiate()
		seeker.source = hero
		seeker.faction = hero.faction
		seeker.target = primary
		seeker.damage = hero.get_attack() * skill.damage_multiplier
		seeker.knockback_strength = skill.knockback
		seeker.collision_layer = 8 if hero.faction == &"ally" else 16
		seeker.collision_mask = 5 if hero.faction == &"ally" else 3
		seeker.global_position = hero.attack_origin.global_position + Vector2(0.0, 18.0 if i == 0 else -18.0)
		hero.get_tree().current_scene.add_child(seeker)

func _spawn_clone() -> void:
	var victim := _most_recent_enemy_kill()
	var clone: CloneUnit = CLONE_SCENE.instantiate()
	clone.faction = hero.faction
	clone.basic_attack_scene = hero.basic_attack_scene
	var color_source := victim if is_instance_valid(victim) else hero
	if color_source.has_node("Body"):
		var body := color_source.get_node("Body") as Polygon2D
		if body != null:
			clone.body_color = body.color
	clone.global_position = hero.global_position + Vector2(40.0 * hero.facing_direction, 0.0)
	hero.get_tree().current_scene.add_child(clone)

func _most_recent_enemy_kill() -> Node2D:
	var mm := hero.get_tree().root.get_node_or_null("MatchManager")
	if mm == null:
		return null
	for entry in mm.recent_deaths:
		if entry.get("faction") != hero.faction:
			var unit = entry.get("unit")
			if unit == null or not is_instance_valid(unit):
				continue
			return unit as Node2D
	return null

func _mass_revive() -> void:
	var tree := hero.get_tree()
	var mm := tree.root.get_node_or_null("MatchManager")
	var revived := false
	for ally_hero in tree.get_nodes_in_group(&"heroes"):
		if ally_hero.get("faction") != hero.faction:
			continue
		if not ally_hero.has_method("is_dead") or not ally_hero.is_dead():
			continue
		if mm != null:
			if mm.revive_hero(ally_hero):
				revived = true
	if mm != null:
		for entry in mm.recent_deaths:
			if entry.get("faction") != hero.faction:
				continue
			if not entry.get("is_troop", false):
				continue
			var scene_path: String = entry.get("scene", "")
			if scene_path.is_empty():
				continue
			var scene := load(scene_path) as PackedScene
			if scene == null:
				continue
			var troop: Troop = scene.instantiate()
			troop.faction = hero.faction
			troop.basic_attack_scene = hero.basic_attack_scene
			troop.global_position = hero.global_position + Vector2(randf_range(-60.0, 60.0), randf_range(-30.0, 30.0))
			tree.current_scene.add_child(troop)
			revived = true
	var cost := hero.max_hp * REVIVE_COST_RATIO
	if not revived:
		return
	if hero.hp > cost:
		hero.hp -= cost
		hero.health_changed.emit(hero.hp, hero.max_hp)
	else:
		hero.take_damage(hero.hp, Vector2.ZERO, hero)

func _troop_scene() -> PackedScene:
	var spawner := hero.get_tree().current_scene.get_node_or_null("TroopSpawner")
	if spawner == null:
		return null
	return spawner.ally_troop_scene if hero.faction == &"ally" else spawner.enemy_troop_scene
