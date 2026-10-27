class_name JobPerks
extends Resource
## What one rank of a job does. A rank's perks replace the previous rank's,
## so rank 2 lists everything rank 1 had plus more.

@export_group("Nova")
## Extra, wider pulses after each nova.
@export var nova_aftershocks: int = 0
@export var aftershock_delay: float = 0.35
@export var aftershock_radius_multiplier: float = 1.35
@export var aftershock_damage_multiplier: float = 0.55

@export_group("Lure")
## Enemies the lure reaches are marked this long and take extra damage.
@export var lure_mark_duration: float = 0.0
@export var mark_damage_bonus: float = 0.0
@export var lure_cooldown_multiplier: float = 1.0
## Damage reduction the lure grants the player for lure_armor_duration.
@export var lure_armor: float = 0.0
@export var lure_armor_duration: float = 0.0

@export_group("Bolts")
## Enemies a bolt bursts on before it stops.
@export var bolt_pierce: int = 0
@export var burst_radius_multiplier: float = 1.0

@export_group("Stats")
@export var stats: Array[PlayerStat.Id] = []
@export var values: PackedFloat32Array = []
