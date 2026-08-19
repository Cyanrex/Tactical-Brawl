class_name PlayerTestBot
extends AIAgent


@export var debug_auto_bot: bool = true
@export var debug_attack_interval: float = 0.9
@export var debug_heal_threshold: float = 0.0
@export var debug_respawn_disengage_range: float = 300.0
@export var debug_respawn_disengage_duration: float = 4.0

var _attack_cd: float = 0.0
var _patrol_dir: int = 1
var _was_dead: bool = false
var _respawned_at: float = -INF
var _was_active: bool = false

func _ready() -> void:
	super._ready()
	enabled = debug_auto_bot
	print("[TestBot] debug_auto_bot = %s — press 'q' (debug_bot_toggle) to toggle" % str(debug_auto_bot))

func _physics_process(delta: float) -> void:
	physics_tick(delta)

func physics_tick(delta: float) -> void:
	if Input.is_action_just_pressed("debug_bot_toggle"):
		debug_auto_bot = not debug_auto_bot
		enabled = debug_auto_bot
		print("[TestBot] auto bot %s" % ("ON" if debug_auto_bot else "OFF"))
		_release_all_input()
	if not enabled or not debug_auto_bot or body == null:
		if _was_active:
			_release_all_input()
		_was_active = false
		return
	_was_active = true
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null and mm.is_match_over():
		_release_all_input()
		return
	if body.state == CombatUnit.UnitState.DEAD:
		_release_all_input()
		_was_dead = true
		return
	if _was_dead:
		_was_dead = false
		_respawned_at = mm.match_elapsed if mm != null else 0.0
	_heal_buffer()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	super.physics_tick(delta)
	if _handle_respawn_disengage():
		return
	if current_state == State.ATTACK:
		_release_movement()
	elif current_state == State.IDLE and not lane_push_when_idle:
		_set_movement(_patrol())

func _handle_respawn_disengage() -> bool:
	var mm := get_tree().root.get_node_or_null("MatchManager")
	var elapsed: float = mm.match_elapsed if mm != null else 0.0
	if elapsed < _respawned_at or elapsed > _respawned_at + debug_respawn_disengage_duration:
		return false
	var threat := _nearest_threat()
	if threat == null:
		return false
	var to_threat := threat.global_position - body.global_position
	if to_threat.length() > debug_respawn_disengage_range:
		return false
	_set_movement(-to_threat.normalized())
	return true

func _nearest_threat() -> Node2D:
	var hero := BotTactics.nearest_enemy_of_type(body, &"heroes") as Node2D
	var troop := BotTactics.nearest_enemy_of_type(body, &"troops") as Node2D
	if hero == null:
		return troop
	if troop == null:
		return hero
	var hero_dist := body.global_position.distance_to(hero.global_position)
	var troop_dist := body.global_position.distance_to(troop.global_position)
	return hero if hero_dist <= troop_dist else troop

func _heal_buffer() -> void:
	if body.hp < body.max_hp * debug_heal_threshold:
		body.hp = body.max_hp
		body.health_changed.emit(body.hp, body.max_hp)


func _execute_basic_attack() -> bool:
	if _attack_cd > 0.0:
		return false
	var did_attack := super._execute_basic_attack()
	if did_attack:
		_attack_cd = debug_attack_interval
	return did_attack

func _apply_movement(direction: Vector2, _body_state: CombatUnit.UnitState) -> void:
	_set_movement(direction)

func _stop_body() -> void:
	_release_movement()

func _patrol() -> Vector2:
	if body.global_position.x > 100.0:
		_patrol_dir = -1
	elif body.global_position.x < -100.0:
		_patrol_dir = 1
	return Vector2(_patrol_dir, 0.0)

func _set_movement(dir: Vector2) -> void:
	_set_dir(&"move_right", &"move_left", dir.x)
	_set_dir(&"move_down", &"move_up", dir.y)

func _set_dir(positive: StringName, negative: StringName, value: float) -> void:
	if value > 0.15:
		Input.action_press(positive)
		Input.action_release(negative)
	elif value < -0.15:
		Input.action_release(positive)
		Input.action_press(negative)
	else:
		Input.action_release(positive)
		Input.action_release(negative)

func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func _release_all_input() -> void:
	_release_movement()
	for action in ["basic_attack"]:
		Input.action_release(action)
	for action in ["skill_1", "skill_2", "skill_3", "ultimate"]:
		Input.action_release(action)
