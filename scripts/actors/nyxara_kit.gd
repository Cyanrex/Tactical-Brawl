class_name NyxaraKit
extends HeroKit


const BALL_SCENE := preload("res://scenes/combat/projectiles/VoidBall.tscn")
const SPIKE_SCENE := preload("res://scenes/combat/projectiles/VoidSpike.tscn")

const DASH_SPEED := 950.0
const RECAST_WINDOW := 3.5
const EXPLOSION_RADIUS := 170.0
const SPIKE_COUNT := 3
const SPIKE_ORBIT_RADIUS := 62.0
const SPIKE_ATTACK_INTERVAL := 1.0
const SPIKE_BOLT_SPEED := 620.0
const SPIKE_DRAIN_PER_SECOND := 0.015
const SPIKE_ALLY_BUFF_PER_STACK := 0.05
const SPIKE_ALLY_BUFF_MAX_STACKS := 5
const LINK_MAX_ALLIES := 2
const LINK_ALLY_DAMAGE_MULTIPLIER := 1.25
const LINK_ALLY_CDR := 0.2
const LINK_SELF_DAMAGE_MULTIPLIER := 0.6
const ULT_INCOMING_DAMAGE_FACTOR := 0.25
const ULT_REFLECT_FACTOR := 0.6

var _anchor: VoidAnchor = null
var _anchor_expire_timer: Timer = null

var _spikes_active: bool = false
var _spikes: Array[VoidSpike] = []
var _drain_timer: Timer = null
var _buff_tick_timer: Timer = null
var _ally_buffs: Dictionary = {}

var _link_active: bool = false
var _links: Dictionary = {}
var _link_tick_timer: Timer = null

var _ball: VoidBall = null

func _init(owner_hero: Hero) -> void:
	super(owner_hero)
	_anchor_expire_timer = Timer.new()
	_anchor_expire_timer.one_shot = true
	_anchor_expire_timer.wait_time = RECAST_WINDOW
	_anchor_expire_timer.timeout.connect(_on_anchor_expired)
	hero.add_child(_anchor_expire_timer)
	_drain_timer = Timer.new()
	_drain_timer.wait_time = 0.5
	_drain_timer.timeout.connect(_on_drain_tick)
	hero.add_child(_drain_timer)
	_buff_tick_timer = Timer.new()
	_buff_tick_timer.wait_time = 1.0
	_buff_tick_timer.timeout.connect(_on_buff_tick)
	hero.add_child(_buff_tick_timer)
	_link_tick_timer = Timer.new()
	_link_tick_timer.wait_time = 0.5
	_link_tick_timer.timeout.connect(_on_link_tick)
	hero.add_child(_link_tick_timer)
	hero.died.connect(_on_hero_died)

func cast_skill(skill: SkillData, _aim_position: Vector2 = Vector2.INF) -> bool:
	match skill.skill_type:
		SkillData.SkillType.DASH:
			_void_shift(skill)
			return true
		SkillData.SkillType.TOGGLE:
			if skill.skill_name == &"void_spikes":
				_set_spikes_active(true)
			elif skill.skill_name == &"void_link":
				_set_link_active(true)
			return true
		SkillData.SkillType.VOID_BALL:
			_void_ball(skill)
			return true
	return false

func try_recast(slot: int) -> bool:
	match slot:
		1:
			if _anchor != null and is_instance_valid(_anchor) and not _anchor.is_exploded():
				_anchor.explode(true)
				_anchor = null
				_anchor_expire_timer.stop()
				return true
		2:
			if _spikes_active:
				_set_spikes_active(false)
				return true
		3:
			if _link_active:
				_set_link_active(false)
				return true
	return false

func ai_manage_toggles() -> void:
	if hero.is_match_over() or hero.state == CombatUnit.UnitState.DEAD:
		return
	if _any_visible_enemy():
		_ai_toggle_on(2)
	else:
		_set_spikes_active(false)
	var link_range := _skill_range(3, 480.0)
	if not _visible_allies(link_range).is_empty():
		_ai_toggle_on(3)
	else:
		_set_link_active(false)

func _ai_toggle_on(slot: int) -> void:
	if slot == 2 and _spikes_active:
		return
	if slot == 3 and _link_active:
		return
	var skill := hero.get_skill(slot)
	if skill == null or hero.level < skill.unlock_level:
		return
	var timer := hero.get_skill_timer(slot)
	if timer == null or not timer.is_stopped():
		return
	hero.try_use_skill(slot)

