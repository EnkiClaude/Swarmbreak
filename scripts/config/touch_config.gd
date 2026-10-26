class_name TouchConfig
extends Resource
## On-screen controls for touchscreens. Positions are fractions of the screen
## (0,0 top-left, 1,1 bottom-right); sizes are in viewport pixels at 1280x800.

## Show the controls even without a touchscreen (handy for testing on desktop).
@export var show_without_touchscreen: bool = false
## How far the thumb travels from where it landed for full deflection.
@export var stick_radius: float = 110.0
@export var knob_radius: float = 44.0
## Where the faint stick hints sit before a thumb lands.
@export var move_hint_position: Vector2 = Vector2(0.14, 0.74)
## Hold to fire bolts; drag from it to aim while firing.
@export var fire_button_position: Vector2 = Vector2(0.86, 0.74)
@export var fire_button_radius: float = 80.0
@export var nova_button_position: Vector2 = Vector2(0.9, 0.36)
@export var nova_button_radius: float = 72.0
@export var spawn_button_position: Vector2 = Vector2(0.6, 0.07)
@export var overlay_button_position: Vector2 = Vector2(0.4, 0.07)
@export var small_button_radius: float = 38.0
@export var color: Color = Color(1, 1, 1, 0.35)
@export var active_color: Color = Color(1, 1, 1, 0.7)
@export var nova_color: Color = Color(0.5, 0.85, 1, 0.55)
