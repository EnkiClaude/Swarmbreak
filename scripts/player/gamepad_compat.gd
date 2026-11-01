class_name GamepadCompat
extends RefCounted
## Makes the right trigger fire on controllers Godot has no layout for.
## Browsers and some drivers report such pads raw, where the right trigger
## arrives as button 7 (the left-stick click in Godot's layout) or as axis 5
## resting at -1. For those pads only, a held trigger presses attack_fire,
## and raw button 7 must not toggle the debug overlay (is_raw_l3()).

const RAW_TRIGGER_BUTTON := 7
const TRIGGER_THRESHOLD := 0.3

var _pressing := false


## True if the event is a raw pad's button 7: really its right trigger.
static func is_raw_l3(event: InputEvent) -> bool:
	return event is InputEventJoypadButton \
			and (event as InputEventJoypadButton).button_index == RAW_TRIGGER_BUTTON \
			and not Input.is_joy_known(event.device)


## Call every frame: holds attack_fire while a raw pad's trigger is held.
func tick() -> void:
	var held := false
	for device in Input.get_connected_joypads():
		if Input.is_joy_known(device):
			continue
		if Input.is_joy_button_pressed(device, RAW_TRIGGER_BUTTON) \
				or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_THRESHOLD:
			held = true
	if held and not _pressing:
		Input.action_press("attack_fire")
	elif not held and _pressing:
		Input.action_release("attack_fire")
	_pressing = held


## "Xbox Controller (mapped)" lines for the debug overlay.
static func describe() -> String:
	var lines: PackedStringArray = []
	for device in Input.get_connected_joypads():
		lines.append("%s (%s)" % [Input.get_joy_name(device),
				"mapped" if Input.is_joy_known(device) else "raw"])
	return ", ".join(lines) if not lines.is_empty() else "none"
