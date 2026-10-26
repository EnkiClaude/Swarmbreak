class_name ZoneConfig
extends Resource
## How a zone's enemy camps are generated. Each zone level reuses this with
## more and bigger camps. Generation is seeded, so a level always looks the same.

@export var zone_seed: int = 20261026
@export var camp_count: int = 16
@export var camps_per_level: int = 3
@export var camp_size_min: int = 12
@export var camp_size_max: int = 36
## Camp sizes multiply by this each level.
@export var camp_size_growth: float = 1.15
## Chance each camp member is the second enemy type (brutes).
@export var heavy_chance: float = 0.1
## Spacing between members of a sleeping camp.
@export var member_spacing: float = 0.95
## A sleeping camp wakes when the player comes this close to its center.
@export var aggro_radius: float = 11.0
## No camp closer than this to where the player starts.
@export var safe_start_radius: float = 24.0
## Minimum distance between camp centers.
@export var camp_spacing: float = 17.0
## Keep camps this far inside the arena edge.
@export var edge_margin: float = 8.0
@export var placement_attempts: int = 400
## Most camps a zone can hold (sizes the wake flags).
@export var max_camps: int = 128
