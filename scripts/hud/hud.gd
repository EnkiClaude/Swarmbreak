class_name Hud
extends Control
## Player-facing HUD. Top left, a framed character panel: level and job,
## where the player is (region or dungeon and its level), health, mana and XP bars, with hints below it when
## skill points or a job choice are waiting. Top right, a round minimap
## (HudMinimap). Right edge, the skill column with cooldowns (HudSkills),
## hidden while the touch buttons show. Also pickup messages, a banner for
## level-ups and place names, a boss health bar while a boss is awake nearby,
## and a red edge flash when the player is hurt.
## Redraws every frame from the live game state; owns no game state itself.

const TEXT_SIZE := 18
const SMALL_TEXT_SIZE := 14
const VIGNETTE_WIDTH := 48.0
const XP_BAR_HEIGHT := 5.0
const PANEL_PADDING := 10.0
const CORNER_SIZE := 6.0
const TOAST_TIME := 3.5
const TOAST_LINES := 4
const TOAST_ORIGIN := Vector2(16.0, 0.72)
## Level-up banner: below the break popup so a big break and the level-up
## it causes are both readable.
const BANNER_Y := 0.34
const BANNER_SIZE := 40
const BOSS_BAR_Y := 0.1
const BOSS_BAR_WIDTH := 460.0
const BOSS_BAR_HEIGHT := 14.0
const BOSS_BAR_COLOR := Color(0.95, 0.45, 0.15)
const SKILL_ROWS := 4

@export var config: HudConfig

var _vitals: PlayerVitals
var _world: WorldDirector
var _player: Player
var _hurt := 0.0
var _progress: PlayerProgress
var _toast_texts: PackedStringArray = []
var _toast_colors: PackedColorArray = []
var _toast_ages: PackedFloat32Array = []
var _banner_text := ""
var _banner_color := Color.WHITE
var _banner_left := 0.0
var _banner_duration := 1.0
var _bosses: BossSystem
var _boss_name := ""
var _jobs: JobTree
var _camera: CameraRig
var _combat: PlayerCombat
## The skill column hides while the touch buttons are on screen.
var show_skills := true


func setup(vitals: PlayerVitals, world: WorldDirector, player: Player,
		progress: PlayerProgress = null) -> void:
	_vitals = vitals
	_progress = progress
	_world = world
	_player = player
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flashes the screen edges; amount is damage taken this frame.
func flash_hurt(amount: float) -> void:
	_hurt = minf(_hurt + amount * 0.08, 1.0)


func setup_camera_and_skills(camera: CameraRig, combat: PlayerCombat) -> void:
	_camera = camera
	_combat = combat


func setup_bosses_and_jobs(bosses: BossSystem, boss_name: String, jobs: JobTree) -> void:
	_bosses = bosses
	_boss_name = boss_name
	_jobs = jobs


## Shows a large line under the break popup, e.g. "LEVEL 5".
func banner(text: String, color: Color, duration: float) -> void:
	_banner_text = text
	_banner_color = color
	_banner_left = duration
	_banner_duration = duration


func banner_showing() -> bool:
	return _banner_left > 0.0


## Shows a short message bottom-left, e.g. an item pickup. Repeating a
## message that's still showing refreshes it instead of adding a line.
func toast(text: String, color: Color) -> void:
	var existing := _toast_texts.find(text)
	if existing >= 0:
		_toast_ages[existing] = 0.0
		return
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
	_draw_panel()
	_draw_minimap()
	if show_skills and _combat != null:
		_draw_skills()
	_draw_boss_bar()
	_draw_toasts()
	if _banner_left > 0.0:
		var color := _banner_color
		color.a *= clampf(_banner_left / (_banner_duration * 0.3), 0.0, 1.0)
		_draw_text_centered(Vector2(size.x * 0.5, size.y * BANNER_Y), _banner_text, color,
				BANNER_SIZE)
	if _hurt > 0.0:
		_draw_vignette()
	if _world != null and _world.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, _world.fade))


