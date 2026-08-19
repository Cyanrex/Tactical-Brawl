class_name BotTactics
extends RefCounted

const STRUCTURE_COLLISION_MASK := 32 | 64
const SPAWN_SAFE_RADIUS := 200.0
const DEFAULT_TARGET_ORDER := [&"heroes", &"troops", &"structures"]
const DEFAULT_VISION_SIZE := Vector2(1152.0, 648.0)

static func camera_view_size(node: Node) -> Vector2:
	var viewport := node.get_viewport()
	var visible_size := DEFAULT_VISION_SIZE
	if viewport != null:
		visible_size = viewport.get_visible_rect().size
	var scene := node.get_tree().current_scene
	var camera: Camera2D = null
	if scene != null:
		camera = scene.get_node_or_null("Camera2D") as Camera2D
	if camera != null and camera.is_current() and camera.zoom.x > 0.0 and camera.zoom.y > 0.0:
		visible_size /= camera.zoom
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return DEFAULT_VISION_SIZE
	return visible_size

static func vision_rect(unit: CombatUnit) -> Rect2:
	var view_size := camera_view_size(unit)
	return Rect2(unit.global_position - view_size * 0.5, view_size)

static func can_see(unit: CombatUnit, target) -> bool:
	if target == null or not is_instance_valid(target) or not target is Node2D:
		return false
	return vision_rect(unit).has_point((target as Node2D).global_position)

static func pick_target(
		unit: CombatUnit,
		hero_priority_range: float,
		target_order: Array = DEFAULT_TARGET_ORDER,
		aggro_range: float = -1.0,
		skip_spawn_heroes: bool = true,
	) -> Node:
	for group in target_order:
		var group_name := StringName(group)
		if group_name == &"heroes":
			var hero_range := hero_priority_range
			if aggro_range >= 0.0:
				hero_range = minf(hero_range, aggro_range)
			var hero := (
				nearest_enemy_hero(unit, hero_range)
				if skip_spawn_heroes
				else nearest_enemy_of_type(unit, &"heroes", hero_range)
			)
			if hero != null:
				return hero
		else:
			var candidate := nearest_enemy_of_type(unit, group_name, aggro_range)
			if candidate != null:
				return candidate
	return null

static func _obstacle_escape(unit: CombatUnit, point: Vector2) -> Vector2:
	var scene := unit.get_tree().current_scene
	var arena: Rect2 = scene.arena_rect() if scene.has_method("arena_rect") else Rect2(-640.0, -360.0, 1280.0, 720.0)
	var margin := 60.0
	var can_up: bool = unit.global_position.y - margin >= arena.position.y
	var can_down: bool = unit.global_position.y + margin <= arena.end.y
	if can_up and not can_down:
		return Vector2.UP
	if can_down and not can_up:
		return Vector2.DOWN
	return Vector2.UP if point.y >= unit.global_position.y else Vector2.DOWN

static func nearest_enemy_hero(unit: CombatUnit, hero_priority_range: float) -> Node:
	var best: Node = null
	var best_distance := hero_priority_range
	for node in unit.get_tree().get_nodes_in_group(&"heroes"):
		if not is_instance_valid(node):
			continue
		if node.get("faction") == unit.faction:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if not can_see(unit, node):
			continue
		if is_at_own_spawn(node):
			continue
		var distance := unit.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = node
	return best

static func is_at_own_spawn(hero: Node) -> bool:
	var mm := hero.get_tree().root.get_node_or_null("MatchManager")
	if mm == null:
		return false
	var own_spawn: Vector2 = mm.ally_spawn_point if hero.faction == &"ally" else mm.enemy_spawn_point
	return hero.global_position.distance_to(own_spawn) <= SPAWN_SAFE_RADIUS

static func nearest_enemy_of_type(unit: CombatUnit, group: StringName, max_distance: float = -1.0) -> Node:
	var best: Node = null
	var best_distance := INF if max_distance < 0.0 else max_distance
	for node in unit.get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node):
			continue
		if node.get("faction") == unit.faction:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if not can_see(unit, node):
			continue
		var distance := unit.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

static func own_main_tower(unit: CombatUnit) -> Tower:
	for node in unit.get_tree().get_nodes_in_group(&"structures"):
		if not is_instance_valid(node) or not node is Tower:
			continue
		var tower := node as Tower
		if tower.faction == unit.faction and tower.is_main and not tower.is_dead():
			return tower
	return null

static func nearest_enemy_near_point(
		unit: CombatUnit,
		point: Vector2,
		max_distance: float,
		groups: Array = [&"heroes", &"troops"],
	) -> Node:
	var best: Node = null
	var best_distance := max_distance
	for group in groups:
		for node in unit.get_tree().get_nodes_in_group(StringName(group)):
			if not is_instance_valid(node) or node == unit:
				continue
			if node.get("faction") == unit.faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			var distance := point.distance_to(node.global_position)
			if distance <= best_distance:
				best_distance = distance
				best = node
	return best

