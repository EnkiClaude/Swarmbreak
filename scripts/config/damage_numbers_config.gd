class_name DamageNumbersConfig
extends Resource
## Floating damage numbers over hit enemies.

## Most numbers on screen at once; extra hits show none.
@export var capacity: int = 48
## Most numbers one blow shows, spread over the enemies it hit.
@export var per_blow: int = 6
@export var lifetime: float = 0.75
## Meters per second the numbers float up.
@export var rise_speed: float = 1.8
## Height above the ground a number starts at.
@export var start_height: float = 1.4
## Random sideways scatter in meters, so numbers on a pack don't stack.
@export var scatter: float = 0.4
@export var font_size: int = 64
@export var outline_size: int = 14
## World size of one font pixel.
@export var pixel_size: float = 0.012
@export var color: Color = Color(1.0, 0.95, 0.85)
@export var outline_color: Color = Color(0.15, 0.05, 0.0)
## Hits of at least big_damage show in big_color and bigger.
@export var big_damage: float = 40.0
@export var big_color: Color = Color(1.0, 0.75, 0.2)
@export var big_scale: float = 1.4
