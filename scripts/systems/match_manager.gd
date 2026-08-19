extends Node

signal match_state_changed(new_state: MatchState)
signal hero_died(hero: CombatUnit)
signal hero_respawned(hero: CombatUnit)
signal victory_triggered()
signal defeat_triggered()
signal match_time_changed(elapsed: float)
signal tower_lost(faction: StringName, towers_destroyed: int)

enum MatchState {
	STARTING,
	PLAYING,
	PAUSED,
	VICTORY,
	DEFEAT
}

@export var respawn_delay: float = 3.0
@export var ally_spawn_point := Vector2(-480.0, 0.0)
@export var enemy_spawn_point := Vector2(480.0, 0.0)

const RECENT_DEATHS_CAP := 16
const RECENT_DEATHS_WINDOW := 12.0
const HERO_TEAM_XP_FRACTION := 0.40
const MINION_TEAM_XP_FRACTION := 0.30
const LAST_HIT_BONUS_XP_FRACTION := 0.10

var match_state: MatchState = MatchState.STARTING
var ally_towers_destroyed: int = 0
var enemy_towers_destroyed: int = 0
var match_elapsed: float = 0.0
var recent_deaths: Array = []

var _pending_respawns: Dictionary = {}
var _respawn_tokens: Dictionary = {}

func _ready() -> void:
	match_state = MatchState.STARTING
	match_elapsed = 0.0
	match_state_changed.emit(match_state)

func reset_match() -> void:
	match_state = MatchState.STARTING
	ally_towers_destroyed = 0
	enemy_towers_destroyed = 0
	match_elapsed = 0.0
	recent_deaths.clear()
	_pending_respawns.clear()
	_respawn_tokens.clear()
	match_state_changed.emit(match_state)

func start_match() -> void:
	if match_state != MatchState.STARTING:
		return
	match_state = MatchState.PLAYING
	match_state_changed.emit(match_state)

func _process(delta: float) -> void:
	if match_state != MatchState.PLAYING:
		return
	match_elapsed += delta
	match_time_changed.emit(match_elapsed)

func register_combatant(unit: CombatUnit) -> void:
	if unit.died.is_connected(_on_unit_died):
		return
	unit.died.connect(_on_unit_died)

func register_hero(hero: CombatUnit) -> void:
	if hero.died.is_connected(_on_hero_died):
		return
	hero.died.connect(_on_hero_died)

func register_tower(tower: Tower) -> void:
	if tower.died.is_connected(_on_tower_died):
		return
	tower.died.connect(_on_tower_died)

func _on_unit_died(unit: CombatUnit) -> void:
	if match_state != MatchState.PLAYING:
		return
	if unit is Hero:
		(unit as Hero).register_death()
	var killer := unit.last_hit_source
	if is_instance_valid(killer) and killer is Hero and killer.faction != unit.faction:
		(killer as Hero).register_kill(unit)
	_award_experience(unit)
	recent_deaths.push_front({"unit": unit, "faction": unit.faction, "time": match_elapsed, "scene": unit.scene_file_path, "is_troop": unit is Troop})
	while recent_deaths.size() > RECENT_DEATHS_CAP:
		recent_deaths.pop_back()
	while not recent_deaths.is_empty() and match_elapsed - recent_deaths[-1]["time"] > RECENT_DEATHS_WINDOW:
		recent_deaths.pop_back()

