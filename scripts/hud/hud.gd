class_name Hud
extends Control
## Player-facing HUD: health, mana and XP bars, level and zone line, a hint
## when skill points are waiting, a minimap of the camps, pickup messages and
## a red edge flash when the player is hurt.
## Redraws every frame from the live game state; owns no game state itself.

const TEXT_SIZE := 18
const VIGNETTE_WIDTH := 48.0
const XP_BAR_HEIGHT := 6.0
const TOAST_TIME := 3.5
const TOAST_LINES := 4
const TOAST_ORIGIN := Vector2(16.0, 0.72)
## Level-up banner: below the break popup so a big break and the level-up
## it causes are both readable.
const BANNER_Y := 0.34
const BANNER_SIZE := 40

@export var config: HudConfig

var _vitals: PlayerVitals
var _zone: ZoneDirector
var _player: Player
var _half_extent := 1.0
var _hurt := 0.0
var _progress: PlayerProgress
var _toast_texts: PackedStringArray = []
var _toast_colors: PackedColorArray = []
var _toast_ages: PackedFloat32Array = []
var _banner_text := ""
var _banner_color := Color.WHITE
var _banner_left := 0.0
var _banner_duration := 1.0


func setup(vitals: PlayerVitals, zone: ZoneDirector, player: Player, half_extent: float,
		progress: PlayerProgress = null) -> void:
	_vitals = vitals
	_progress = progress
	_zone = zone
	_player = player
	_half_extent = half_extent
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flashes the screen edges; amount is damage taken this frame.
func flash_hurt(amount: float) -> void:
	_hurt = minf(_hurt + amount * 0.08, 1.0)


## Shows a large line under the break popup, e.g. "LEVEL 5".
func banner(text: String, color: Color, duration: float) -> void:
	_banner_text = text
	_banner_color = color
	_banner_left = duration
	_banner_duration = duration


func banner_showing() -> bool:
	return _banner_left > 0.0


## Shows a short message bottom-left, e.g. an item pickup.
func toast(text: String, color: Color) -> void:
	_toast_texts.append(text)
	_toast_colors.append(color)
	_toast_ages.append(0.0)
	while _toast_texts.size() > TOAST_LINES:
		_toast_texts.remove_at(0)
		_toast_colors.remove_at(0)
		_toast_ages.remove_at(0)


func tick(delta: float) -> void:
	_hurt = maxf(_hurt - config.hurt_vignette_fade * delta, 0.0)
	_banner_left = maxf(_banner_left - delta, 0.0)
	for k in range(_toast_ages.size() - 1, -1, -1):
		_toast_ages[k] += delta
		if _toast_ages[k] > TOAST_TIME:
			_toast_texts.remove_at(k)
			_toast_colors.remove_at(k)
			_toast_ages.remove_at(k)
	queue_redraw()


func _draw() -> void:
	if _vitals == null:
		return
	_draw_bars()
	_draw_minimap()
	_draw_toasts()
	if _banner_left > 0.0:
		var color := _banner_color
		color.a *= clampf(_banner_left / (_banner_duration * 0.3), 0.0, 1.0)
		_draw_text_centered(Vector2(size.x * 0.5, size.y * BANNER_Y), _banner_text, color,
				BANNER_SIZE)
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
	var line := ""
	if _progress != null:
		var xp_rect := Rect2(center.x - w * 0.5, top - XP_BAR_HEIGHT - 4.0, w, XP_BAR_HEIGHT)
		var fraction := 1.0 if _progress.is_max_level() else _progress.xp / _progress.xp_to_next()
		draw_rect(xp_rect, config.bar_back_color)
		draw_rect(Rect2(xp_rect.position, Vector2(w * fraction, XP_BAR_HEIGHT)), config.xp_color)
		line = "LV %d   " % _progress.level
		top -= XP_BAR_HEIGHT + 4.0
		if _progress.skill_points > 0:
			_draw_text_centered(Vector2(center.x, top - 34.0), "%d skill point%s - open CHAR" % [
					_progress.skill_points, "" if _progress.skill_points == 1 else "s"],
					config.xp_color)
	if _zone != null:
		line += "ZONE %d   camps left %d" % [_zone.level, _zone.camps_left()]
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


func _draw_toasts() -> void:
	var y := size.y * TOAST_ORIGIN.y
	for k in _toast_texts.size():
		var color := _toast_colors[k]
		color.a *= clampf((TOAST_TIME - _toast_ages[k]) / 0.6, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(TOAST_ORIGIN.x, y + k * (TEXT_SIZE + 6)),
				_toast_texts[k], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, color)


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
