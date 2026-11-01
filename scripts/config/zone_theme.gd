class_name ZoneTheme
extends Resource
## How a zone looks: floor pattern, walls, pillars, lanterns, scenery outside
## the walls, sky, fog and light. Purely visual; gameplay never reads it.
## ZoneConfig.themes lists them, and zone levels cycle through the list.

enum FloorPattern { TILES, FLAGSTONES, GROUND }

@export var display_name: String = "Zone"

@export_group("Floor")
@export var floor_pattern: FloorPattern = FloorPattern.TILES
@export var floor_color: Color = Color(0.5, 0.15, 0.1)
## TILES: every other tile leans this way. FLAGSTONES: random per stone.
## GROUND: large patches.
@export var floor_alt_color: Color = Color(0.42, 0.12, 0.08)
@export var grout_color: Color = Color(0.2, 0.08, 0.05)
## Gold lines framing every inlay_every x inlay_every block of tiles; 0 = none.
@export var inlay_color: Color = Color(0.85, 0.65, 0.25)
@export var inlay_every: int = 0
@export var tile_size: float = 2.0
@export var grout_width: float = 0.06
## How much the floor's color varies with noise, 0..1.
@export var floor_noise: float = 0.15
@export var floor_roughness: float = 0.6

@export_group("Walls")
@export var wall_height: float = 7.0
@export var wall_color: Color = Color(0.15, 0.32, 0.25)
## Bands along the bottom and top of the wall.
@export var wall_trim_color: Color = Color(0.55, 0.12, 0.08)
## A ceiling closes the hall above this height; 0 leaves it open to the sky.
@export var ceiling_height: float = 0.0
@export var ceiling_color: Color = Color(0.12, 0.06, 0.04)

@export_group("Pillars")
## Distance between pillars along the walls; 0 = no pillars.
@export var pillar_spacing: float = 0.0
@export var pillar_height: float = 6.0
@export var pillar_radius: float = 0.55
@export var pillar_color: Color = Color(0.6, 0.12, 0.08)
## Base and capital.
@export var pillar_trim_color: Color = Color(0.85, 0.65, 0.25)
## Every this many pillars carries a lantern; 0 = no lanterns.
@export var lantern_every: int = 0
@export var lantern_color: Color = Color(1.0, 0.75, 0.45)

@export_group("Outside")
## Houses with stacked roofs placed outside the walls.
@export var house_count: int = 0
@export var house_color: Color = Color(0.55, 0.45, 0.35)
@export var roof_color: Color = Color(0.2, 0.22, 0.26)
@export var tree_count: int = 0
@export var trunk_color: Color = Color(0.3, 0.22, 0.15)
## Leaf color; fully transparent makes bare, dead trees.
@export var leaf_color: Color = Color(0.3, 0.5, 0.2)
## How far outside the walls scenery and ground reach, in meters.
@export var outside_reach: float = 40.0

@export_group("Atmosphere")
## Outdoor zones show a sky; indoor ones a flat background.
@export var show_sky: bool = true
@export var sky_top_color: Color = Color(0.35, 0.5, 0.75)
@export var sky_horizon_color: Color = Color(0.75, 0.8, 0.85)
@export var background_color: Color = Color(0.05, 0.04, 0.04)
@export var fog_color: Color = Color(0.7, 0.75, 0.8)
@export var fog_density: float = 0.01
@export var ambient_color: Color = Color(0.6, 0.62, 0.7)
@export var ambient_energy: float = 0.6
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 1.2
## Degrees above the horizon.
@export var sun_elevation: float = 50.0
## Degrees around the vertical axis the sunlight comes from.
@export var sun_azimuth: float = 35.0
## Bloom on bright things (lanterns, spells).
@export var glow_strength: float = 0.8
