class_name HeroSelectUI
extends CanvasLayer

signal hero_selected(entry: Dictionary)

@export var default_scene_path: String = ""
@export var min_ui_scale: float = 0.75
@export var max_ui_scale: float = 1.5

var _ui_scale: float = 1.0
var _cards: Array[Button] = []

func _ready() -> void:
	layer = 10
	var viewport_height := get_viewport().get_visible_rect().size.y
	_ui_scale = clampf(viewport_height / 648.0, min_ui_scale, max_ui_scale)
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
			var idx := int(key_event.keycode) - int(KEY_1)
			if idx < HeroRoster.HEROES.size():
				_select(idx)
				get_viewport().set_input_as_handled()

func _default_index() -> int:
	for i in HeroRoster.HEROES.size():
		if HeroRoster.HEROES[i]["player_scene"] == default_scene_path:
			return i
	return 0

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.09, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", int(24 * _ui_scale))
	center.add_child(root)

	var title := Label.new()
	title.text = "CHOOSE YOUR HERO"
	title.add_theme_font_size_override("font_size", int(40 * _ui_scale))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var fill_hint := Label.new()
	fill_hint.text = "YOU PICK YOUR HERO \u00b7 TEAMMATES & ENEMIES AUTO-FILL"
	fill_hint.add_theme_font_size_override("font_size", int(13 * _ui_scale))
	fill_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fill_hint.modulate = Color(1, 1, 1, 0.6)
	root.add_child(fill_hint)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", int(20 * _ui_scale))
	root.add_child(cards_row)

	var default_idx := _default_index()
	for i in HeroRoster.HEROES.size():
		var entry: Dictionary = HeroRoster.HEROES[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 190) * _ui_scale
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal", _card_style(entry["color"], i == default_idx))
		card.add_theme_stylebox_override("hover", _card_style(entry["color"], i == default_idx, 1.0))
		card.add_theme_stylebox_override("pressed", _card_style(entry["color"], i == default_idx))
		card.pressed.connect(_select.bind(i))
		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = int(14 * _ui_scale)
		content.offset_right = int(-14 * _ui_scale)
		content.offset_top = int(12 * _ui_scale)
		content.offset_bottom = int(-12 * _ui_scale)
		content.add_theme_constant_override("separation", int(6 * _ui_scale))
		card.add_child(content)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", int(10 * _ui_scale))
		content.add_child(header)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(22, 22) * _ui_scale
		swatch.color = entry["color"]
		header.add_child(swatch)
		var name_label := Label.new()
		name_label.text = "%s" % entry["name"]
		name_label.add_theme_font_size_override("font_size", int(22 * _ui_scale))
		header.add_child(name_label)

		var hint := Label.new()
		hint.text = "Press %d" % (i + 1)
		hint.add_theme_font_size_override("font_size", int(12 * _ui_scale))
		hint.modulate = Color(1, 1, 1, 0.5)
		content.add_child(hint)

		var stats_label := Label.new()
		stats_label.text = entry["stats"]
		stats_label.add_theme_font_size_override("font_size", int(14 * _ui_scale))
		content.add_child(stats_label)

		var skills_label := Label.new()
		skills_label.text = entry["skills"]
		skills_label.add_theme_font_size_override("font_size", int(13 * _ui_scale))
		skills_label.modulate = Color(1, 1, 1, 0.75)
		skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(skills_label)

		_cards.append(card)
		cards_row.add_child(card)

func _card_style(accent: Color, is_default: bool, border_alpha: float = 0.6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = accent if is_default else Color(1, 1, 1, border_alpha * 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _select(index: int) -> void:
	print("[HeroSelect] select %d triggered" % index)
	if index < 0 or index >= HeroRoster.HEROES.size():
		return
	hero_selected.emit(HeroRoster.HEROES[index])
