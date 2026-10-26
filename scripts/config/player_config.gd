class_name PlayerConfig
extends Resource
## Player movement and body tuning.

@export var move_speed: float = 7.0
## Meters per second squared; high values feel snappy on a stick.
@export var acceleration: float = 60.0
## Body radius used to keep enemies out of the player.
@export var radius: float = 0.45
@export var height: float = 1.8
@export var color: Color = Color(0.3, 0.75, 1.0)
