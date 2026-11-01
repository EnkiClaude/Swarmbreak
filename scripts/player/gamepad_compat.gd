class_name GamepadCompat
extends RefCounted
## Makes the triggers work on controllers Godot has no layout for. Browsers
## and some drivers report such pads raw, where the left and right triggers
## arrive as buttons 6 and 7 (Start and the left-stick click in Godot's
## layout) or as axes 4 and 5 resting at -1. For those pads only, a held
## right trigger presses attack_fire and a held left trigger presses dodge,
## and buttons 6 and 7 must not open the menu or toggle the overlay
## (is_raw_trigger()).

const RAW_LEFT_TRIGGER := 6
const RAW_RIGHT_TRIGGER := 7
const TRIGGER_THRESHOLD := 0.3

var _firing := false
var _dodging := false


## True if the event is a raw pad's button 6 or 7: really a trigger.
static func is_raw_trigger(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton or Input.is_joy_known(event.device):
		return false
	var button := (event as InputEventJoypadButton).button_index
	return button == RAW_LEFT_TRIGGER or button == RAW_RIGHT_TRIGGER


## Call every frame: holds the trigger actions while a raw pad's triggers are held.
func tick() -> void:
	var fire := false
	var dodge := false
	for device in Input.get_connected_joypads():
		if Input.is_joy_known(device):
			continue
		fire = fire or Input.is_joy_button_pressed(device, RAW_RIGHT_TRIGGER) \
				or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_THRESHOLD
		dodge = dodge or Input.is_joy_button_pressed(device, RAW_LEFT_TRIGGER) \
				or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > TRIGGER_THRESHOLD
	_firing = _hold("attack_fire", fire, _firing)
	_dodging = _hold("dodge", dodge, _dodging)


static func _hold(action: String, held: bool, was: bool) -> bool:
	if held and not was:
		Input.action_press(action)
	elif not held and was:
		Input.action_release(action)
	return held


## "Xbox Controller (mapped)" lines for the debug overlay.
static func describe() -> String:
	var lines: PackedStringArray = []
	for device in Input.get_connected_joypads():
		lines.append("%s (%s)" % [Input.get_joy_name(device),
				"mapped" if Input.is_joy_known(device) else "raw"])
	return ", ".join(lines) if not lines.is_empty() else "none"
