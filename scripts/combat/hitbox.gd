class_name AttackHitbox
extends Area2D

signal hit_landed(target: Node, damage: float)

@export var damage_multiplier: float = 1.0
@export var lifetime: float = 0.2
@export var knockback_strength: float = 0.0

var source: CombatUnit = null
var can_damage_towers: bool = false
var direction: int = 1
var aim_direction: Vector2 = Vector2.ZERO
var hit_targets: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(target: Node) -> void:
	try_hit(target)

func try_hit(target: Node) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead():
		return
	if not target.has_method("take_damage"):
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
	var damage := source.get_attack() * damage_multiplier
	var knockback := get_knockback_vector(target)
	var unit := target as CombatUnit
	if unit != null:
		unit.take_damage(damage, knockback, source)
	elif target is Tower:
		(target as Tower).take_damage(damage, knockback, can_damage_towers)
	else:
		target.take_damage(damage, knockback)
	if source.lifesteal_fraction > 0.0:
		source.ai_regenerate(damage * source.lifesteal_fraction)
	hit_landed.emit(target, damage)

func get_knockback_vector(_target: Node) -> Vector2:
	if not aim_direction.is_zero_approx():
		return aim_direction * knockback_strength
	return Vector2(direction * knockback_strength, 0.0)
