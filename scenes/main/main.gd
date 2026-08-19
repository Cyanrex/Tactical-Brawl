extends Node2D

const WALKABLE_TEXTURE := preload("res://resources/assets/map background/dirt 1.png")

@export var arena_size: Vector2 = Vector2(1280.0, 720.0)
@export var player_hero_scene: PackedScene
@export var enemy_hero_scene: PackedScene
@export var basic_attack_scene: PackedScene
@export var team_size: int = 5

var player: CombatUnit = null

var _menu_ui: MainMenuUI = null

func _ready() -> void:
	_setup_arena()
	if HeroRoster.HEROES.is_empty():
		_spawn_heroes(player_hero_scene, enemy_hero_scene)
		_start_match()
		return
	_show_main_menu()

func arena_rect() -> Rect2:
	var half := arena_size * 0.5
	return Rect2(-half, arena_size)

func _setup_arena() -> void:
	var half := arena_size * 0.5
	_resize_wall("WallTop", Vector2(0.0, -half.y), Vector2(arena_size.x, 40.0))
	_resize_wall("WallBottom", Vector2(0.0, half.y), Vector2(arena_size.x, 40.0))
	_resize_wall("WallLeft", Vector2(-half.x, 0.0), Vector2(40.0, arena_size.y))
	_resize_wall("WallRight", Vector2(half.x, 0.0), Vector2(40.0, arena_size.y))

	var camera := $Camera2D as Camera2D
	camera.limit_left = int(-half.x)
	camera.limit_right = int(half.x)
	camera.limit_top = int(-half.y)
	camera.limit_bottom = int(half.y)

	var spawn_x := half.x - 160.0
	var main_tower_x := half.x - 40.0
	var mid_tower_x := half.x * 0.65
	var first_tower_x := half.x * 0.325
	$AllySpawn.position = Vector2(-spawn_x, 0.0)
	$EnemySpawn.position = Vector2(spawn_x, 0.0)
	$AllyBase.position = Vector2(-main_tower_x, 0.0)
	$AllyMidTower.position = Vector2(-mid_tower_x, 0.0)
	$AllyFirstTower.position = Vector2(-first_tower_x, 0.0)
	$EnemyTower.position = Vector2(main_tower_x, 0.0)
	$EnemyMidTower.position = Vector2(mid_tower_x, 0.0)
	$EnemyFirstTower.position = Vector2(first_tower_x, 0.0)
	$TroopSpawner/AllySpawnPoint.position = Vector2(-spawn_x, 0.0)
	$TroopSpawner/EnemySpawnPoint.position = Vector2(spawn_x, 0.0)

	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.ally_spawn_point = Vector2(-spawn_x, 0.0)
		mm.enemy_spawn_point = Vector2(spawn_x, 0.0)
	queue_redraw()

func _draw() -> void:
	var half := arena_size * 0.5
	var backdrop_rect := Rect2(-half - Vector2(2000.0, 1000.0), arena_size + Vector2(4000.0, 2000.0))
	draw_rect(backdrop_rect, Color(0.055, 0.1, 0.12, 1.0), true)
	var field_rect := Rect2(-half, arena_size)
	draw_rect(field_rect, Color(0.055, 0.1, 0.12, 1.0), true)
	var shoulder_height := minf(92.0, arena_size.y * 0.18)
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(arena_size.x, shoulder_height)), Color(0.08, 0.18, 0.18, 1.0), true)
	draw_rect(Rect2(Vector2(-half.x, half.y - shoulder_height), Vector2(arena_size.x, shoulder_height)), Color(0.08, 0.18, 0.18, 1.0), true)
	var road_rect := Rect2(Vector2(-half.x, -half.y + shoulder_height), Vector2(arena_size.x, arena_size.y - shoulder_height * 2.0))
	draw_rect(road_rect, Color(0.11, 0.15, 0.18, 1.0), true)
	draw_texture_rect(WALKABLE_TEXTURE, field_rect, true)

func _resize_wall(wall_name: String, pos: Vector2, size: Vector2) -> void:
	var wall := get_node(wall_name) as StaticBody2D
	wall.position = pos
	var shape_node := wall.get_node("CollisionShape2D") as CollisionShape2D
	shape_node.position = Vector2.ZERO
	var shape := shape_node.shape as RectangleShape2D
	shape.size = size

