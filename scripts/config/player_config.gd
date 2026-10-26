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
@export var max_health: float = 100.0
@export var health_regen: float = 1.5
@export var max_mana: float = 100.0
@export var mana_regen: float = 9.0
## Mana gained per enemy killed, so big breaks refuel the next one.
@export var mana_per_kill: float = 0.35
@export var dash_distance: float = 5.5
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.7
## Invulnerable for the dash plus this long after it.
@export var dash_grace: float = 0.12
## After dying, seconds before the zone restarts.
@export var respawn_delay: float = 2.0
@export var nova: NovaConfig
@export var bolt: BoltConfig
@export var lure: LureConfig
