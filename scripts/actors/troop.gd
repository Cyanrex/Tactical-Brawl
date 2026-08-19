class_name Troop
extends CombatUnit

const MINION_TEXTURE := preload("res://resources/assets/minions/minion.png")

@export var attack_range: float = 55.0
@export var attack_cooldown: float = 1.5

var _attack_ready: bool = true

@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var ai_agent: AIAgent = get_node_or_null("AIAgent") as AIAgent

func _ready() -> void:
	super._ready()
	_setup_minion_sprite()
	add_to_group("troops")
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_finished)

func _setup_minion_sprite() -> void:
	var body := get_node_or_null("Body") as Polygon2D
	if body != null:
		body.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "MinionSprite"
	sprite.texture = MINION_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.09, 0.09)
	sprite.modulate = Color(0.78, 0.92, 1.0, 1.0) if faction == &"ally" else Color(1.0, 0.75, 0.75, 1.0)
	add_child(sprite)

func perform_basic_attack(aim_position: Vector2 = Vector2.INF) -> bool:
	if not _attack_ready:
		return false
	var did_attack := super.perform_basic_attack(aim_position)
	if did_attack:
		_attack_ready = false
		attack_cooldown_timer.start(attack_cooldown)
	return did_attack

func _physics_process(delta: float) -> void:
	if is_match_over():
		velocity = Vector2.ZERO
		state = UnitState.IDLE
		move_and_slide()
		return
	if state in [UnitState.STUNNED, UnitState.DEAD]:
		super._physics_process(delta)
		return
	if state in [UnitState.ATTACK, UnitState.CAST_SKILL]:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if ai_agent != null:
		ai_agent.physics_tick(delta)
	else:
		velocity = Vector2.ZERO
		state = UnitState.IDLE
	move_and_slide()

func get_ai_attack_range() -> float:
	if basic_attack_range > 0.0:
		return basic_attack_range
	return attack_range

func die() -> void:
	super.die()
	queue_free()

func _on_attack_cooldown_finished() -> void:
	_attack_ready = true