func _any_visible_enemy() -> bool:
	for group in [&"heroes", &"troops"]:
		for node in hero.get_tree().get_nodes_in_group(group):
			if node.get("faction") == hero.faction:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			if BotTactics.can_see(hero, node):
				return true
	return false


func _void_shift(skill: SkillData) -> void:
	_clear_anchor()
	var dir := _dash_direction()
	hero.facing_direction = 1 if dir.x >= 0.0 else -1
	var anchor := VoidAnchor.new()
	anchor.hero = hero
	anchor.damage_multiplier = skill.damage_multiplier
	anchor.explosion_radius = EXPLOSION_RADIUS
	anchor.knockback_strength = skill.knockback
	anchor.global_position = hero.global_position
	hero.get_tree().current_scene.add_child(anchor)
	_anchor = anchor
	_anchor_expire_timer.start()
	hero.start_dash(dir.normalized(), DASH_SPEED, skill.range / DASH_SPEED)

func _on_anchor_expired() -> void:
	if _anchor != null and is_instance_valid(_anchor) and not _anchor.is_exploded():
		_anchor.explode(false)
	_anchor = null

func _clear_anchor() -> void:
	if _anchor != null and is_instance_valid(_anchor) and not _anchor.is_exploded():
		_anchor.queue_free()
	_anchor = null
	_anchor_expire_timer.stop()

func _dash_direction() -> Vector2:
	if hero is PlayerHero:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir != Vector2.ZERO:
			return input_dir
	var target := BotTactics.pick_target(hero, 9999.0) as Node2D
	if target != null:
		return hero.global_position.direction_to(target.global_position)
	return Vector2(hero.facing_direction, 0.0)


func _set_spikes_active(active: bool) -> void:
	if active == _spikes_active:
		return
	_spikes_active = active
	if active:
		for i in SPIKE_COUNT:
			var spike: VoidSpike = SPIKE_SCENE.instantiate()
			spike.hero = hero
			spike.orbit_angle = i * TAU / SPIKE_COUNT
			spike.orbit_radius = SPIKE_ORBIT_RADIUS
			spike.attack_interval = SPIKE_ATTACK_INTERVAL
			spike.bolt_damage_multiplier = _skill_damage(2, 1.0)
			spike.bolt_speed = SPIKE_BOLT_SPEED
			spike.stagger = i * SPIKE_ATTACK_INTERVAL / SPIKE_COUNT
			hero.add_child(spike)
			_spikes.append(spike)
		_drain_timer.start()
		_buff_tick_timer.start()
		_on_buff_tick()
	else:
		for spike in _spikes.duplicate():
			if is_instance_valid(spike):
				(spike as VoidSpike).queue_free()
		_spikes.clear()
		_drain_timer.stop()
		_buff_tick_timer.stop()
		_clear_ally_buffs()

func _on_drain_tick() -> void:
	if not _spikes_active or hero.is_match_over() or hero.is_dead():
		return
	var drain := hero.max_hp * SPIKE_DRAIN_PER_SECOND * _drain_timer.wait_time
	var previous := hero.hp
	hero.hp = maxf(hero.hp - drain, 1.0)
	if hero.hp != previous:
		hero.health_changed.emit(hero.hp, hero.max_hp)
	if hero.hp <= 1.0:
		_set_spikes_active(false)

func _on_buff_tick() -> void:
	if not _spikes_active:
		return
	var buff_range := _skill_range(2, 480.0)
	var visible := _visible_allies(buff_range)
	var visible_ids := {}
	for ally in visible:
		visible_ids[ally.get_instance_id()] = true
	for id in _ally_buffs.keys():
		if visible_ids.has(id):
			continue
		var entry: Dictionary = _ally_buffs[id]
		var ally = entry.get("ally")
		if is_instance_valid(ally) and ally is CombatUnit:
			(ally as CombatUnit).damage_dealt_multiplier /= _buff_factor(entry.get("stacks", 0))
		_ally_buffs.erase(id)
	for ally in visible:
		var id := ally.get_instance_id()
		var entry: Dictionary = _ally_buffs.get(id, {})
		var old_stacks: int = entry.get("stacks", 0)
		var new_stacks := mini(old_stacks + 1, SPIKE_ALLY_BUFF_MAX_STACKS)
		if new_stacks > old_stacks:
			ally.damage_dealt_multiplier *= _buff_factor(new_stacks) / _buff_factor(old_stacks)
		_ally_buffs[id] = {"ally": ally, "stacks": new_stacks}

