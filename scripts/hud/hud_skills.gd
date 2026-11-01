class_name HudSkills
extends RefCounted
## Draws the skill column on the right edge: one framed slot per ability
## with a drawn glyph, its controller button, a cooldown shade that drains
## from the top, and a blue tint when there isn't enough mana.

enum Glyph { BOLT, NOVA, LURE, DODGE }

const LABEL_SIZE := 13
const GLYPH_COLORS: Array[Color] = [Color(1.0, 0.6, 0.2), Color(0.5, 0.8, 1.0),
		Color(1.0, 0.8, 0.3), Color(0.75, 1.0, 0.7)]


## Top-left of the slot at row (0 = top) in a column of rows slots.
static func slot_position(config: HudConfig, screen: Vector2, row: int, rows: int) -> Vector2:
	var s := config.skill_slot_size
	var column := rows * s + (rows - 1) * config.skill_gap
	var top := screen.y * config.skill_center_y - column * 0.5
	return Vector2(screen.x - config.skill_margin - s, top + row * (s + config.skill_gap))


## readiness is 0 right after use and 1 when ready (Cooldown.progress()).
static func draw_slot(canvas: CanvasItem, config: HudConfig, at: Vector2, glyph: Glyph,
		button: String, readiness: float, usable: bool) -> void:
	var s := config.skill_slot_size
	var rect := Rect2(at, Vector2(s, s))
	canvas.draw_rect(rect, config.skill_back_color)
	_draw_glyph(canvas, rect.get_center(), s * 0.3, glyph)
	if readiness < 1.0:
		var shade := Rect2(at, Vector2(s, s * (1.0 - readiness)))
		canvas.draw_rect(shade, config.skill_cooldown_color)
	if not usable:
		canvas.draw_rect(rect, config.skill_no_mana_color)
	var frame := config.frame_color
	if readiness < 1.0:
		frame = frame.darkened(0.45)
	canvas.draw_rect(rect, frame, false, 2.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(button, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var label_at := Vector2(at.x + s - w - 3.0, at.y + s - 4.0)
	canvas.draw_string_outline(font, label_at, button, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			4, Color(0, 0, 0, 0.85))
	canvas.draw_string(font, label_at, button, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			Color(1.0, 0.95, 0.85))


static func _draw_glyph(canvas: CanvasItem, c: Vector2, r: float, glyph: Glyph) -> void:
	var color := GLYPH_COLORS[glyph]
	match glyph:
		Glyph.BOLT:
			var tail := c + Vector2(-r, r)
			var tip := c + Vector2(r, -r)
			canvas.draw_line(tail, tip, color, 3.0, true)
			var back := (tail - tip).normalized()
			var side := Vector2(-back.y, back.x)
			canvas.draw_colored_polygon(PackedVector2Array([tip,
					tip + back * r * 0.7 + side * r * 0.35,
					tip + back * r * 0.7 - side * r * 0.35]), color)
		Glyph.NOVA:
			canvas.draw_arc(c, r * 0.55, 0.0, TAU, 24, color, 3.0, true)
			for k in 8:
				var dir := Vector2.from_angle(TAU * k / 8.0)
				canvas.draw_line(c + dir * r * 0.75, c + dir * r * 1.1, color, 2.5, true)
		Glyph.LURE:
			canvas.draw_circle(c + Vector2(-r * 0.6, 0.0), r * 0.25, color)
			for k in 3:
				var radius := r * (0.45 + 0.4 * k)
				canvas.draw_arc(c + Vector2(-r * 0.6, 0.0), radius, -0.7, 0.7, 12, color, 2.5, true)
		Glyph.DODGE:
			for k in 2:
				var x := c.x - r * 0.6 + k * r * 0.7
				canvas.draw_polyline(PackedVector2Array([Vector2(x, c.y - r * 0.7),
						Vector2(x + r * 0.55, c.y), Vector2(x, c.y + r * 0.7)]), color, 3.5, true)
