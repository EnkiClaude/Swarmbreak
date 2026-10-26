class_name Hud
extends Control
## Player-facing HUD: health and mana bars, zone and camps-left line, a
## minimap of the camps, and a red edge flash when the player is hurt.
## Redraws every frame from the live game state; owns no game state itself.

const TEXT_SIZE := 18
const VIGNETTE_WIDTH := 48.0

@export var config: HudConfig

var _vitals: PlayerVitals
var _zone: ZoneDirector
var _player: Player
var _half_extent := 1.0
var _hurt := 0.0


func setup(vitals: PlayerVitals, zone: ZoneDirector, player: Player, half_extent: float) -> void:
	_vitals = vitals
	_zone = zone
	_player = player
	_half_extent = half_extent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flashes the screen edges; amount is damage taken this frame.
func flash_hurt(amount: float) -> void:
	_hurt = minf(_hurt + amount * 0.08, 1.0)


func tick(delta: float) -> void:
	_hurt = maxf(_hurt - config.hurt_vignette_fade * delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _vitals == null:
		return
	_draw_bars()
	_draw_minimap()
	if _hurt > 0.0:
		_draw_vignette()


func _draw_bars() -> void:
	var center := config.bar_position * size
	var w := config.bar_width
	var h := config.bar_height
	var top := center.y - h - config.bar_gap * 0.5
	_draw_bar(Rect2(center.x - w * 0.5, top, w, h), _vitals.health / _vitals.max_health,
			config.health_color, "%d / %d" % [ceili(_vitals.health), roundi(_vitals.max_health)])
	_draw_bar(Rect2(center.x - w * 0.5, top + h + config.bar_gap, w, h),
			_vitals.mana / _vitals.max_mana, config.mana_color, "%d" % floori(_vitals.mana))
	if _zone != null:
		var line := "ZONE %d   camps left %d" % [_zone.level, _zone.camps_left()]
		_draw_text_centered(Vector2(center.x, top - 10.0), line, Color(1, 1, 1, 0.85))


func _draw_bar(rect: Rect2, fraction: float, color: Color, label: String) -> void:
	draw_rect(rect, config.bar_back_color)
	var filled := rect
	filled.size.x *= clampf(fraction, 0.0, 1.0)
	draw_rect(filled, color)
	_draw_text_centered(rect.get_center() + Vector2(0.0, TEXT_SIZE * 0.35 - 1.0), label,
			Color(1, 1, 1, 0.9), TEXT_SIZE - 4)


func _draw_minimap() -> void:
	if _zone == null:
		return
	var s := config.minimap_size
	var origin := Vector2(size.x - s - config.minimap_margin, config.minimap_margin)
	draw_rect(Rect2(origin, Vector2(s, s)), config.minimap_back_color)
	var scale_factor := s / (_half_extent * 2.0)
	for camp in _zone.camp_centers.size():
		if _zone.camp_alive[camp] <= 0:
			continue
		var c: Vector2 = _zone.camp_centers[camp]
		var dot := origin + (c + Vector2(_half_extent, _half_extent)) * scale_factor
		var awake := _zone.camp_awake[camp] != 0
		var radius := clampf(sqrt(float(_zone.camp_alive[camp])) * 0.7, 2.0, 6.0)
		draw_circle(dot, radius, config.minimap_awake_color if awake else config.minimap_camp_color)
	var p := _player.ground_position()
	draw_circle(origin + (p + Vector2(_half_extent, _half_extent)) * scale_factor, 3.5,
			config.minimap_player_color)


func _draw_vignette() -> void:
	var color := config.hurt_vignette_color
	color.a *= _hurt
	var w := VIGNETTE_WIDTH
	draw_rect(Rect2(0, 0, size.x, w), color)
	draw_rect(Rect2(0, size.y - w, size.x, w), color)
	draw_rect(Rect2(0, w, w, size.y - w * 2.0), color)
	draw_rect(Rect2(size.x - w, w, w, size.y - w * 2.0), color)


func _draw_text_centered(at: Vector2, text: String, color: Color,
		font_size: int = TEXT_SIZE) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(at.x - width * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, color)
