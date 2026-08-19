class_name Minimap
extends Control

const DEFAULT_ARENA_RECT := Rect2(-640.0, -360.0, 1280.0, 720.0)
const COLOR_MAP := Color(0.025, 0.055, 0.09, 1.0)
const COLOR_ROAD := Color(0.08, 0.13, 0.17, 1.0)
const COLOR_GUIDE := Color(0.25, 0.38, 0.44, 0.45)
const COLOR_VIEWPORT := Color(0.72, 0.88, 1.0, 0.75)

var arena_rect := DEFAULT_ARENA_RECT

func _process(_delta: float) -> void:
	if is_inside_tree():
		_refresh_arena_rect()
		queue_redraw()

func _refresh_arena_rect() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("arena_rect"):
		arena_rect = scene.arena_rect()

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var bounds := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	draw_rect(bounds, COLOR_MAP, true)
	var road_top := size.y * 0.2
	var road_height := size.y * 0.6
	draw_rect(Rect2(Vector2(1, road_top), Vector2(size.x - 2, road_height)), COLOR_ROAD, true)
	draw_line(Vector2(1, road_top), Vector2(size.x - 1, road_top), COLOR_GUIDE, 1.0)
	draw_line(Vector2(1, road_top + road_height), Vector2(size.x - 1, road_top + road_height), COLOR_GUIDE, 1.0)
	draw_line(Vector2(1, size.y * 0.5), Vector2(size.x - 1, size.y * 0.5), COLOR_GUIDE, 1.0)
	_draw_lane_ticks()
	_draw_group("structures", 5.0)
	_draw_group("heroes", 4.0)
	_draw_group("troops", 2.5)
	_draw_camera_window()
	draw_rect(bounds, Color(0.45, 0.65, 0.78, 0.7), false, 1.0)

func _draw_lane_ticks() -> void:
	var x := 10.0
	while x < size.x - 10.0:
		draw_line(Vector2(x, size.y * 0.5 - 2.0), Vector2(minf(x + 12.0, size.x - 10.0), size.y * 0.5 - 2.0), COLOR_GUIDE, 1.0)
		x += 28.0

func _draw_group(group: StringName, radius: float) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if not node.visible:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var pos := _world_to_map(node.global_position)
		if pos.x < -radius or pos.y < -radius or pos.x > size.x + radius or pos.y > size.y + radius:
			continue
		var color := Color(0.35, 0.72, 1.0, 1.0) if node.faction == &"ally" else Color(1.0, 0.35, 0.38, 1.0)
		if group == &"structures":
			var structure_radius := 7.0 if node is Tower and node.is_main else radius
			draw_rect(Rect2(pos - Vector2(structure_radius, structure_radius), Vector2(structure_radius * 2.0, structure_radius * 2.0)), color, true)
		else:
			draw_circle(pos, radius, color)

func _draw_camera_window() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var camera := scene.get_node_or_null("Camera2D") as Camera2D
	if camera == null or not camera.is_current():
		return
	var visible_size := BotTactics.camera_view_size(self)
	var top_left := camera.get_screen_center_position() - visible_size * 0.5
	var bottom_right := top_left + visible_size
	var map_top_left := _world_to_map(top_left)
	var map_bottom_right := _world_to_map(bottom_right)
	var window := Rect2(map_top_left, map_bottom_right - map_top_left)
	draw_rect(window, COLOR_VIEWPORT, false, 1.0)

func _world_to_map(world: Vector2) -> Vector2:
	if arena_rect.size.x <= 0.0 or arena_rect.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		(world.x - arena_rect.position.x) / arena_rect.size.x * size.x,
		(world.y - arena_rect.position.y) / arena_rect.size.y * size.y
	)
