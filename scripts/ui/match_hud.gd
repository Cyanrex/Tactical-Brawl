class_name MatchHUD
extends CanvasLayer

const COLOR_INK := Color(0.035, 0.055, 0.09, 0.97)
const COLOR_PANEL := Color(0.055, 0.085, 0.13, 0.96)
const COLOR_PANEL_ALT := Color(0.075, 0.11, 0.16, 0.96)
const COLOR_BORDER := Color(0.25, 0.36, 0.48, 0.8)
const COLOR_TEXT := Color(0.91, 0.95, 1.0, 1.0)
const COLOR_MUTED := Color(0.55, 0.64, 0.73, 1.0)
const COLOR_ALLY := Color(0.27, 0.68, 1.0, 1.0)
const COLOR_ENEMY := Color(1.0, 0.35, 0.35, 1.0)
const COLOR_HP := Color(0.2, 0.84, 0.43, 1.0)
const COLOR_EXP := Color(0.61, 0.42, 1.0, 1.0)
const COLOR_ACCENT := Color(1.0, 0.72, 0.2, 1.0)
const REFERENCE_VIEWPORT := Vector2(1152.0, 648.0)
const KILL_ICON_TEXTURE := preload("res://art/scithersword.png")
const DEATH_ICON_TEXTURE := preload("res://art/pixelart_skull.png")

var player: PlayerHero = null

var _root: Control
var ui_scale: float = 1.0
var hero_name_label: Label
var hero_role_label: Label
var hp_bar: HudBar
var hp_value_label: Label
var exp_bar: HudBar
var exp_value_label: Label
var level_label: Label
var timer_label: Label
var player_kills_label: Label
var player_deaths_label: Label
var center_label: Label
var result_panel: Panel
var minimap: Minimap
var pause_overlay: Control
var result_hint_label: Label
var result_table: GridContainer

var _skill_buttons: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null:
		mm.victory_triggered.connect(_show_victory)
		mm.defeat_triggered.connect(_show_defeat)
		mm.match_time_changed.connect(_on_match_time_changed)

func _process(_delta: float) -> void:
	if player == null:
		player = _find_player()
		if player == null:
			return
		_connect_player()
	_update_skill_buttons()

func _find_player() -> PlayerHero:
	for node in get_tree().get_nodes_in_group("heroes"):
		if node is PlayerHero:
			return node
	return null

func _connect_player() -> void:
	if player == null:
		return
	player.health_changed.connect(_on_health_changed)
	player.exp_changed.connect(_on_exp_changed)
	player.leveled_up.connect(_on_leveled_up)
	player.stats_changed.connect(_on_player_stats_changed)
	var hero_name := player.name.replace("Player", "").to_upper()
	var role := ""
	match int(player.role):
		Hero.ROLE_FIGHTER_TANK:
			role = "FRONTLINE BRAWLER"
		Hero.ROLE_ASSASSIN:
			role = "ASSASSIN"
		Hero.ROLE_MAGE:
			role = "MAGE"
		Hero.ROLE_SUPPORT:
			role = "SUPPORT"
	hero_name_label.text = hero_name
	hero_role_label.text = role
	_on_health_changed(player.hp, player.max_hp)
	_on_exp_changed(player.exp, player.exp_required_for_next_level(), player.level)
	_on_leveled_up(player.level)
	_on_player_stats_changed(player.kill_count, player.death_count, player.minion_kill_count)

func _build_hud() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.size = REFERENCE_VIEWPORT
	_root.custom_minimum_size = Vector2.ZERO
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	_build_hero_panel()
	_build_match_panel()
	_build_minimap_panel()
	_build_score_panel()
	_build_action_bar()
	_build_result_panel()
	_build_pause_overlay()
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_apply_ui_scale(get_viewport().get_visible_rect().size)