func _award_experience(unit: CombatUnit) -> void:
	var allied_faction := &"enemy" if unit.faction == &"ally" else &"ally"
	var allied_heroes: Array[Hero] = []
	for node in get_tree().get_nodes_in_group(&"heroes"):
		if node is Hero and is_instance_valid(node) and node.faction == allied_faction:
			allied_heroes.append(node as Hero)
	if allied_heroes.is_empty():
		return

	var contributions: Dictionary = {}
	for source in unit.damage_contributions:
		if source is Hero and is_instance_valid(source) and source.faction == allied_faction and not source.is_dead():
			var damage := float(unit.damage_contributions[source])
			if damage > 0.0:
				contributions[source] = damage
	var last_hit := unit.last_hit_source if unit.last_hit_source is Hero else null
	if last_hit != null and is_instance_valid(last_hit) and last_hit.faction == allied_faction and not last_hit.is_dead():
		contributions[last_hit] = maxf(float(contributions.get(last_hit, 0.0)), 0.001)
	if contributions.is_empty():
		return

	var team_fraction := MINION_TEAM_XP_FRACTION if unit is Troop else HERO_TEAM_XP_FRACTION
	var base_xp := unit.exp_value * team_fraction
	for hero in allied_heroes:
		hero.add_exp(base_xp)

	var total_damage := 0.0
	for damage in contributions.values():
		total_damage += float(damage)
	if total_damage <= 0.0:
		return
	var total_weight := 0.0
	for source in contributions:
		var weight := float(contributions[source])
		if source == last_hit:
			weight += total_damage
		total_weight += weight
	if total_weight <= 0.0:
		return
	var bonus_xp := unit.exp_value * LAST_HIT_BONUS_XP_FRACTION
	for source in contributions:
		var weight := float(contributions[source])
		if source == last_hit:
			weight += total_damage
		(source as Hero).add_exp(bonus_xp * weight / total_weight)

func _on_hero_died(hero: CombatUnit) -> void:
	if match_state != MatchState.PLAYING:
		return
	hero_died.emit(hero)
	_deactivate_hero(hero)
	var delay := respawn_delay + hero.level * 0.5
	_pending_respawns[hero] = true
	var token: int = _respawn_tokens.get(hero, 0) + 1
	_respawn_tokens[hero] = token
	get_tree().create_timer(delay).timeout.connect(_timed_respawn.bind(hero, token))

func _timed_respawn(hero, token: int) -> void:
	if hero == null or not is_instance_valid(hero):
		_pending_respawns.erase(hero)
		return
	if _respawn_tokens.get(hero, 0) != token:
		return
	_respawn_hero(hero)

func revive_hero(hero: CombatUnit) -> bool:
	if match_state != MatchState.PLAYING:
		return false
	if not _pending_respawns.has(hero):
		return false
	if not is_instance_valid(hero):
		_pending_respawns.erase(hero)
		return false
	_respawn_tokens[hero] = _respawn_tokens.get(hero, 0) + 1
	_respawn_hero(hero)
	return true

func _deactivate_hero(hero: CombatUnit) -> void:
	hero.hide()
	hero.set_deferred("collision_layer", 0)
	hero.set_deferred("collision_mask", 0)

func _respawn_hero(hero: CombatUnit) -> void:
	if not is_instance_valid(hero):
		return
	if match_state != MatchState.PLAYING:
		return
	_pending_respawns.erase(hero)
	var spawn_point := ally_spawn_point if hero.faction == &"ally" else enemy_spawn_point
	hero.global_position = spawn_point + hero.spawn_slot_offset
	hero.hp = hero.max_hp
	hero.velocity = Vector2.ZERO
	hero.dash_remaining = 0.0
	hero.dash_velocity = Vector2.ZERO
	hero.state = CombatUnit.UnitState.IDLE
	hero.last_hit_source = null
	hero.set_deferred("collision_layer", hero._default_collision_layer)
	hero.set_deferred("collision_mask", hero._default_collision_mask)
	hero.reset_respawn_effects()
	hero.show()
	hero.health_changed.emit(hero.hp, hero.max_hp)
	hero_respawned.emit(hero)

func _on_tower_died(tower: Tower) -> void:
	if match_state != MatchState.PLAYING:
		return
	if not tower.is_main:
		if tower.faction == &"ally":
			ally_towers_destroyed += 1
			tower_lost.emit(&"ally", ally_towers_destroyed)
		else:
			enemy_towers_destroyed += 1
			tower_lost.emit(&"enemy", enemy_towers_destroyed)
	if not _all_towers_destroyed(tower.faction):
		return
	if tower.faction == &"enemy":
		match_state = MatchState.VICTORY
		victory_triggered.emit()
	else:
		match_state = MatchState.DEFEAT
		defeat_triggered.emit()
	match_state_changed.emit(match_state)

func _all_towers_destroyed(faction: StringName) -> bool:
	var tower_count := 0
	for node in get_tree().get_nodes_in_group(&"structures"):
		if not node is Tower or node.faction != faction:
			continue
		tower_count += 1
		if not node.is_dead():
			return false
	return tower_count > 0

func is_match_over() -> bool:
	return match_state == MatchState.VICTORY or match_state == MatchState.DEFEAT
