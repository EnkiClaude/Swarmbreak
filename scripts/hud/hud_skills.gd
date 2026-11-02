class_name HudSkills
extends RefCounted
## Draws the skill column on the right edge: one framed slot per ability
## with a drawn glyph, its controller button, a cooldown shade that drains
## from the top, and a blue tint when there isn't enough mana. Active skills
## (ActiveSkills) sit in a second column to its left, showing their grade, or
## the level they unlock at while locked.

enum Glyph { BOLT, NOVA, LURE, DODGE, CHAIN, INFERNO, METEOR, WHIRL }

const LABEL_SIZE := 13
const GLYPH_COLORS: Array[Color] = [Color(1.0, 0.6, 0.2), Color(0.5, 0.8, 1.0),
		Color(1.0, 0.8, 0.3), Color(0.75, 1.0, 0.7), Color(0.6, 0.85, 1.0), Color(1.0, 0.45, 0.15),
		Color(1.0, 0.3, 0.1), Color(0.95, 0.25, 0.2)]


## Top-left of the slot at row (0 = top) in a column of rows slots; column
## 1 is the one left of the first.
static func slot_position(config: HudConfig, screen: Vector2, row: int, rows: int,
		column: int = 0) -> Vector2:
	var s := config.skill_slot_size
	var height := rows * s + (rows - 1) * config.skill_gap
	var top := screen.y * config.skill_center_y - height * 0.5
	return Vector2(screen.x - config.skill_margin - s - column * (s + config.skill_gap),
			top + row * (s + config.skill_gap))


## readiness is 0 right after use and 1 when ready (Cooldown.progress()).
static func draw_slot(canvas: CanvasItem, config: HudConfig, at: Vector2, glyph: Glyph,
		button: String, readiness: float, usable: bool, corner: String = "",
		locked: bool = false) -> void:
	var s := config.skill_slot_size
	var rect := Rect2(at, Vector2(s, s))
	canvas.draw_rect(rect, config.skill_back_color)
	_draw_glyph(canvas, rect.get_center(), s * 0.3, glyph)
	if locked:
		canvas.draw_rect(rect, Color(0, 0, 0, 0.65))
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
	if corner != "":
		var corner_at := Vector2(at.x + 3.0, at.y + LABEL_SIZE + 1.0)
		canvas.draw_string_outline(font, corner_at, corner, HORIZONTAL_ALIGNMENT_LEFT, -1,
				LABEL_SIZE, 4, Color(0, 0, 0, 0.85))
		canvas.draw_string(font, corner_at, corner, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
				Color(1.0, 0.8, 0.4) if not locked else Color(1, 1, 1, 0.6))


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
		Glyph.CHAIN:
			var points := PackedVector2Array([c + Vector2(-r * 0.2, -r), c + Vector2(r * 0.3, -r * 0.15),
					c + Vector2(-r * 0.25, r * 0.05), c + Vector2(r * 0.25, r)])
			canvas.draw_polyline(points, color, 3.5, true)
		Glyph.INFERNO:
			for k in 3:
				var x := c.x + (k - 1) * r * 0.55
				var h := r * (0.7 + 0.3 * float(k % 2))
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - r * 0.25, c.y + r * 0.7),
						Vector2(x, c.y + r * 0.7 - h * 1.4), Vector2(x + r * 0.25, c.y + r * 0.7)]),
						color)
		Glyph.METEOR:
			canvas.draw_circle(c + Vector2(r * 0.35, r * 0.35), r * 0.38, color)
			for k in 3:
				var off := Vector2(-r * 0.15 * k, r * 0.15 * k)
				canvas.draw_line(c + Vector2(-r, -r) + off * 2.0, c + Vector2(r * 0.1, r * 0.1) + off,
						color, 2.5, true)
		Glyph.WHIRL:
			for k in 3:
				var a := TAU * k / 3.0
				canvas.draw_arc(c, r * 0.8, a, a + 1.4, 10, color, 3.0, true)
				canvas.draw_line(c + Vector2.from_angle(a + 1.4) * r * 0.8,
						c + Vector2.from_angle(a + 1.2) * r * 1.05, color, 3.0, true)
		Glyph.DODGE:
			for k in 2:
				var x := c.x - r * 0.6 + k * r * 0.7
				canvas.draw_polyline(PackedVector2Array([Vector2(x, c.y - r * 0.7),
						Vector2(x + r * 0.55, c.y), Vector2(x, c.y + r * 0.7)]), color, 3.5, true)