func _apply_ui_scale(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	ui_scale = minf(viewport_size.x / REFERENCE_VIEWPORT.x, viewport_size.y / REFERENCE_VIEWPORT.y)
	var design_size := viewport_size / ui_scale
	_root.custom_minimum_size = Vector2.ZERO
	_root.size = design_size
	_root.scale = Vector2.ONE * ui_scale
	_root.position = Vector2.ZERO
	if timer_label != null:
		timer_label.position = Vector2((design_size.x - timer_label.size.x) * 0.5, 21)
	if pause_overlay != null:
		pause_overlay.size = design_size

func _build_hero_panel() -> void:
	var panel := _make_panel("HeroStatusPanel", Vector2(330, 104), COLOR_PANEL)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(18, 16)
	_root.add_child(panel)
	_make_pause_region(panel)

	hero_name_label = _make_label(panel, "HeroName", "SELECTING...", Vector2(16, 10), Vector2(175, 24), 20, COLOR_TEXT)
	hero_role_label = _make_label(panel, "HeroRole", "FRONTLINE BRAWLER", Vector2(16, 33), Vector2(210, 16), 10, COLOR_MUTED)
	level_label = _make_label(panel, "Level", "LV 1", Vector2(250, 13), Vector2(66, 22), 16, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)

	hp_bar = _make_bar(panel, "HealthBar", Vector2(16, 55), Vector2(298, 18), COLOR_HP)
	hp_value_label = _make_label(panel, "HealthValue", "100 / 100", Vector2(16, 55), Vector2(298, 18), 11, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	exp_bar = _make_bar(panel, "ExperienceBar", Vector2(16, 80), Vector2(298, 8), COLOR_EXP)
	exp_value_label = _make_label(panel, "ExperienceValue", "0 / 100 XP", Vector2(16, 88), Vector2(180, 16), 10, COLOR_MUTED)

func _build_match_panel() -> void:
	timer_label = _make_label(_root, "MatchTimer", "00:00", Vector2.ZERO, Vector2(260, 48), 26, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)

func _build_minimap_panel() -> void:
	var panel := _make_panel("MapPanel", Vector2(286, 164), COLOR_PANEL)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-304, 16)
	_root.add_child(panel)
	_make_pause_region(panel)
	minimap = Minimap.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(12, 8)
	minimap.size = Vector2(262, 148)
	minimap.custom_minimum_size = minimap.size
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(minimap)

func _build_score_panel() -> void:
	var panel := _make_panel("PlayerStatsPanel", Vector2(286, 72), COLOR_PANEL_ALT)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-304, 190)
	_root.add_child(panel)
	_make_icon(panel, "KillIcon", KILL_ICON_TEXTURE, Vector2(18, 7), Vector2(38, 38))
	player_kills_label = _make_label(panel, "PlayerKills", "00", Vector2(62, 9), Vector2(46, 28), 20, COLOR_ALLY, HORIZONTAL_ALIGNMENT_CENTER)
	_make_icon(panel, "DeathIcon", DEATH_ICON_TEXTURE, Vector2(164, 7), Vector2(38, 38))
	player_deaths_label = _make_label(panel, "PlayerDeaths", "00", Vector2(208, 9), Vector2(46, 28), 20, COLOR_ENEMY, HORIZONTAL_ALIGNMENT_CENTER)

func _build_action_bar() -> void:
	var panel := _make_panel("ActionBarPanel", Vector2(510, 104), COLOR_PANEL)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-528, -122)
	_root.add_child(panel)
	_make_label(panel, "ActionBarTitle", "ACTION BAR", Vector2(14, 8), Vector2(110, 14), 9, COLOR_MUTED)
	var row := HBoxContainer.new()
	row.name = "ActionButtons"
	row.position = Vector2(14, 27)
	row.size = Vector2(482, 66)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(row)

	_skill_buttons.append(_make_skill_button(row, "BasicAttackButton", "BASIC", "J", Color(0.18, 0.38, 0.62, 1.0), 0, Vector2(76, 66)))
	for slot in range(1, 5):
		_skill_buttons.append(_make_skill_button(row, "SkillButton%d" % slot, "SKILL %d" % slot, ["K", "L", "U", "I"][slot - 1], Color(0.22, 0.29, 0.42, 1.0), slot, Vector2(92, 66)))
