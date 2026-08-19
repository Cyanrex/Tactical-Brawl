class_name HudBar
extends Control

var fill_color := Color.WHITE
var value: float = 0.0

func set_value(next_value: float) -> void:
	value = clampf(next_value, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.045, 0.95), true)
	var fill_width := (size.x - 2.0) * value / 100.0
	if fill_width > 0.0:
		draw_rect(Rect2(Vector2(1, 1), Vector2(fill_width, size.y - 2.0)), fill_color, true)
		draw_line(Vector2(1, 1), Vector2(size.x - 1, 1), fill_color.lightened(0.2), 1.0)
