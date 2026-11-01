class_name BoltConfig
extends Resource
## Aimed bolts that burst on the first enemy they touch or at max range.

@export var speed: float = 24.0
@export var fire_interval: float = 0.15
## Seconds before a bolt bursts on its own.
@export var lifetime: float = 0.9
## Collision radius; touching an enemy also counts its body radius.
@export var hit_radius: float = 0.2
@export var burst_radius: float = 1.5
@export var damage: float = 12.0
@export var knockback: float = 4.0
## Distance in front of the player's center where bolts appear.
@export var muzzle_offset: float = 0.6
@export var height: float = 0.9
@export var size: float = 0.18
@export var color: Color = Color(1.0, 0.85, 0.4)
## Pool size: the most bolts in flight at once.
@export var capacity: int = 64
## Bolts bend toward the nearest enemy within this many degrees of the aim.
@export var aim_assist_degrees: float = 12.0
## Only enemies this close count for aim assist.
@export var aim_assist_range: float = 20.0
@export var burst_effect: EffectType
