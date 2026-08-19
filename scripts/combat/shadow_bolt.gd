class_name ShadowBolt
extends Projectile


var anchor: Vector2 = Vector2.ZERO
var max_range: float = 260.0

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(anchor) > max_range:
		queue_free()
