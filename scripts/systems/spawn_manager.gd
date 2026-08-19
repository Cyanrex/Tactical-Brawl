class_name TroopSpawner
extends Node2D

@export var ally_troop_scene: PackedScene
@export var enemy_troop_scene: PackedScene
@export var ally_ranged_troop_scene: PackedScene
@export var enemy_ranged_troop_scene: PackedScene
@export var ally_elite_troop_scene: PackedScene
@export var enemy_elite_troop_scene: PackedScene
@export var initial_wave_size: int = 10
@export var spawn_interval: float = 15.0
@export var spawn_scatter: float = 60.0
@export var ranged_bonus_count: int = 5
@export var elite_bonus_count: int = 5

var _ally_tier: int = 0
var _enemy_tier: int = 0

@onready var ally_spawn_point: Marker2D = $AllySpawnPoint
@onready var enemy_spawn_point: Marker2D = $EnemySpawnPoint
@onready var ally_spawn_timer: Timer = $AllySpawnTimer
@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer

func _ready() -> void:
	ally_spawn_timer.timeout.connect(spawn_ally_troop)
	enemy_spawn_timer.timeout.connect(spawn_enemy_troop)
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.match_state_changed.connect(_on_match_state_changed)
		mm.tower_lost.connect(_on_tower_lost)
		_on_match_state_changed(mm.match_state)
	else:
		_start_spawning()

func _on_tower_lost(faction: StringName, towers_destroyed: int) -> void:
	if faction == &"ally":
		_enemy_tier = towers_destroyed
	else:
		_ally_tier = towers_destroyed

func _on_match_state_changed(new_state: int) -> void:
	if new_state == MatchManager.MatchState.PLAYING:
		_start_spawning()
	else:
		_stop_spawning()

func _start_spawning() -> void:
	ally_spawn_timer.start(spawn_interval)
	enemy_spawn_timer.start(spawn_interval)
	call_deferred("_spawn_initial_wave")

func _stop_spawning() -> void:
	ally_spawn_timer.stop()
	enemy_spawn_timer.stop()

func _spawn_initial_wave() -> void:
	_spawn_wave_ally()
	_spawn_wave_enemy()

func spawn_ally_troop() -> void:
	_spawn_wave_ally()

func spawn_enemy_troop() -> void:
	_spawn_wave_enemy()

func _spawn_wave_ally() -> void:
	_spawn_escalated_wave(
		ally_troop_scene, ally_elite_troop_scene, ally_ranged_troop_scene,
		ally_spawn_point, _ally_tier)

func _spawn_wave_enemy() -> void:
	_spawn_escalated_wave(
		enemy_troop_scene, enemy_elite_troop_scene, enemy_ranged_troop_scene,
		enemy_spawn_point, _enemy_tier)

func _spawn_escalated_wave(melee_scene: PackedScene, elite_scene: PackedScene, ranged_scene: PackedScene, at: Marker2D, tier: int) -> void:
	var melee := melee_scene
	var melee_count := initial_wave_size
	if tier >= 2:
		melee = elite_scene
		melee_count += elite_bonus_count
	var ranged_count := ranged_bonus_count if tier >= 1 else 0
	var total := melee_count + ranged_count
	for i in melee_count:
		_spawn_troop(melee, at, _formation_offset(i, total))
	for i in ranged_count:
		_spawn_troop(ranged_scene, at, _formation_offset(melee_count + i, total))

func _formation_offset(index: int, total: int = -1) -> Vector2:
	if total < 0:
		total = initial_wave_size
	if total <= 1:
		return Vector2.ZERO
	var y := lerpf(-spawn_scatter, spawn_scatter, float(index) / float(total - 1))
	var x := (randf() - 0.5) * 20.0
	return Vector2(x, y)

func _spawn_troop(scene: PackedScene, at: Marker2D, offset: Vector2 = Vector2.ZERO) -> void:
	if scene == null:
		return
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null and mm.is_match_over():
		return
	var troop: Troop = scene.instantiate()
	troop.global_position = at.global_position + offset + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	get_tree().current_scene.add_child(troop)
