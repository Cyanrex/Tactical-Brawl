class_name AIAgent
extends Node


enum State {
	IDLE,
	CHASE,
	ATTACK,
	RETREAT,
	KITE,
	DEFEND,
}

const ROLE_FIGHTER_TANK := 0
const ROLE_ASSASSIN := 1
const ROLE_MAGE := 2
const ROLE_SUPPORT := 3
const ASSASSIN_HERO_SEARCH_RANGE := 900.0
const SUPPORT_HERO_SEARCH_RANGE := 500.0

@export var enabled: bool = true
@export var target_order: Array[StringName] = [&"heroes", &"troops", &"structures"]
@export var hero_priority_range: float = 600.0
@export var aggro_range: float = -1.0
@export var tower_priority_range: float = -1.0
@export var prefer_basic_attack_in_range: bool = false
@export var skip_spawn_heroes: bool = true
@export var skill_engage_range: float = -1.0
@export var lane_push_when_idle: bool = true
@export var retreat_enabled: bool = false
@export var retreat_hp_ratio: float = 0.2
@export var resume_hp_ratio: float = 1.0
@export var retreat_regen: float = 125.0
@export var skill_cast_order: Array[int] = [4, 2, 1, 3]
@export var ultimate_slot: int = 4
@export var ultimate_hp_threshold: float = 0.6
@export var clear_minions_when_passing: bool = true
@export var minion_clear_range: float = -1.0
@export var hero_chase_give_up_range: float = -1.0
@export var main_tower_defense_enabled: bool = true
@export var main_tower_defense_radius: float = 700.0
@export var team_fight_enabled: bool = true
@export var team_fight_range: float = 420.0
@export var team_ally_support_range: float = 420.0
@export var team_assist_range: float = 700.0
@export var team_bait_enabled: bool = true
@export var team_bait_standoff_range: float = 180.0

var current_state: State = State.IDLE
var target: Node = null
var body: CombatUnit = null
var _defending_main_tower: bool = false
var _team_retreating: bool = false
var _team_fight_active: bool = false
var _team_helping: bool = false
var _team_baiting: bool = false

var _clearing_passing_minion: bool = false
var _resume_target: Node = null


func _ready() -> void:
	body = get_parent() as CombatUnit
	if body == null:
		push_error("AIAgent must be a child of a CombatUnit.")


