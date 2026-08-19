class_name ShadeSnare
extends Area2D


var source: CombatUnit = null
var trigger_radius: float = 42.0
var pull_radius: float = 130.0
var damage_multiplier: float = 1.0
var root_duration: float = 1.2
var lifetime: float = 12.0
var pull_speed: float = 420.0

var _triggered: bool = false
var _victims: Array = []
var _pull_remaining: float = 0.0
var _pulse_time: float = 0.0
var _visual: Polygon2D = null
var _core: Polygon2D = null


func _ready() -> void:
	if source == null:
		queue_free()
		return
	collision_layer = 0
	collision_mask = 4 if source.faction == &"ally" else 2
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var circle := shape_node.shape as CircleShape2D
		if circle != null:
			circle.radius = trigger_radius
	_visual = get_node_or_null("Visual") as Polygon2D
	_core = get_node_or_null("Core") as Polygon2D
	if _visual != null:
		_visual.polygon = _circle_polygon(trigger_radius, 20)
	if _core != null:
		_core.polygon = _circle_polygon(6.0, 12)
	body_entered.connect(_on_body_entered)
	var arm_timer := Timer.new()
	arm_timer.one_shot = true
	arm_timer.wait_time = 0.05
	arm_timer.timeout.connect(_check_overlap)
	add_child(arm_timer)
	arm_timer.start()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if _triggered:
		if _pull_remaining <= 0.0:
			queue_free()
			return
		_pull_remaining -= delta
		for victim in _victims:
			if victim == null or not is_instance_valid(victim):
				continue
			_drag(victim, delta)
		return
	_pulse_time += delta
	if _visual != null:
		_visual.color.a = 0.16 + 0.08 * sin(_pulse_time * 3.0)


func _check_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if _triggered:
			return


func _on_body_entered(target: Node) -> void:
	if _triggered:
		return
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not target.has_method("take_damage"):
		return
	if target is Tower:
		return
	if target.get("faction") == source.faction:
		return
	if target.has_method("is_dead") and target.is_dead():
		return
	_trigger()


func _trigger() -> void:
	_triggered = true
	var damage := source.get_attack() * damage_multiplier
	for group in [&"heroes", &"troops"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get("faction") == source.faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if global_position.distance_to(node.global_position) > pull_radius:
				continue
			if node is CombatUnit:
				var unit := node as CombatUnit
				unit.take_damage(damage, Vector2.ZERO, source)
				unit.apply_root(root_duration)
				_victims.append(unit)
			else:
				node.take_damage(damage)
	_pull_remaining = minf(root_duration, 0.7)
	if _visual != null:
		_visual.color.a = 0.55
	if _core != null:
		_core.color.a = 0.9


func _drag(victim: Node, delta: float) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	if victim.has_method("is_dead") and victim.is_dead():
		return
	if not victim is Node2D:
		return
	var to_center := global_position - (victim as Node2D).global_position
	var dist := to_center.length()
	if dist <= 3.0:
		return
	var step := minf(dist, pull_speed * delta)
	(victim as Node2D).global_position += to_center.normalized() * step


func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
