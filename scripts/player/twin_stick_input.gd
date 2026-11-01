class_name TwinStickInput
extends RefCounted
## Reads move intent. The left stick (or WASD, or the touch move stick) moves
## relative to the camera; the right stick turns the camera (see CameraRig),
## and attacks go where the camera looks.


## Screen-space move intent: x right, y down, length <= 1.
func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
