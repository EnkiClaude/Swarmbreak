class_name CameraConfig
extends Resource
## Angled orthographic follow camera.

## Degrees below the horizon the camera looks down.
@export var pitch_degrees: float = 55.0
## Rotation around the vertical axis; 45 gives the classic diagonal ARPG view.
@export var yaw_degrees: float = 45.0
## Distance from the target along the view axis. Ortho, so this only affects clipping.
@export var distance: float = 40.0
## Visible height of the view in meters.
@export var ortho_size: float = 30.0
## Higher is snappier. Used as an exponential decay rate per second.
@export var follow_sharpness: float = 10.0
## Camera offset in meters at full shake trauma.
@export var shake_max_offset: float = 0.9
## Trauma lost per second.
@export var shake_decay: float = 2.2
## How fast the shake wobbles.
@export var shake_frequency: float = 28.0