func physics_tick(delta: float) -> void:
	if body == null:
		return
	if not enabled:
		current_state = State.IDLE
		_stop_body()
		return
	if body.is_match_over():
		_stop_body()
		return

	if body is Hero:
		(body as Hero).ai_manage_toggles()
	if _process_retreat(delta):
		_exit_clear_mode()
		return
	var defending_main_tower := _process_main_tower_defense()
	if defending_main_tower:
		_exit_clear_mode()
		if target == null:
			var main_tower := BotTactics.own_main_tower(body)
			current_state = State.DEFEND
			if main_tower != null and body.global_position.distance_to(main_tower.global_position) > 90.0:
				_apply_movement(BotTactics.steer_toward_point(body, main_tower.global_position), CombatUnit.UnitState.MOVE)
			else:
				_stop_body()
			return
	if not defending_main_tower and _process_team_fight(delta):
		_exit_clear_mode()
		return
	if defending_main_tower:
		_team_fight_active = false
		_team_helping = false
		_team_baiting = false
	elif _team_helping:
		_exit_clear_mode()

	if not _is_valid_target(target):
		var resume := _resume_target
		_exit_clear_mode()
		target = resume if _is_valid_target(resume) else _pick_first_target()
	elif target is Tower:
		if not _siege_priority_active():
			var nearby_target := _pick_nearby_target()
			if nearby_target != null and not nearby_target is Tower:
				target = nearby_target
	elif not _defending_main_tower and not _team_helping and _clearing_passing_minion:
		var hero_in_melee := BotTactics.nearest_enemy_hero(body, body.get_ai_attack_range())
		if hero_in_melee != null:
			_exit_clear_mode()
			target = hero_in_melee
	elif not _defending_main_tower and not _team_helping:
		var nearby_hero := BotTactics.nearest_enemy_hero(body, _hero_priority_search_range())
		if nearby_hero != null and nearby_hero != target:
			target = nearby_hero
		elif _hero_retreated_far():
			_exit_clear_mode()
			target = null

	if target == null:
		current_state = State.IDLE
		if lane_push_when_idle:
			_move_in_lane()
		else:
			_stop_body()
		return

	if _team_baiting and target is Hero:
		if _process_team_bait():
			return

	var distance := body.global_position.distance_to(target.global_position)
	var attack_range := body.get_ai_attack_range()
	var engage_range := attack_range
	if skill_engage_range >= 0.0:
		engage_range = maxf(engage_range, skill_engage_range)

	if distance > attack_range and _sweep_passing_minion():
		distance = body.global_position.distance_to(target.global_position)

	var prefer_basic_in_range := _role_prefers_basic_attack_in_range() and distance <= attack_range
	var skill_window_open := not prefer_basic_in_range or not body.attack_lock_timer.is_stopped()
	if not _clearing_passing_minion and skill_window_open and distance <= engage_range and _try_cast_skill(distance):
		current_state = State.ATTACK
		body.velocity = Vector2.ZERO
		return

	if distance <= attack_range:
		_face_target()
		if body.is_ranged_basic_attack():
			_execute_basic_attack()
			if distance < body.get_basic_attack_kite_range():
				current_state = State.KITE
				var away := -BotTactics.steer_toward(body, target)
				_apply_movement(away, CombatUnit.UnitState.MOVE)
				body.update_facing(body.global_position.direction_to(target.global_position))
			else:
				if body.can_attack_while_moving:
					current_state = State.CHASE
					_move_toward_target()
				else:
					current_state = State.ATTACK
					body.velocity = Vector2.ZERO
		elif body.can_attack_while_moving:
			_execute_basic_attack()
			current_state = State.CHASE
			_move_toward_target()
		else:
			current_state = State.ATTACK
			body.velocity = Vector2.ZERO
			_execute_basic_attack()
		return

	current_state = State.CHASE
	_move_toward_target()


func _process_retreat(delta: float) -> bool:
	if not retreat_enabled:
		return false

	var hp_ratio := body.hp / maxf(body.max_hp, 1.0)
	if current_state == State.RETREAT:
		if hp_ratio < resume_hp_ratio:
			_retreat(delta)
			return true
		current_state = State.IDLE
		if body.state == CombatUnit.UnitState.RETREAT:
			body.state = CombatUnit.UnitState.IDLE
	elif hp_ratio < retreat_hp_ratio:
		_retreat(delta)
		return true
	return false

func _process_main_tower_defense() -> bool:
	if not main_tower_defense_enabled:
		_defending_main_tower = false
		return false
	var main_tower := BotTactics.own_main_tower(body)
	if main_tower == null:
		_defending_main_tower = false
		return false
	var threat := BotTactics.nearest_enemy_near_point(
		body,
		main_tower.global_position,
		main_tower_defense_radius,
	)
	if threat == null and not main_tower.is_under_attack():
		_defending_main_tower = false
		if current_state == State.DEFEND:
			current_state = State.IDLE
		return false
	_defending_main_tower = true
	if threat != null:
		target = threat
	elif not _is_main_tower_threat(target, main_tower):
		target = null
	return true

func _process_team_fight(delta: float) -> bool:
	_team_fight_active = false
	_team_helping = false
	_team_baiting = false
	if not team_fight_enabled or not body is Hero:
		_team_retreating = false
		return false
	var enemy_count := BotTactics.nearby_enemy_hero_count(body, team_fight_range)
	var ally_count := BotTactics.nearby_ally_hero_count(body, team_ally_support_range)
	var help_target := BotTactics.team_help_target(body, team_assist_range)
	if help_target != null:
		_team_fight_active = true
		_team_helping = true
		_team_retreating = false
		target = help_target
		return false
	var outnumbered := enemy_count > ally_count + 1
	if _team_retreating:
		if outnumbered:
			target = null
			_retreat(delta)
			return true
		_team_retreating = false
		if current_state == State.RETREAT:
			current_state = State.IDLE
	elif outnumbered:
		_team_retreating = true
		target = null
		_retreat(delta)
		return true
	if enemy_count <= 0 or ally_count <= 0:
		return false
	var team_target := BotTactics.nearest_enemy_hero(body, team_fight_range)
	if team_target == null:
		return false
	_team_fight_active = true
	target = team_target
	_team_baiting = team_bait_enabled and BotTactics.team_baiter(body, team_ally_support_range) == body
	return false