func _draw_panel() -> void:
	var at := config.panel_position
	var w := config.panel_width
	var inner := w - PANEL_PADDING * 2.0
	var bars_top := at.y + PANEL_PADDING + TEXT_SIZE + SMALL_TEXT_SIZE + 10.0
	var height := bars_top - at.y + config.bar_height * 2.0 + config.bar_gap * 2.0 \
			+ XP_BAR_HEIGHT + PANEL_PADDING
	var panel := Rect2(at, Vector2(w, height))
	draw_rect(panel, config.panel_color)
	_draw_frame(panel)
	var x := at.x + PANEL_PADDING
	var font := ThemeDB.fallback_font
	var title := "LV %d" % (_progress.level if _progress != null else 1)
	draw_string(font, Vector2(x, at.y + PANEL_PADDING + TEXT_SIZE - 2.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(1.0, 0.92, 0.75))
	if _progress != null and _jobs != null and _progress.job >= 0:
		var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		draw_string(font, Vector2(x + title_w + 10.0, at.y + PANEL_PADDING + TEXT_SIZE - 2.0),
				_progress.job_title(_jobs), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE,
				_jobs.jobs[_progress.job].color)
	if _world != null:
		var place := "%s   -   %s" % [_world.location_name(),
				"Safe" if _world.is_town() else "Lv %d" % _world.level()]
		draw_string(font, Vector2(x, at.y + PANEL_PADDING + TEXT_SIZE + SMALL_TEXT_SIZE + 2.0),
				place, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_TEXT_SIZE, Color(1, 1, 1, 0.7))
	var bar := Rect2(x, bars_top, inner, config.bar_height)
	_draw_bar(bar, _vitals.health / _vitals.max_health, config.health_color, _health_text())
	bar.position.y += config.bar_height + config.bar_gap
	_draw_bar(bar, _vitals.mana / _vitals.max_mana, config.mana_color,
			"%d / %d" % [floori(_vitals.mana), ceili(_vitals.max_mana)])
	if _progress != null:
		bar.position.y += config.bar_height + config.bar_gap
		bar.size.y = XP_BAR_HEIGHT
		var fraction := 1.0 if _progress.is_max_level() else _progress.xp / _progress.xp_to_next()
		_draw_bar(bar, fraction, config.xp_color, "")
		_draw_hints(Vector2(at.x, panel.end.y + 20.0))


## Skill-point and job-choice hints under the panel.
func _draw_hints(at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if _jobs != null and _progress.can_choose_job(_jobs):
		draw_string(font, at, "Choose your path - open CHAR", HORIZONTAL_ALIGNMENT_LEFT, -1,
				SMALL_TEXT_SIZE + 2, Color(1.0, 0.85, 0.35))
		at.y += SMALL_TEXT_SIZE + 8.0
	if _progress.skill_points > 0:
		draw_string(font, at, "%d skill point%s - open CHAR" % [_progress.skill_points,
				"" if _progress.skill_points == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1,
				SMALL_TEXT_SIZE + 2, config.xp_color)


## Thin gold frame with small corner blocks.
func _draw_frame(rect: Rect2) -> void:
	draw_rect(rect, config.frame_color, false, 1.5)
	var c := CORNER_SIZE
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		draw_rect(Rect2(corner - Vector2(c, c) * 0.5, Vector2(c, c)), config.frame_color)


## Rounds both numbers the same way, so health never reads above max.
func _health_text() -> String:
	var shown_max := ceili(_vitals.max_health)
	return "%d / %d" % [mini(ceili(_vitals.health), shown_max), shown_max]


func _draw_bar(rect: Rect2, fraction: float, color: Color, label: String) -> void:
	draw_rect(rect, config.bar_back_color)
	var filled := rect
	filled.size.x *= clampf(fraction, 0.0, 1.0)
	draw_rect(filled, color)
	_draw_text_centered(rect.get_center() + Vector2(0.0, TEXT_SIZE * 0.35 - 1.0), label,
			Color(1, 1, 1, 0.9), TEXT_SIZE - 4)


func _draw_minimap() -> void:
	var r := config.minimap_radius
	var center := Vector2(size.x - config.minimap_margin - r, config.minimap_margin + r)
	var yaw := _camera.yaw() if _camera != null else 0.0
	var facing := Vector2(_player.facing.x, _player.facing.z)
	HudMinimap.draw(self, center, config, _world, _player.ground_position(), facing, yaw)


func _draw_skills() -> void:
	var mana := _vitals.mana
	var pc := _player.config
	var lure_ready := _combat.lure_cooldown.progress() if pc.lure != null else 0.0
	var lure_usable := pc.lure != null and mana >= pc.lure.mana_cost
	HudSkills.draw_slot(self, config, HudSkills.slot_position(config, size, 0, SKILL_ROWS),
			HudSkills.Glyph.BOLT, "RT", 1.0, true)
	HudSkills.draw_slot(self, config, HudSkills.slot_position(config, size, 1, SKILL_ROWS),
			HudSkills.Glyph.NOVA, "RB", _combat.nova_cooldown.progress(),
			mana >= pc.nova.mana_cost)
	HudSkills.draw_slot(self, config, HudSkills.slot_position(config, size, 2, SKILL_ROWS),
			HudSkills.Glyph.LURE, "LB", lure_ready, lure_usable)
	HudSkills.draw_slot(self, config, HudSkills.slot_position(config, size, 3, SKILL_ROWS),
			HudSkills.Glyph.DODGE, "A", _player.dash_cooldown.progress(), true)


func _draw_boss_bar() -> void:
	if _bosses == null:
		return
	var target: Array = _bosses.hud_target(_player.ground_position())
	if int(target[0]) < 0:
		return
	var rect := Rect2(size.x * 0.5 - BOSS_BAR_WIDTH * 0.5, size.y * BOSS_BAR_Y, BOSS_BAR_WIDTH,
			BOSS_BAR_HEIGHT)
	_draw_bar(rect, float(target[1]), BOSS_BAR_COLOR, "")
	_draw_text_centered(Vector2(size.x * 0.5, rect.position.y - 6.0), _boss_name.to_upper(),
			BOSS_BAR_COLOR)


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