static func nearby_enemy_hero_count(unit: CombatUnit, max_distance: float) -> int:
	var count := 0
	for node in unit.get_tree().get_nodes_in_group(&"heroes"):
		if not is_instance_valid(node) or node == unit:
			continue
		if node.get("faction") == unit.faction:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if is_at_own_spawn(node):
			continue
		if not can_see(unit, node):
			continue
		if unit.global_position.distance_to(node.global_position) <= max_distance:
			count += 1
	return count

static func nearby_ally_hero_count(unit: CombatUnit, max_distance: float) -> int:
	var count := 0
	for node in unit.get_tree().get_nodes_in_group(&"heroes"):
		if not is_instance_valid(node) or node == unit:
			continue
		if node.get("faction") != unit.faction:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if not can_see(unit, node):
			continue
		if unit.global_position.distance_to(node.global_position) <= max_distance:
			count += 1
	return count

static func team_help_target(unit: CombatUnit, max_distance: float) -> Node:
	var best: Node = null
	var best_distance := max_distance
	for ally in unit.get_tree().get_nodes_in_group(&"heroes"):
		if not is_instance_valid(ally) or ally == unit:
			continue
		if ally.get("faction") != unit.faction:
			continue
		if ally.has_method("is_dead") and ally.is_dead():
			continue
		if not can_see(unit, ally):
			continue
		var ally_distance := unit.global_position.distance_to(ally.global_position)
		if ally_distance > max_distance:
			continue
		var enemy := _hero_engagement_target(ally, max_distance)
		if enemy == null:
			continue
		if ally_distance <= best_distance:
			best_distance = ally_distance
			best = enemy
	return best

static func _hero_engagement_target(hero: Node, max_distance: float) -> Node:
	var recent_attacker: Variant = hero.get("last_hit_source")
	if _is_live_enemy_hero(hero, recent_attacker, max_distance):
		return recent_attacker
	for controller_path in [NodePath("AIAgent"), NodePath("TestBot")]:
		var controller := hero.get_node_or_null(controller_path)
		if controller == null:
			continue
		var candidate: Variant = controller.get("target")
		if _is_live_enemy_hero(hero, candidate, max_distance):
			return candidate
	return null

static func _is_live_enemy_hero(hero: Node, candidate: Variant, max_distance: float) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate is Hero:
		return false
	if candidate.get("faction") == hero.get("faction"):
		return false
	if candidate.has_method("is_dead") and candidate.is_dead():
		return false
	if is_at_own_spawn(candidate):
		return false
	return hero.global_position.distance_to(candidate.global_position) <= max_distance

static func team_baiter(unit: CombatUnit, max_distance: float) -> Node:
	var candidates: Array[Node] = [unit]
	for node in unit.get_tree().get_nodes_in_group(&"heroes"):
		if not is_instance_valid(node) or node == unit:
			continue
		if node.get("faction") != unit.faction:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if not can_see(unit, node):
			continue
		if unit.global_position.distance_to(node.global_position) <= max_distance:
			candidates.append(node)
	var ranged: Node = null
	for candidate in candidates:
		if candidate is CombatUnit and (candidate as CombatUnit).is_ranged_basic_attack():
			if ranged == null or candidate.get_instance_id() < ranged.get_instance_id():
				ranged = candidate
	if ranged != null:
		return ranged
	var result: Node = unit
	for candidate in candidates:
		if candidate.get_instance_id() < result.get_instance_id():
			result = candidate
	return result

static func steer_toward(unit: CombatUnit, target: Node) -> Vector2:
	var exclude: Array = []
	if target is Tower:
		exclude = [target.get_rid()]
	return _steer(unit, target.global_position, exclude)

static func steer_toward_point(unit: CombatUnit, point: Vector2) -> Vector2:
	return _steer(unit, point, [])

static func _steer(unit: CombatUnit, point: Vector2, exclude: Array) -> Vector2:
	var dir: Vector2 = (point - unit.global_position).normalized()
	var escape := _obstacle_escape(unit, point)
	var space := unit.get_world_2d().direct_space_state
	var half_y := _body_half_y(unit)
	var origin := unit.global_position - escape * half_y
	var query := PhysicsRayQueryParameters2D.create(origin, point, STRUCTURE_COLLISION_MASK)
	if not exclude.is_empty():
		query.exclude = exclude
	if space.intersect_ray(query).is_empty():
		return dir
	return (dir + escape * 1.1).normalized()

static func _body_half_y(unit: CombatUnit) -> float:
	var shape_node := unit.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size.y * 0.5
	return 12.0
