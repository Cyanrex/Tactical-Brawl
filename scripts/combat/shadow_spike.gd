class_name ShadowSpike
extends Projectile


var root_duration: float = 1.2

func try_hit(target: Node) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not target.has_method("take_damage"):
		queue_free()
		return
	if target is Tower and not can_damage_towers:
		return
	if target.get("faction") == source.faction:
		return
	if target.has_method("is_dead") and target.is_dead():
		return
	var id := target.get_instance_id()
	if hit_targets.has(id):
		return
	hit_targets[id] = true
	var unit := target as CombatUnit
	if unit != null:
		unit.take_damage(damage, direction * knockback_strength, source)
		if unit.has_method("apply_root"):
			unit.apply_root(root_duration)
	elif target is Tower:
		(target as Tower).take_damage(damage, direction * knockback_strength, can_damage_towers)
	else:
		target.take_damage(damage, direction * knockback_strength)
	projectile_hit.emit(target)
	queue_free()
