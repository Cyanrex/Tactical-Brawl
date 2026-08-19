class_name HealthBar2D
extends Node2D


var fill_color := Color(0.32, 0.85, 0.38)
var fill_ratio: float = 1.0

var bar_width := 36.0
var bar_height := 5.0

func _ready() -> void:
	var body := get_parent().get_node_or_null("Body") as Polygon2D
	if body != null and body.polygon.size() > 0:
		var min_x: float = INF
		var min_y: float = INF
		var max_x: float = -INF
		var max_y: float = -INF
		for point: Vector2 in body.polygon:
			min_x = minf(min_x, point.x)
			min_y = minf(min_y, point.y)
			max_x = maxf(max_x, point.x)
			max_y = maxf(max_y, point.y)
		bar_width = clampf((max_x - min_x) * 0.95, 22.0, 44.0)
		bar_height = clampf(bar_width * 0.14, 4.0, 6.0)
		position = Vector2((min_x + max_x) * 0.5, min_y - bar_height - 5.0)
	queue_redraw()

func update_value(current_hp: float, max_hp: float) -> void:
	fill_ratio = clampf(current_hp / maxf(max_hp, 1.0), 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var top_left := Vector2(-bar_width * 0.5, 0.0)
	var bg := Rect2(top_left, Vector2(bar_width, bar_height))
	draw_rect(bg, Color(0.015, 0.025, 0.045, 0.92), true)
	if fill_ratio > 0.0:
		var fill_rect := Rect2(top_left + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * fill_ratio, bar_height - 2.0))
		draw_rect(fill_rect, fill_color, true)
		draw_line(fill_rect.position, Vector2(fill_rect.position.x + fill_rect.size.x, fill_rect.position.y), fill_color.lightened(0.25), 1.0)
	draw_rect(bg, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
