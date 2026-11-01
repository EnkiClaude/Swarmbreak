class_name CameraConfig
extends Resource
## Third-person follow camera: hangs behind and above the player, and the
## right stick (or the captured mouse) turns it around the player and tilts it.

## Field of view in degrees (vertical).
@export var fov_degrees: float = 55.0
## Degrees below the horizon the camera looks down after going through a gate.
@export var pitch_degrees: float = 26.0
## Tilt limits for the right stick and mouse.
@export var min_pitch_degrees: float = 10.0
@export var max_pitch_degrees: float = 60.0
## Rotation around the vertical axis after going through a gate; 0 looks toward -Z.
@export var yaw_degrees: float = 0.0
## Distance from the look point to the camera at the closest zoom.
@export var distance: float = 11.0
## Distance at the farthest zoom.
@export var max_distance: float = 30.0
## Meters per mouse-wheel notch or D-pad press.
@export var zoom_step: float = 2.5
## Levels the zoom-cycle button steps through, closest to farthest.
@export var zoom_levels: int = 3
## Higher eases into a new zoom faster (exponential rate per second).
@export var zoom_sharpness: float = 10.0
## Shortest distance the camera pulls in to when it would leave the arena.
@export var min_distance: float = 3.0
## Keep the camera this far inside the arena edge, so walls don't block the view.
@export var wall_margin: float = 1.0
## The camera looks at this point above the player's feet.
@export var look_height: float = 1.5
## Degrees per second at full right-stick deflection.
@export var turn_speed: float = 150.0
## Degrees per second of tilt at full right-stick deflection.
@export var tilt_speed: float = 70.0
## Degrees per pixel of mouse movement while the mouse is captured.
@export var mouse_sensitivity: float = 0.18
## Nothing beyond this distance is drawn; fog should hide the cut.
@export var far: float = 150.0
## Higher is snappier. Used as an exponential decay rate per second.
@export var follow_sharpness: float = 12.0
## Camera offset in meters at full shake trauma.
@export var shake_max_offset: float = 0.35
## Trauma lost per second.
@export var shake_decay: float = 2.2
## How fast the shake wobbles.
@export var shake_frequency: float = 28.0