func _process_team_bait() -> bool:
	var distance := body.global_position.distance_to(target.global_position)
	var poke_range := maxf(team_bait_standoff_range, body.get_ai_attack_range())
	if skill_engage_range >= 0.0:
		poke_range = maxf(poke_range, skill_engage_range)
	if distance > poke_range:
		current_state = State.CHASE
		_move_toward_target()
		return true
	_face_target()
	var skill_window_open := not _role_prefers_basic_attack_in_range() or not body.attack_lock_timer.is_stopped()
	if skill_window_open and distance <= poke_range and _try_cast_skill(distance):
		current_state = State.ATTACK
		body.velocity = Vector2.ZERO
		return true
	if distance <= body.get_ai_attack_range():
		_execute_basic_attack()
	current_state = State.KITE
	_apply_movement(-BotTactics.steer_toward(body, target), CombatUnit.UnitState.MOVE)
	return true


func _retreat(delta: float) -> void:
	current_state = State.RETREAT
	body.ai_regenerate(retreat_regen * delta)
	var direction := BotTactics.steer_toward_point(body, body.get_ai_home_position())
	_apply_movement(direction, CombatUnit.UnitState.RETREAT)

func _is_main_tower_threat(candidate, main_tower: Tower) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate is Node2D:
		return false
	if candidate.get("faction") == body.faction:
		return false
	if candidate.has_method("is_dead") and candidate.is_dead():
		return false
	return main_tower.global_position.distance_to(candidate.global_position) <= main_tower_defense_radius


func _hero_retreated_far() -> bool:
	if target == null or not (target is Hero):
		return false
	if BotTactics.is_at_own_spawn(target):
		return true
	var give_up := _hero_chase_give_up_range()
	return give_up >= 0.0 and body.global_position.distance_to(target.global_position) > give_up


func _hero_chase_give_up_range() -> float:
	if hero_chase_give_up_range >= 0.0:
		return hero_chase_give_up_range
	return _hero_priority_search_range() * 1.5


func _minion_clear_range() -> float:
	if minion_clear_range >= 0.0:
		return minion_clear_range
	return body.get_ai_attack_range() + 40.0


func _sweep_passing_minion() -> bool:
	if not clear_minions_when_passing or _clearing_passing_minion or _defending_main_tower or _hero_role() == ROLE_ASSASSIN:
		return false
	var minion := BotTactics.nearest_enemy_of_type(body, &"troops", _minion_clear_range())
	if minion == null or minion == target:
		return false
	_resume_target = target
	_clearing_passing_minion = true
	target = minion
	return true


func _exit_clear_mode() -> void:
	_clearing_passing_minion = false
	_resume_target = null


func _try_cast_skill(distance: float) -> bool:
	var hero := body as Hero
	if hero == null:
		return false

	var hp_ratio := hero.hp / maxf(hero.max_hp, 1.0)
	for slot in skill_cast_order:
		if slot == ultimate_slot and hp_ratio >= ultimate_hp_threshold:
			continue
		var skill: SkillData = hero.get_skill(slot)
		if skill == null or hero.level < skill.unlock_level:
			continue
		if distance > hero.get_ai_cast_range(slot, _fallback_skill_range(slot)):
			continue
		_face_target()
		var aim_position: Vector2 = target.global_position if _is_valid_target(target) else Vector2.INF
		if hero.try_use_skill(slot, aim_position):
			return true
	return false


