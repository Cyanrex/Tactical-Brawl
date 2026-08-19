class_name MainMenuUI
extends CanvasLayer

signal hero_selected(entry: Dictionary)

const SCREEN_TITLE := "title"
const SCREEN_CHARACTERS := "characters"
const SCREEN_CREDITS := "credits"
const CHARACTER_SLOT_COUNT := 20

const COLOR_BACKGROUND := Color(0.035, 0.055, 0.09, 1.0)
const COLOR_SURFACE := Color(0.07, 0.1, 0.16, 0.96)
const COLOR_INK := Color(0.93, 0.95, 1.0, 1.0)
const COLOR_MUTED := Color(0.58, 0.63, 0.74, 1.0)
const COLOR_PLACEHOLDER := Color(0.3, 0.35, 0.45, 1.0)
const COLOR_DISABLED := Color(1.0, 0.39, 0.48, 1.0)
const COLOR_BLUE := Color(0.21, 0.74, 0.96, 1.0)

const UI_BLUE_BUTTON: Texture2D = preload("res://resources/assets/UI/Blue/button_rectangle_depth_gradient.svg")
const UI_YELLOW_BUTTON: Texture2D = preload("res://resources/assets/UI/Yellow/button_rectangle_depth_gradient.svg")
const UI_RED_BUTTON: Texture2D = preload("res://resources/assets/UI/Red/button_rectangle_depth_gradient.svg")
const UI_STAR: Texture2D = preload("res://resources/assets/UI/Yellow/star_outline_depth.svg")
const UI_DIVIDER: Texture2D = preload("res://resources/assets/UI/Extra/divider.svg")

@export var default_scene_path: String = ""

var _root: Control
var _screen := SCREEN_TITLE
var _selected_index := 0

func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_show_title()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_BACKSPACE:
		if _screen == SCREEN_CHARACTERS or _screen == SCREEN_CREDITS:
			_show_title()
		get_viewport().set_input_as_handled()
		return

	if _screen == SCREEN_CHARACTERS and key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		var slot := int(key_event.keycode) - int(KEY_1)
		if slot < HeroRoster.HEROES.size():
			_select_character(slot)
		get_viewport().set_input_as_handled()

func _on_viewport_size_changed() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	match _screen:
		SCREEN_TITLE:
			_show_title()
		SCREEN_CHARACTERS:
			_render_character_screen()
		SCREEN_CREDITS:
			_show_credits()

func _clear_screen() -> void:
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()

func _add_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	var top_band := ColorRect.new()
	top_band.name = "TopBand"
	top_band.color = Color(0.06, 0.12, 0.19, 0.8)
	top_band.position = Vector2(0.0, 0.0)
	top_band.size = Vector2(_viewport_size().x, 5.0)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_band)