func _show_main_menu() -> void:
	_menu_ui = (preload("res://scenes/ui/MainMenuUI.tscn").instantiate() as MainMenuUI)
	_menu_ui.default_scene_path = player_hero_scene.resource_path if player_hero_scene != null else ""
	_menu_ui.hero_selected.connect(_on_hero_selected)
	add_child(_menu_ui)
	print("[Main] main menu shown, default=%s" % _menu_ui.default_scene_path)

func _on_hero_selected(entry: Dictionary) -> void:
	if _menu_ui == null:
		return
	print("[Main] hero selected: %s" % entry["name"])
	_menu_ui.queue_free()
	_menu_ui = null
	_spawn_teams(entry)
	_start_match()

func _spawn_teams(player_entry: Dictionary) -> void:
	var used: Array[int] = [HeroRoster.find_index_by_player_scene(player_entry["player_scene"])]
	var ally_bots: Array[Dictionary] = HeroRoster.random_picks(maxi(team_size - 1, 0), used)
	for entry in ally_bots:
		used.append(HeroRoster.find_index_by_player_scene(entry["player_scene"]))
	var enemy_team: Array[Dictionary] = HeroRoster.random_picks(maxi(team_size, 0), used)

	_spawn_hero(load(player_entry["player_scene"]), $AllySpawn.position, 0, team_size, &"ally", 2, 37, true)
	for slot in range(ally_bots.size()):
		var scene: PackedScene = load(ally_bots[slot]["enemy_scene"])
		_spawn_hero(scene, $AllySpawn.position, slot + 1, team_size, &"ally", 2, 37, false)
	for slot in range(enemy_team.size()):
		var scene: PackedScene = load(enemy_team[slot]["enemy_scene"])
		_spawn_hero(scene, $EnemySpawn.position, slot, team_size, &"enemy", 4, 35, false)
	print("[Main] teams %dv%d -> ally=[%s] enemy=[%s]" % [
		team_size, team_size,
		", ".join(_team_names([player_entry] + ally_bots)),
		", ".join(_team_names(enemy_team)),
	])

func _team_names(entries: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in entries:
		names.append(entry["name"])
	return names

func _spawn_heroes(player_scene: PackedScene, enemy_scene: PackedScene) -> void:
	if player_scene == null:
		return
	_spawn_hero(player_scene, $AllySpawn.position, 0, team_size, &"ally", 2, 37, true)
	for slot in range(1, team_size):
		_spawn_hero(enemy_scene, $AllySpawn.position, slot, team_size, &"ally", 2, 37, false)
	for slot in range(team_size):
		_spawn_hero(enemy_scene, $EnemySpawn.position, slot, team_size, &"enemy", 4, 35, false)

func _spawn_hero(scene: PackedScene, base_position: Vector2, slot: int, count: int, faction: StringName, layer: int, mask: int, is_player: bool) -> CombatUnit:
	if scene == null:
		return null
	var hero := scene.instantiate() as CombatUnit
	hero.faction = faction
	hero.collision_layer = layer
	hero.collision_mask = mask
	hero.spawn_slot_offset = _slot_offset(slot, count)
	hero.global_position = base_position + hero.spawn_slot_offset
	hero.basic_attack_scene = basic_attack_scene
	add_child(hero)
	if is_player:
		player = hero
	return hero

func _slot_offset(slot: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var spread := minf(94.0, 30.0 + 16.0 * float(count - 1))
	var t := float(slot) / float(count - 1)
	return Vector2(0.0, lerpf(-spread, spread, t))

func _start_match() -> void:
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.start_match()

func return_to_main_menu() -> void:
	get_tree().paused = false
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.reset_match()
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var camera := $Camera2D as Camera2D
	var view := get_viewport_rect().size
	var half := arena_size * 0.5
	camera.position = camera.position.lerp(player.global_position, minf(1.0, 8.0 * delta))
	if arena_size.x > view.x:
		camera.position.x = clampf(camera.position.x, -half.x + view.x * 0.5, half.x - view.x * 0.5)
	else:
		camera.position.x = 0.0
	if arena_size.y > view.y:
		camera.position.y = clampf(camera.position.y, -half.y + view.y * 0.5, half.y - view.y * 0.5)
	else:
		camera.position.y = 0.0
