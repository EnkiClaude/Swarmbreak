class_name TouchControls
extends Control
## On-screen twin-stick controls for touchscreens. The left half of the screen
## is a floating move stick. On the right, the FIRE button is also a stick:
## hold it to fire and drag from it to aim (no drag fires where the player
## faces). Plus NOVA, spawn and overlay buttons.
##
## Everything is translated into the same input actions a controller presses,
## so gameplay code never knows the input came from touch.

const MOVE_ACTIONS: PackedStringArray = ["move_left", "move_right", "move_up", "move_down"]
const AIM_ACTIONS: PackedStringArray = ["aim_left", "aim_right", "aim_up", "aim_down"]
const RING_WIDTH := 3.0
const LABEL_SIZE := 22

@export var config: TouchConfig

var _move: VirtualStick
## The FIRE button's stick: held means firing, deflection aims.
var _aim: VirtualStick
## Touch index -> action name, for buttons currently held down.
var _held_buttons: Dictionary = {}
var _active := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move = VirtualStick.new(config.stick_radius)
	_aim = VirtualStick.new(config.stick_radius)
	set_active(config.show_without_touchscreen or DisplayServer.is_touchscreen_available())


func set_active(active: bool) -> void:
	_active = active
	visible = active
	if not active:
		_release_all()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not _active:
			set_active(true)  # first touch on a device that didn't report a touchscreen
		handle_touch(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		handle_drag(drag.index, drag.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all()


## Public so tests can drive touches without going through the window.
func handle_touch(index: int, at: Vector2, pressed: bool) -> void:
	if not pressed:
		_end_touch(index)
		queue_redraw()
		return
	var button := _button_at(at)
	var fire_center := _screen(config.fire_button_position)
	if button != "":
		_held_buttons[index] = button
		_send_action(button, true)
	elif at.distance_to(fire_center) <= config.fire_button_radius:
		if not _aim.is_held():
			_aim.press(index, fire_center)
			_aim.drag(at)
			_apply_stick(_aim, AIM_ACTIONS)
			_send_action("attack_fire", true)
	elif at.x < size.x * 0.5 and not _move.is_held():
		_move.press(index, at)
	queue_redraw()


func handle_drag(index: int, at: Vector2) -> void:
	if index == _move.touch_index:
		_move.drag(at)
		_apply_stick(_move, MOVE_ACTIONS)
	elif index == _aim.touch_index:
		_aim.drag(at)
		_apply_stick(_aim, AIM_ACTIONS)
	else:
		return
	queue_redraw()


func _end_touch(index: int) -> void:
	if _held_buttons.has(index):
		_send_action(_held_buttons[index], false)
		_held_buttons.erase(index)
	if index == _move.touch_index:
		_move.release()
		_apply_stick(_move, MOVE_ACTIONS)
	if index == _aim.touch_index:
		_aim.release()
		_apply_stick(_aim, AIM_ACTIONS)
		_send_action("attack_fire", false)


func _release_all() -> void:
	for index in _held_buttons.keys():
		_send_action(_held_buttons[index], false)
	_held_buttons.clear()
	if _move != null:
		_move.release()
		_apply_stick(_move, MOVE_ACTIONS)
	if _aim != null and _aim.is_held():
		_aim.release()
		_apply_stick(_aim, AIM_ACTIONS)
		_send_action("attack_fire", false)
	queue_redraw()


## Presses each direction action with the stick's strength along it.
func _apply_stick(stick: VirtualStick, actions: PackedStringArray) -> void:
	var v := stick.vector
	_set_strength(actions[0], maxf(-v.x, 0.0))
	_set_strength(actions[1], maxf(v.x, 0.0))
	_set_strength(actions[2], maxf(-v.y, 0.0))
	_set_strength(actions[3], maxf(v.y, 0.0))


func _set_strength(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## Buttons go through the event queue so both polled actions and
## _unhandled_input handlers (debug spawn, overlay toggle) see them.
func _send_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _button_at(at: Vector2) -> String:
	if at.distance_to(_screen(config.nova_button_position)) <= config.nova_button_radius:
		return "attack_nova"
	if at.distance_to(_screen(config.spawn_button_position)) <= config.small_button_radius:
		return "debug_spawn"
	if at.distance_to(_screen(config.overlay_button_position)) <= config.small_button_radius:
		return "debug_toggle_overlay"
	return ""


func _screen(fraction: Vector2) -> Vector2:
	return fraction * size


func _draw() -> void:
	_draw_stick(_move, _screen(config.move_hint_position), "MOVE")
	_draw_fire_stick()
	_draw_button(config.nova_button_position, config.nova_button_radius, "NOVA",
			"attack_nova", config.nova_color)
	_draw_button(config.spawn_button_position, config.small_button_radius, "+100",
			"debug_spawn", config.color)
	_draw_button(config.overlay_button_position, config.small_button_radius, "HUD",
			"debug_toggle_overlay", config.color)


func _draw_stick(stick: VirtualStick, hint: Vector2, label: String) -> void:
	if not stick.is_held():
		draw_arc(hint, config.stick_radius, 0.0, TAU, 48, config.color, RING_WIDTH)
		_draw_label(hint, label, config.color)
		return
	draw_arc(stick.origin, config.stick_radius, 0.0, TAU, 48, config.active_color, RING_WIDTH)
	draw_circle(stick.origin + stick.vector * config.stick_radius, config.knob_radius,
			config.active_color)


func _draw_fire_stick() -> void:
	var center := _screen(config.fire_button_position)
	if not _aim.is_held():
		draw_circle(center, config.fire_button_radius, config.color)
		_draw_label(center, "FIRE", Color(1, 1, 1, 0.9))
		return
	draw_circle(center, config.fire_button_radius, config.active_color)
	draw_arc(center, config.stick_radius, 0.0, TAU, 48, config.active_color, RING_WIDTH)
	draw_circle(center + _aim.vector * config.stick_radius, config.knob_radius,
			Color(1, 0.85, 0.4, 0.85))


func _draw_button(fraction: Vector2, radius: float, label: String, action: String,
		color: Color) -> void:
	var center := _screen(fraction)
	var held := _held_buttons.values().has(action)
	draw_circle(center, radius, config.active_color if held else color)
	_draw_label(center, label, Color(0, 0, 0, 0.8) if held else Color(1, 1, 1, 0.9))


func _draw_label(center: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(font, center + Vector2(-width * 0.5, LABEL_SIZE * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)
