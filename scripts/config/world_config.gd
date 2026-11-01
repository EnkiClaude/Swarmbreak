class_name WorldConfig
extends Resource
## The open world: a grid of regions with a town, dungeons behind gates, and
## how camps stream in and out around the player and come back after clearing.

@export var world_seed: int = 20261101
## Width of one square region in meters.
@export var region_size: float = 128.0
## Regions per side; regions holds grid_size * grid_size entries.
@export var grid_size: int = 3
@export var regions: Array[RegionDef] = []
@export var dungeons: Array[DungeonDef] = []

@export_group("Camps")
## Sleeping camps closer than this to the player exist in the swarm.
@export var spawn_radius: float = 90.0
## Sleeping camps farther than this leave the swarm (and come back when near).
@export var despawn_radius: float = 115.0
## Seconds before a cleared camp comes back.
@export var camp_respawn_time: float = 60.0
## A camp never comes back with the player closer than this to its center.
@export var respawn_min_distance: float = 30.0
## Spawners run while the player is within this distance.
@export var spawner_range: float = 32.0
## A sleeping camp wakes when the player comes this close to its center.
@export var aggro_radius: float = 11.0
## Spacing between members of a sleeping camp.
@export var member_spacing: float = 0.95
## Minimum distance between camp centers.
@export var camp_spacing: float = 18.0
## Keep camps this far inside their region and the world edge.
@export var edge_margin: float = 10.0
## No camps this close to a gate or to where the player arrives.
@export var keep_clear_radius: float = 16.0
@export var placement_attempts: int = 300
## Monster health, damage and XP grow by these fractions per level above 1.
@export var health_growth: float = 0.25
@export var damage_growth: float = 0.12
@export var xp_growth: float = 0.2

@export_group("Travel")
## Stepping this close to a gate goes through it.
@export var gate_radius: float = 2.5
## Seconds to fade out (and again to fade in) when going through a gate.
@export var fade_time: float = 0.3
## Seconds the atmosphere takes to settle into a new region's.
@export var atmosphere_blend_time: float = 2.0
## Fraction of a region, at each border, where floor colors blend.
@export var region_blend: float = 0.12

@export_group("World edge")
@export var edge_wall_height: float = 5.0
@export var edge_wall_color: Color = Color(0.36, 0.32, 0.28)
@export var edge_wall_trim_color: Color = Color(0.25, 0.22, 0.2)
## Width of the town's paved square.
@export var plaza_size: float = 44.0
@export var plaza_color: Color = Color(0.5, 0.47, 0.42)
@export var plaza_grout_color: Color = Color(0.3, 0.27, 0.24)
## Props in the open world keep this far from camp centers, gates and each other.
@export var prop_clearance: float = 12.0
@export var prop_spacing: float = 7.0


func half_extent() -> float:
	return region_size * grid_size * 0.5


## Index of the first town region, or 0.
func town_region() -> int:
	for k in regions.size():
		if regions[k].is_town:
			return k
	return 0