func _fallback_skill_range(slot: int) -> float:
	match slot:
		4:
			return 200.0
		2:
			return 380.0
		1:
			return 80.0
		3:
			return 120.0
	return 80.0


func _move_toward_target() -> void:
	var direction := BotTactics.steer_toward(body, target)
	_apply_movement(direction, CombatUnit.UnitState.MOVE)


func _move_in_lane() -> void:
	var lane_direction := 1.0 if body.faction == &"ally" else -1.0
	var waypoint := body.global_position + Vector2(lane_direction * 4000.0, 0.0)
	_apply_movement(BotTactics.steer_toward_point(body, waypoint), CombatUnit.UnitState.MOVE)


func _pick_first_target() -> Node:
	if tower_priority_range >= 0.0:
		var hero_range := aggro_range if aggro_range >= 0.0 else _hero_priority_search_range()
		var hero := BotTactics.nearest_enemy_hero(body, hero_range)
		if hero != null:
			return hero
		var tower := BotTactics.nearest_enemy_of_type(body, &"structures", tower_priority_range)
		if tower != null:
			return tower
	return BotTactics.pick_target(
		body,
		_hero_priority_search_range(),
		target_order,
		aggro_range,
		skip_spawn_heroes,
	)


func _siege_priority_active() -> bool:
	return tower_priority_range >= 0.0 and _is_valid_target(target) and target is Tower \
		and body.global_position.distance_to(target.global_position) <= tower_priority_range


func _pick_nearby_target() -> Node:
	var nearby_range := aggro_range if aggro_range >= 0.0 else _hero_priority_search_range()
	return BotTactics.pick_target(
		body,
		_hero_priority_search_range(),
		target_order,
		nearby_range,
		skip_spawn_heroes,
	)


func _execute_basic_attack() -> bool:
	if _is_valid_target(target):
		return body.perform_basic_attack(target.global_position)
	return body.perform_basic_attack()


func _apply_movement(direction: Vector2, body_state: CombatUnit.UnitState) -> void:
	body.velocity = direction * body.get_move_speed()
	body.update_facing(direction)
	body.state = body_state


func _stop_body() -> void:
	body.velocity = Vector2.ZERO
	if body.state not in [
		CombatUnit.UnitState.ATTACK,
		CombatUnit.UnitState.CAST_SKILL,
		CombatUnit.UnitState.STUNNED,
		CombatUnit.UnitState.DEAD,
	]:
		body.state = CombatUnit.UnitState.IDLE


func _face_target() -> void:
	if _is_valid_target(target):
		body.update_facing(body.global_position.direction_to(target.global_position))


func _hero_role() -> int:
	var hero := body as Hero
	return hero.role if hero != null else ROLE_FIGHTER_TANK


func _hero_priority_search_range() -> float:
	match _hero_role():
		ROLE_ASSASSIN:
			return maxf(hero_priority_range, ASSASSIN_HERO_SEARCH_RANGE)
		ROLE_SUPPORT:
			if hero_priority_range < 0.0:
				return SUPPORT_HERO_SEARCH_RANGE
			return minf(hero_priority_range, SUPPORT_HERO_SEARCH_RANGE)
	return hero_priority_range


func _role_prefers_basic_attack_in_range() -> bool:
	return prefer_basic_attack_in_range or _hero_role() in [ROLE_FIGHTER_TANK, ROLE_ASSASSIN]


func _is_valid_target(candidate) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate == body or not candidate is Node2D:
		return false
	if candidate.get("faction") == body.faction:
		return false
	if candidate.has_method("is_dead") and candidate.is_dead():
		return false
	if not _defending_main_tower and not _team_helping and not BotTactics.can_see(body, candidate):
		return false
	if _defending_main_tower and not BotTactics.can_see(body, candidate):
		var main_tower := BotTactics.own_main_tower(body)
		if main_tower == null or not _is_main_tower_threat(candidate, main_tower):
			return false
	if _team_helping and not BotTactics.can_see(body, candidate):
		if BotTactics.team_help_target(body, team_assist_range) != candidate:
			return false
	return true
