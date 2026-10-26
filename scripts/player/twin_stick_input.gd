class_name TwinStickInput
extends RefCounted
## Reads move and aim intent. Controller first: the right stick aims, and the
## mouse only takes over aiming after it moves or clicks. Any stick, button or
## touch use hands aiming back to the stick (touch controls drive the aim actions).

enum AimSource { STICK, MOUSE }

## Stick deflection that counts as "the player picked up the controller".
const STICK_WAKE_THRESHOLD := 0.3

var aim_source := AimSource.STICK


func observe(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_source = AimSource.MOUSE
	elif event is InputEventJoypadButton or event is InputEventScreenTouch:
		aim_source = AimSource.STICK
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_WAKE_THRESHOLD:
			aim_source = AimSource.STICK


## Screen-space move intent: x right, y down, length <= 1.
func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Screen-space right-stick aim, or zero inside the deadzone.
func stick_aim() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