func _build_result_panel() -> void:
	result_panel = _make_panel("MatchResultPanel", Vector2(780, 540), COLOR_INK, 16, 2)
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.position = Vector2(-390, -270)
	result_panel.visible = false
	_root.add_child(result_panel)
	center_label = _make_label(result_panel, "ResultLabel", "", Vector2(0, 18), Vector2(780, 42), 34, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	result_hint_label = _make_label(result_panel, "ResultHint", "PLAYER / BOT STATS", Vector2(0, 59), Vector2(780, 18), 10, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	result_table = GridContainer.new()
	result_table.name = "ResultTable"
	result_table.columns = 7
	result_table.position = Vector2(28, 88)
	result_table.size = Vector2(724, 420)
	result_table.add_theme_constant_override("h_separation", 6)
	result_table.add_theme_constant_override("v_separation", 5)
	result_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(result_table)
	var exit_button := _make_exit_button(result_panel)
	exit_button.pressed.connect(_on_exit_button_pressed)
	_build_result_table()

func _build_result_table() -> void:
	if result_table == null:
		return
	for child in result_table.get_children():
		child.free()
	for header in [
		{"text":"PLAYER / BOT", "size":Vector2(300, 30), "align":HORIZONTAL_ALIGNMENT_LEFT},
		{"text":"KILLS", "size":Vector2(64, 30), "align":HORIZONTAL_ALIGNMENT_CENTER},
		{"text":"DEATHS", "size":Vector2(70, 30), "align":HORIZONTAL_ALIGNMENT_CENTER},
		{"text":"MINIONS", "size":Vector2(82, 30), "align":HORIZONTAL_ALIGNMENT_CENTER},
		{"text":"ITEM 1", "size":Vector2(58, 30), "align":HORIZONTAL_ALIGNMENT_CENTER},
		{"text":"ITEM 2", "size":Vector2(58, 30), "align":HORIZONTAL_ALIGNMENT_CENTER},
		{"text":"ITEM 3", "size":Vector2(58, 30), "align":HORIZONTAL_ALIGNMENT_CENTER},
	]:
		result_table.add_child(_make_result_cell(header["text"], header["size"], COLOR_MUTED, 10, header["align"]))

func _populate_result_table() -> void:
	_build_result_table()
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or not node is Hero:
			continue
		var hero := node as Hero
		var faction_color := COLOR_ALLY if hero.faction == &"ally" else COLOR_ENEMY
		var display_name := hero.name.trim_prefix("Player").trim_prefix("Enemy").to_upper()
		var team_name := "ALLY  " if hero.faction == &"ally" else "ENEMY  "
		result_table.add_child(_make_result_cell(team_name + display_name, Vector2(300, 32), faction_color, 13, HORIZONTAL_ALIGNMENT_LEFT))
		result_table.add_child(_make_result_cell(str(hero.kill_count), Vector2(64, 32), COLOR_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER))
		result_table.add_child(_make_result_cell(str(hero.death_count), Vector2(70, 32), COLOR_TEXT, 14, HORIZONTAL_ALIGNMENT_CENTER))
		result_table.add_child(_make_result_cell(str(hero.minion_kill_count), Vector2(82, 32), COLOR_ACCENT, 14, HORIZONTAL_ALIGNMENT_CENTER))
		for _slot in 3:
			result_table.add_child(_make_result_item_slot())

func _make_result_cell(label_text: String, cell_size: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = cell_size
	label.size = cell_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_result_item_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(58, 32)
	slot.size = slot.custom_minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.045, 0.9)
	style.border_color = COLOR_BORDER.darkened(0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot

func _make_exit_button(parent: Control) -> Button:
	var button := Button.new()
	button.name = "ExitButton"
	button.text = "X"
	button.position = Vector2(718, 12)
	button.size = Vector2(48, 48)
	button.custom_minimum_size = button.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.68, 0.46, 1.0)
	normal.border_color = Color(0.42, 0.95, 0.72, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(24)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.82, 0.55, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.48, 0.33, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(button)
	return button

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.size = REFERENCE_VIEWPORT
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	_root.add_child(pause_overlay)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.04, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(shade)

	var panel := _make_panel("PausePanel", Vector2(340, 112), COLOR_INK, 14, 2)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-170, -56)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(panel)
	_make_label(panel, "PauseTitle", "PAUSED", Vector2(0, 20), Vector2(340, 34), 26, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_make_label(panel, "PauseHint", "CLICK THE HERO PANEL OR MAP TO RESUME", Vector2(0, 65), Vector2(340, 18), 9, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _make_pause_region(panel: Control) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_pause_region_gui_input)

func _make_panel(node_name: String, panel_size: Vector2, color: Color, radius: int = 10, border_width: int = 1) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COLOR_BORDER
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _fmt_num(value: float) -> String:
	var digits := str(int(value))
	var out := ""
	for i in digits.length():
		out += digits[i]
		var remaining := digits.length() - 1 - i
		if remaining > 0 and remaining % 3 == 0:
			out += ","
	return out

func _make_label(parent: Control, node_name: String, label_text: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = label_size
	label.text = label_text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _make_bar(parent: Control, node_name: String, at: Vector2, bar_size: Vector2, fill_color: Color) -> HudBar:
	var bar := HudBar.new()
	bar.name = node_name
	bar.position = at
	bar.size = bar_size
	bar.custom_minimum_size = bar_size
	bar.fill_color = fill_color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func _make_icon(parent: Control, node_name: String, texture: Texture2D, at: Vector2, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = icon_size
	icon.position = at
	icon.size = icon_size
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _make_skill_button(parent: Control, node_name: String, fallback_title: String, key: String, color: Color, slot: int, button_size: Vector2) -> Dictionary:
	var button := _make_action_button(parent, node_name, fallback_title, key, color, button_size)
	button["slot"] = slot
	var base_button: Button = button["button"]
	base_button.pressed.connect(_on_skill_button_pressed.bind(slot))
	return button

func _make_action_button(parent: Control, node_name: String, title: String, key: String, color: Color, button_size: Vector2) -> Dictionary:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = button_size
	button.size = button_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.18)
	normal.border_color = color.lightened(0.15)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.03)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.lightened(0.16)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.1, 0.13, 0.18, 0.95)
	disabled.border_color = Color(0.25, 0.3, 0.37, 0.8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", normal)
	parent.add_child(button)

	var overlay := ProgressBar.new()
	overlay.name = "CooldownOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.show_percentage = false
	overlay.max_value = 100.0
	overlay.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_background := StyleBoxFlat.new()
	overlay_background.bg_color = Color(0, 0, 0, 0)
	var overlay_fill := StyleBoxFlat.new()
	overlay_fill.bg_color = Color(0.01, 0.02, 0.04, 0.72)
	overlay.add_theme_stylebox_override("background", overlay_background)
	overlay.add_theme_stylebox_override("fill", overlay_fill)
	overlay.visible = false
	button.add_child(overlay)

	var title_label := _make_label(button, "Title", title, Vector2(2, 9), Vector2(button_size.x - 4, 37), 11, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var _key_label := _make_label(button, "Key", "[" + key + "]", Vector2(4, button_size.y - 20), Vector2(button_size.x - 8, 15), 9, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var cooldown_label := _make_label(button, "Cooldown", "", Vector2(0, 19), Vector2(button_size.x, 24), 17, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	cooldown_label.visible = false
	var lock_label := _make_label(button, "Lock", "", Vector2(button_size.x - 38, 3), Vector2(34, 14), 8, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	lock_label.visible = false
	return {"button": button, "overlay": overlay, "title_label": title_label, "cooldown_label": cooldown_label, "lock_label": lock_label, "slot": -1, "base_title": title}

func _on_skill_button_pressed(slot: int) -> void:
	if player == null:
		return
	if slot == 0:
		player.perform_basic_attack()
	else:
		player.try_use_skill(slot)

func _update_skill_buttons() -> void:
	if player == null:
		return
	for entry in _skill_buttons:
		var button: Button = entry["button"]
		var slot: int = entry["slot"]
		var overlay: ProgressBar = entry["overlay"]
		var cooldown_label: Label = entry["cooldown_label"]
		var lock_label: Label = entry["lock_label"]
		if slot == 0:
			button.disabled = false
			lock_label.visible = false
			continue
		var skill: SkillData = player.get_skill(slot)
		if skill == null:
			button.disabled = true
			lock_label.text = "N/A"
			lock_label.visible = true
			continue
		entry["title_label"].text = _skill_title(skill.skill_name)
		var locked := player.level < skill.unlock_level
		button.disabled = locked
		lock_label.text = "LV%d" % skill.unlock_level
		lock_label.visible = locked
		var timer := player.get_skill_timer(slot)
		if timer != null and not timer.is_stopped():
			var remaining := timer.time_left
			overlay.value = 100.0 * remaining / skill.cooldown if skill.cooldown > 0.0 else 0.0
			overlay.visible = true
			cooldown_label.text = "%.1f" % remaining
			cooldown_label.visible = true
		else:
			overlay.value = 0.0
			overlay.visible = false
			cooldown_label.text = ""
			cooldown_label.visible = false

func _skill_title(skill_name: StringName) -> String:
	var words := str(skill_name).replace("_", " ").to_upper().split(" ")
	if words.size() >= 2:
		return "%s\n%s" % [words[0], " ".join(words.slice(1))]
	return str(skill_name).to_upper()

func _on_health_changed(current_hp: float, max_hp: float) -> void:
	hp_bar.set_value(100.0 * current_hp / max_hp if max_hp > 0.0 else 0.0)
	hp_value_label.text = "%s / %s" % [_fmt_num(current_hp), _fmt_num(max_hp)]

func _on_exp_changed(current_exp: float, required_exp: float, _current_level: int) -> void:
	if required_exp <= 0.0:
		exp_bar.set_value(100.0)
		exp_value_label.text = "MAX XP"
		return
	exp_bar.set_value(100.0 * current_exp / required_exp)
	exp_value_label.text = "%d / %d XP" % [int(current_exp), int(required_exp)]

func _on_leveled_up(new_level: int) -> void:
	level_label.text = "LV %d" % new_level

func _on_match_time_changed(elapsed: float) -> void:
	var minutes := int(elapsed / 60.0)
	var seconds := int(elapsed) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_player_stats_changed(kills: int, deaths: int, _minion_kills: int) -> void:
	player_kills_label.text = "%02d" % kills
	player_deaths_label.text = "%02d" % deaths

func _on_pause_region_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_toggle_pause()
	get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var mm := get_tree().root.get_node_or_null("MatchManager")
	if mm != null and mm.match_state != MatchManager.MatchState.PLAYING:
		return
	get_tree().paused = not get_tree().paused
	if pause_overlay != null:
		pause_overlay.visible = get_tree().paused

func _show_victory() -> void:
	_show_result("VICTORY", COLOR_ALLY)

func _show_defeat() -> void:
	_show_result("DEFEAT", COLOR_ENEMY)

func _show_result(result_text: String, result_color: Color) -> void:
	center_label.text = result_text
	center_label.add_theme_color_override("font_color", result_color)
	_populate_result_table()
	result_panel.visible = true

func _on_exit_button_pressed() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("return_to_main_menu"):
		main.return_to_main_menu()
