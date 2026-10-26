class_name FeedbackConfig
extends Resource
## How hard the game reacts to hits: freeze-frames, shake, break popups,
## flying corpses and vibration. Bigger breaks react harder.

@export_group("Hit-stop")
## Kills in one hit needed before the game freezes for an instant.
@export var hitstop_min_kills: int = 6
@export var hitstop_base: float = 0.03
@export var hitstop_per_kill: float = 0.0012
@export var hitstop_max: float = 0.14

@export_group("Shake")
## Shake "trauma" is 0..1; the camera's offset grows with its square.
@export var shake_nova: float = 0.35
@export var shake_bolt_burst: float = 0.08
@export var shake_per_kill: float = 0.006
@export var shake_kills_max: float = 0.5

@export_group("Break popup")
@export var popup_min_kills: int = 10
@export var popup_duration: float = 1.0
@export var popup_base_size: int = 44
## Extra font size per doubling of kills above popup_min_kills.
@export var popup_size_per_doubling: int = 10
@export var popup_max_size: int = 110
@export var popup_color: Color = Color(1.0, 0.82, 0.35)
@export var popup_outline_color: Color = Color(0.25, 0.08, 0.02)

@export_group("Corpses")
## Dead enemies keep this much of their velocity (which includes knockback).
@export var corpse_fling_scale: float = 1.3
@export var corpse_up_speed_min: float = 3.0
@export var corpse_up_speed_max: float = 7.0
@export var corpse_spin_max: float = 14.0
@export var corpse_gravity: float = 22.0
@export var corpse_bounce: float = 0.3
@export var corpse_ground_friction: float = 0.55
@export var corpse_lifetime: float = 0.9
## Fraction of lifetime after which corpses shrink away.
@export var corpse_shrink_start: float = 0.65
@export var corpse_darken: float = 0.45
@export var corpse_capacity: int = 800

@export_group("Vibration")
@export var vibration_enabled: bool = true
@export var vibration_nova: float = 0.35
@export var vibration_per_kill: float = 0.01
@export var vibration_max: float = 1.0
@export var vibration_duration: float = 0.18
