class_name CloneUnit
extends Troop

@export var lifespan: float = 10.0
@export var body_color: Color = Color(0.55, 0.75, 0.55)

func _ready() -> void:
	super._ready()
	if faction == &"enemy":
		collision_layer = 4
		collision_mask = 65
	else:
		collision_layer = 2
		collision_mask = 33
	var body := get_node_or_null("Body") as Polygon2D
	if body != null:
		body.color = body_color
	var sprite := get_node_or_null("MinionSprite") as Sprite2D
	if sprite != null:
		sprite.modulate = body_color
	get_tree().create_timer(lifespan).timeout.connect(queue_free)
