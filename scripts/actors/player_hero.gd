class_name PlayerHero
extends Hero

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
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("basic_attack"):
		perform_basic_attack(_aim_point(input_dir))
	if Input.is_action_just_pressed("skill_1"):
		try_use_skill(1, _aim_point(input_dir))
	if Input.is_action_just_pressed("skill_2"):
		try_use_skill(2, _aim_point(input_dir))
	if Input.is_action_just_pressed("skill_3"):
		try_use_skill(3, _aim_point(input_dir))
	if Input.is_action_just_pressed("ultimate"):
		try_use_skill(4, _aim_point(input_dir))
	if state in [UnitState.ATTACK, UnitState.CAST_SKILL]:
		velocity = Vector2.ZERO
	else:
		velocity = input_dir * get_move_speed()
		if input_dir != Vector2.ZERO:
			state = UnitState.MOVE
		else:
			state = UnitState.IDLE
		update_facing(input_dir)
	move_and_slide()

func _aim_point(input_dir: Vector2) -> Vector2:
	if input_dir != Vector2.ZERO:
		return global_position + input_dir.normalized() * 1000.0
	return Vector2.INF

func update_facing(input_dir: Vector2) -> void:
	if input_dir.x > 0.0:
		facing_direction = 1
	elif input_dir.x < 0.0:
		facing_direction = -1