func _show_title() -> void:
	_screen = SCREEN_TITLE
	_clear_screen()
	_add_background()
	var viewport_size := _viewport_size()
	var title_panel := _make_info_panel(Vector2(viewport_size.x * 0.47, viewport_size.y * 0.13), Vector2(viewport_size.x * 0.43, viewport_size.y * 0.6))
	title_panel.name = "TitleFeaturePanel"
	_root.add_child(title_panel)
	var star := _make_texture(title_panel, "ArenaMark", UI_STAR, Vector2(title_panel.size.x - 132.0, 34.0), Vector2(92.0, 86.0))
	star.modulate = Color(1.0, 0.82, 0.25, 0.95)
	_make_label(title_panel, "FeatureKicker", "TACTICAL BRAWL", Vector2(34.0, 42.0), Vector2(title_panel.size.x - 190.0, 28.0), _font_size(16.0, 12.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_BLUE)
	_make_label(title_panel, "FeatureTitle", "ENTER THE\nARENA", Vector2(34.0, 88.0), Vector2(title_panel.size.x - 68.0, 128.0), _font_size(48.0, 28.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_INK)
	_make_texture(title_panel, "FeatureDivider", UI_DIVIDER, Vector2(34.0, 238.0), Vector2(title_panel.size.x - 68.0, 4.0))
	_make_label(title_panel, "FeatureText", "Choose your champion, coordinate your lane,\nand break the enemy tower.", Vector2(34.0, 266.0), Vector2(title_panel.size.x - 68.0, 56.0), _font_size(17.0, 13.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_MUTED)
	_make_label(title_panel, "FeatureStats", "09 HEROES   //   03 LANES   //   01 TOWER", Vector2(34.0, title_panel.size.y - 48.0), Vector2(title_panel.size.x - 68.0, 24.0), _font_size(12.0, 10.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_MUTED)

	var title_size := Vector2(viewport_size.x * 0.42, maxf(80.0, viewport_size.y * 0.14))
	_make_label(_root, "GameEyebrow", "TACTICAL BRAWL / MATCH PROTOCOL", Vector2(viewport_size.x * 0.07, viewport_size.y * 0.12), title_size, _font_size(16.0, 12.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_BLUE)
	_make_label(_root, "GameTitle", "TACTICAL BRAWL", Vector2(viewport_size.x * 0.07, viewport_size.y * 0.18), title_size, _font_size(62.0, 34.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_INK)
	_make_label(_root, "GameSubtitle", "A HERO BRAWL IN THREE LANES", Vector2(viewport_size.x * 0.07, viewport_size.y * 0.31), title_size, _font_size(17.0, 12.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_MUTED)

	var actions := VBoxContainer.new()
	actions.name = "MainActions"
	actions.position = Vector2(maxf(36.0, viewport_size.x * 0.07), viewport_size.y * 0.55)
	actions.add_theme_constant_override("separation", int(clampf(viewport_size.y * 0.018, 6.0, 18.0)))
	_root.add_child(actions)
	var action_width := clampf(viewport_size.x * 0.24, 210.0, 320.0)
	var action_height := clampf(viewport_size.y * 0.075, 48.0, 64.0)
	_make_menu_button(actions, "PLAY MATCH", Vector2(action_width, action_height), _show_characters, 30.0, UI_YELLOW_BUTTON, COLOR_BACKGROUND)
	_make_menu_button(actions, "CREDITS", Vector2(action_width, action_height), _show_credits, 30.0, UI_BLUE_BUTTON, COLOR_INK)
	_make_menu_button(actions, "QUIT", Vector2(action_width, action_height), _quit_game, 30.0, UI_RED_BUTTON, COLOR_INK)
	_make_label(_root, "BuildLabel", "BUILD 0.1  /  ONLINE", Vector2(viewport_size.x * 0.47, viewport_size.y - 34.0), Vector2(240.0, 24.0), 12, HORIZONTAL_ALIGNMENT_LEFT, COLOR_MUTED)

func _show_credits() -> void:
	_screen = SCREEN_CREDITS
	_clear_screen()
	_add_background()
	var viewport_size := _viewport_size()
	_make_label(_root, "CreditsTitle", "CREDITS", Vector2(0.0, viewport_size.y * 0.12), Vector2(viewport_size.x, 80.0), _font_size(48.0, 28.0), HORIZONTAL_ALIGNMENT_CENTER, COLOR_INK)
	var panel := _make_info_panel(Vector2(viewport_size.x * 0.18, viewport_size.y * 0.25), Vector2(viewport_size.x * 0.64, viewport_size.y * 0.5))
	_root.add_child(panel)
	_make_label(panel, "CreditsText", "TACTICAL BRAWL\n\nA WORK IN PROGRESS\n\nASSET CREDITS\nKennyNL\nBevouliin.com\nOpen Game Arts", Vector2(0.0, 0.0), panel.size, _font_size(18.0, 13.0), HORIZONTAL_ALIGNMENT_CENTER, COLOR_MUTED)
	_make_back_button(_root, _show_title)

func _show_characters() -> void:
	_screen = SCREEN_CHARACTERS
	_selected_index = _default_index()
	_render_character_screen()

func _render_character_screen() -> void:
	if _screen != SCREEN_CHARACTERS:
		return
	_clear_screen()
	_add_background()
	var viewport_size := _viewport_size()

	var grid := GridContainer.new()
	grid.name = "CharacterGrid"
	grid.columns = 5
	grid.position = Vector2(viewport_size.x * 0.07, viewport_size.y * 0.055)
	grid.add_theme_constant_override("h_separation", int(clampf(viewport_size.x * 0.04, 16.0, 72.0)))
	grid.add_theme_constant_override("v_separation", int(clampf(viewport_size.y * 0.022, 10.0, 30.0)))
	_root.add_child(grid)

	var card_size := Vector2(clampf(viewport_size.x * 0.145, 118.0, 260.0), clampf(viewport_size.y * 0.13, 92.0, 205.0))
	for slot in CHARACTER_SLOT_COUNT:
		var index := slot
		var entry: Dictionary = HeroRoster.HEROES[index] if index < HeroRoster.HEROES.size() else {}
		var card := _make_character_button(grid, entry, card_size, index == _selected_index)
		if not entry.is_empty():
			card.pressed.connect(_select_character.bind(index))

	var detail_width := clampf(viewport_size.x * 0.24, 230.0, 470.0)
	var detail_height := clampf(viewport_size.y * 0.16, 86.0, 210.0)
	var detail := _make_info_panel(Vector2(0.0, viewport_size.y - detail_height), Vector2(detail_width, detail_height))
	detail.name = "CharacterPreview"
	_root.add_child(detail)
	var selected_entry: Dictionary = HeroRoster.HEROES[_selected_index] if _selected_index < HeroRoster.HEROES.size() else {}
	if selected_entry.is_empty():
		_make_label(detail, "PreviewName", "SELECT A CHARACTER", Vector2(12.0, 0.0), detail.size - Vector2(24.0, 0.0), 20, HORIZONTAL_ALIGNMENT_CENTER, COLOR_MUTED)
	else:
		var icon_size := minf(detail.size.y - 24.0, 110.0)
		var icon := ColorRect.new()
		icon.name = "CharacterIconPlaceholder"
		icon.color = selected_entry["color"]
		icon.position = Vector2(12.0, (detail.size.y - icon_size) * 0.5)
		icon.size = Vector2(icon_size, icon_size)
		detail.add_child(icon)
		_make_label(detail, "PreviewName", selected_entry["name"].to_upper(), Vector2(icon_size + 28.0, detail.size.y * 0.23), Vector2(detail.size.x - icon_size - 40.0, 35.0), _font_size(28.0, 18.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_INK)
		_make_label(detail, "PreviewStats", selected_entry["stats"], Vector2(icon_size + 28.0, detail.size.y * 0.57), Vector2(detail.size.x - icon_size - 40.0, 25.0), _font_size(13.0, 10.0), HORIZONTAL_ALIGNMENT_LEFT, COLOR_MUTED)

	_make_back_button(_root, _show_title)

func _select_character(index: int) -> void:
	if index < 0 or index >= HeroRoster.HEROES.size():
		return
	_selected_index = index
	hero_selected.emit(HeroRoster.HEROES[index])

func _default_index() -> int:
	var index := HeroRoster.find_index_by_player_scene(default_scene_path)
	return index if index >= 0 else 0

func _quit_game() -> void:
	get_tree().quit()

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _font_size(reference: float, minimum: float) -> int:
	return int(maxf(minimum, minf(reference, _viewport_size().y * 0.1)))

func _make_label(parent: Control, node_name: String, text: String, at: Vector2, label_size: Vector2, font_size: int, alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = label_size
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _make_menu_button(parent: Control, text: String, button_size: Vector2, action: Callable, reference_font_size: float, texture: Texture2D = UI_BLUE_BUTTON, text_color: Color = COLOR_INK) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = button_size
	button.size = button_size
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", _font_size(reference_font_size, 20.0))
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.18))
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.12))
	button.add_theme_stylebox_override("normal", _asset_style(texture))
	button.add_theme_stylebox_override("hover", _asset_style(texture, 0.08))
	button.add_theme_stylebox_override("pressed", _asset_style(texture, -0.08))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _make_character_button(parent: Control, entry: Dictionary, button_size: Vector2, selected: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = button_size
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", _font_size(34.0, 18.0) if entry.is_empty() else _font_size(17.0, 11.0))
	var accent: Color = entry["color"] if not entry.is_empty() else COLOR_PLACEHOLDER
	button.text = entry["name"].to_upper() if not entry.is_empty() else "?"
	button.add_theme_color_override("font_color", COLOR_INK if not entry.is_empty() else COLOR_MUTED)
	button.add_theme_color_override("font_hover_color", COLOR_INK)
	var normal := _flat_style(Color(0.94, 0.94, 0.94, 1.0))
	normal.set_border_width_all(2 if selected else 1)
	normal.border_color = accent if not entry.is_empty() else Color(0.68, 0.68, 0.68, 1.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.86, 0.86, 0.86, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	if entry.is_empty():
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	parent.add_child(button)
	return button

func _make_back_button(parent: Control, action: Callable) -> Button:
	var viewport_size := _viewport_size()
	var button := _make_menu_button(parent, "Back", Vector2(clampf(viewport_size.x * 0.15, 150.0, 260.0), 54.0), action, 30.0)
	button.name = "BackButton"
	button.position = Vector2(viewport_size.x - button.size.x - maxf(30.0, viewport_size.x * 0.06), viewport_size.y - 82.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button

func _make_info_panel(at: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	var style := _flat_style(COLOR_SURFACE)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.4, 0.55, 0.7)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_texture(parent: Control, node_name: String, texture: Texture2D, at: Vector2, texture_size: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.texture = texture
	image.position = at
	image.size = texture_size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _asset_style(texture: Texture2D, brightness: float = 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 18.0
	style.texture_margin_right = 18.0
	style.texture_margin_top = 10.0
	style.texture_margin_bottom = 10.0
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	if not is_zero_approx(brightness):
		style.modulate_color = Color(1.0 + brightness, 1.0 + brightness, 1.0 + brightness, 1.0)
	return style

func _flat_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(0)
	return style