func _buff_factor(stacks: int) -> float:
	return 1.0 + SPIKE_ALLY_BUFF_PER_STACK * stacks

func _clear_ally_buffs() -> void:
	for id in _ally_buffs.keys():
		var entry: Dictionary = _ally_buffs[id]
		var ally = entry.get("ally")
		if is_instance_valid(ally) and ally is CombatUnit:
			(ally as CombatUnit).damage_dealt_multiplier /= _buff_factor(entry.get("stacks", 0))
	_ally_buffs.clear()


func _set_link_active(active: bool) -> void:
	if active == _link_active:
		return
	_link_active = active
	if active:
		hero.damage_dealt_multiplier *= LINK_SELF_DAMAGE_MULTIPLIER
		_link_tick_timer.start()
		_on_link_tick()
	else:
		hero.damage_dealt_multiplier /= LINK_SELF_DAMAGE_MULTIPLIER
		_link_tick_timer.stop()
		_clear_links()

func _on_link_tick() -> void:
	if not _link_active:
		return
	for id in _links.keys():
		var link = _links[id]
		if not (is_instance_valid(link) and link is VoidLink):
			_links.erase(id)
	var link_range := _skill_range(3, 480.0)
	var allies := _visible_allies(link_range)
	if allies.is_empty():
		return
	for ally in allies:
		if _links.size() >= LINK_MAX_ALLIES:
			break
		var id := ally.get_instance_id()
		if _links.has(id):
			continue
		var link := VoidLink.new()
		link.hero = hero
		link.ally = ally
		link.damage_multiplier = LINK_ALLY_DAMAGE_MULTIPLIER
		link.cdr_fraction = LINK_ALLY_CDR
		hero.get_tree().current_scene.add_child(link)
		_links[id] = link

func _clear_links() -> void:
	for id in _links.keys():
		var link = _links[id]
		if is_instance_valid(link) and link is VoidLink:
			(link as VoidLink).queue_free()
	_links.clear()


func _void_ball(skill: SkillData) -> void:
	if _ball != null and is_instance_valid(_ball):
		_ball.queue_free()
		_ball = null
	var ball: VoidBall = BALL_SCENE.instantiate()
	ball.hero = hero
	ball.duration = skill.lifetime
	ball.tether_range = skill.range
	ball.damage_reduction_factor = ULT_INCOMING_DAMAGE_FACTOR
	ball.reflect_factor = ULT_REFLECT_FACTOR
	ball.global_position = hero.attack_origin.global_position
	hero.get_tree().current_scene.add_child(ball)
	_ball = ball


func _visible_allies(max_distance: float) -> Array[Hero]:
	var allies: Array[Hero] = []
	for node in hero.get_tree().get_nodes_in_group(&"heroes"):
		if node == hero or not node is Hero:
			continue
		var ally := node as Hero
		if ally.faction != hero.faction:
			continue
		if ally.is_dead():
			continue
		if not BotTactics.can_see(hero, ally):
			continue
		if hero.global_position.distance_to(ally.global_position) > max_distance:
			continue
		allies.append(ally)
	allies.sort_custom(func(a: Hero, b: Hero) -> bool:
		return hero.global_position.distance_to(a.global_position) < hero.global_position.distance_to(b.global_position))
	return allies

func _skill_range(slot: int, fallback: float) -> float:
	var skill := hero.get_skill(slot)
	return skill.range if skill != null and skill.range > 0.0 else fallback

func _skill_damage(slot: int, fallback: float) -> float:
	var skill := hero.get_skill(slot)
	return skill.damage_multiplier if skill != null else fallback

func _on_hero_died(_unit: CombatUnit) -> void:
	_set_spikes_active(false)
	_set_link_active(false)
	_clear_anchor()
	if _ball != null and is_instance_valid(_ball):
		_ball.queue_free()
	_ball = null

func reset_respawn_effects() -> void:
	if _spikes_active:
		_set_spikes_active(false)
	else:
		_clear_ally_buffs()
	if _link_active:
		_set_link_active(false)
	else:
		_clear_links()
	_clear_anchor()
	if _ball != null and is_instance_valid(_ball):
		_ball.queue_free()
	_ball = null
