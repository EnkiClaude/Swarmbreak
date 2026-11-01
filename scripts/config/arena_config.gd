class_name ArenaConfig
extends Resource
## Size of the combat arena. How it looks comes from the zone's ZoneTheme.

## The arena is a square spanning -half_extent..half_extent on X and Z, in meters.
@export var half_extent: float = 64.0
@export var wall_thickness: float = 0.8
