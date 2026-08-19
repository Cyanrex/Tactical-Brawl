class_name BlastMine
extends Area2D


var source: CombatUnit = null
var damage_multiplier: float = 0.9
var knockback_strength: float = 160.0
var blast_radius: float = 70.0
var lifetime: float = 20.0

var _exploded: bool = false
var _pulse_time: float = 0.0
var _visual: Polygon2D = null


func _ready() -> void:
	if source == null:
		queue_free()
		return
	collision_layer = 0
	collision_mask = 4 if source.faction == &"ally" else 2
	body_entered.connect(_on_body_entered)
	_visual = get_node_or_null("Visual") as Polygon2D
	var arm_timer := Timer.new()
	arm_timer.one_shot = true
	arm_timer.wait_time = 0.05
	arm_timer.timeout.connect(_check_overlap)
	add_child(arm_timer)
	arm_timer.start()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_pulse_time += delta
	if _visual != null:
		_visual.color.a = 0.05 + 0.04 * sin(_pulse_time * 5.0)


func _check_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if _exploded:
			return


func _on_body_entered(target: Node) -> void:
	if _exploded:
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
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var damage := source.get_attack() * damage_multiplier
	for group in [&"heroes", &"troops"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.get("faction") == source.faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if global_position.distance_to(node.global_position) > blast_radius:
				continue
			var dir: Vector2 = (node.global_position - global_position).normalized()
			if dir.length_squared() < 0.0001:
				dir = Vector2.UP
			if node is CombatUnit:
				(node as CombatUnit).take_damage(damage, dir * knockback_strength, source)
			else:
				node.take_damage(damage)
	queue_free()
