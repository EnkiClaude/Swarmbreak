class_name BreakPopup
extends CanvasLayer
## The "x274 BREAK!" callout, also used for zone messages. A single reused
## label: a bigger break replaces a smaller one still on screen, and a
## message is never replaced by a break. It pops in large, settles, then fades.

const POP_IN_TIME := 0.12
const POP_SCALE := 1.6
const SCREEN_Y := 0.22

var _config: FeedbackConfig
var _label: Label
var _settings: LabelSettings
var _age := 0.0
var _duration := 1.0
var _kills := 0


func setup(config: FeedbackConfig) -> void:
	_config = config
	layer = 90
	_settings = LabelSettings.new()
	_settings.font_color = config.popup_color
	_settings.outline_color = config.popup_outline_color
	_settings.outline_size = 10
	_label = Label.new()
	_label.label_settings = _settings
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	_age = config.popup_duration
	_duration = config.popup_duration


func show_break(kills: int) -> void:
	if kills < _config.popup_min_kills:
		return
	if _label.visible and kills < _kills:
		return
	_kills = kills
	_age = 0.0
	_duration = _config.popup_duration
	_settings.font_color = _config.popup_color
	var doublings := log(float(kills) / _config.popup_min_kills) / log(2.0)
	_settings.font_size = mini(_config.popup_max_size,
			_config.popup_base_size + roundi(doublings * _config.popup_size_per_doubling))
	_label.text = "x%d BREAK!" % kills
	_label.visible = true


## Shows text such as "ZONE 2" or "YOU DIED" for duration seconds.
func show_message(text: String, color: Color, duration: float) -> void:
	_kills = 1 << 30
	_age = 0.0
	_duration = duration
	_settings.font_size = _config.popup_max_size
	_settings.font_color = color
	_label.text = text
	_label.visible = true


func is_showing() -> bool:
	return _label.visible


func tick(delta: float) -> void:
	if not _label.visible:
		return
	_age += delta
	if _age >= _duration:
		_label.visible = false
		return
	var pop := clampf(_age / POP_IN_TIME, 0.0, 1.0)
	var s := lerpf(POP_SCALE, 1.0, 1.0 - pow(1.0 - pop, 3.0))
	var fade_start := _duration * 0.6
	var alpha := 1.0 if _age < fade_start else 1.0 - (_age - fade_start) / (_duration - fade_start)
	var screen := _label.get_viewport_rect().size
	_label.size = Vector2(screen.x, _settings.font_size * 2.0)
	_label.pivot_offset = _label.size * 0.5
	_label.position = Vector2(0.0, screen.y * SCREEN_Y - _label.size.y * 0.5)
	_label.scale = Vector2(s, s)
	_label.modulate.a = alpha
