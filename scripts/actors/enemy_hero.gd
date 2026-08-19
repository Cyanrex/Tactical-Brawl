class_name EnemyHero
extends Hero

@export var attack_range: float = 70.0
@export var attack_cooldown: float = 1.2

var _attack_ready: bool = true

@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var ai_agent: AIAgent = get_node_or_null("AIAgent") as AIAgent

func _ready() -> void:
	super._ready()
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_finished)

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
	if dash_remaining > 0.0:
		dash_remaining -= delta
		velocity = dash_velocity
		state = UnitState.CAST_SKILL
		move_and_slide()
		if dash_remaining <= 0.0:
			dash_remaining = 0.0
			velocity = Vector2.ZERO
			state = UnitState.IDLE
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
	if is_ranged_basic_attack():
		return get_basic_attack_range()
	return attack_range

func _on_attack_cooldown_finished() -> void:
	_attack_ready = true
