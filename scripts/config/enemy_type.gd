class_name EnemyType
extends Resource
## Tuning for one kind of swarm enemy. Each type gets its own MultiMesh.

@export var display_name: String = "Enemy"
@export var color: Color = Color(0.85, 0.25, 0.2)
@export var max_health: float = 20.0
## XP the player earns for killing one.
@export var xp: float = 1.0
@export var body_radius: float = 0.35
@export var body_height: float = 1.0
@export var max_speed: float = 4.0
## Meters per second squared toward the desired velocity.
@export var acceleration: float = 14.0
## Neighbours closer than this push each other apart. Must not exceed the
## swarm's hash cell size, or some neighbours will be missed.
@export var separation_radius: float = 0.8
## Meters per second of push at full overlap, summed over neighbours.
@export var separation_strength: float = 6.0
## Damage per second dealt to the player while touching it.
@export var contact_dps: float = 6.0
## Extra reach beyond touching that still counts as hitting the player.
@export var attack_reach: float = 0.2
@export var cast_shadow: bool = false
@export var death_effect: EffectType
