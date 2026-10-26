class_name SwarmConfig
extends Resource
## Swarm-wide tuning: pool size, spawning, and grid resolutions.

## Preallocated enemy slots. Spawns beyond this are dropped.
@export var capacity: int = 4096
@export var initial_count: int = 1000
@export var debug_spawn_batch: int = 100
## New enemies appear in a ring between these distances from the player.
@export var spawn_min_distance: float = 16.0
@export var spawn_max_distance: float = 36.0
## Spatial hash cell edge in meters. Keep >= the largest separation radius.
@export var hash_cell_size: float = 1.0
## Flow field cell edge in meters.
@export var flow_cell_size: float = 2.0
## Inside this distance enemies steer straight at the player instead of the field.
@export var direct_chase_distance: float = 3.0
## Frame deltas are clamped to this so a hitch can't tunnel enemies through each other.
@export var max_tick_delta: float = 0.05
@export var enemy_types: Array[EnemyType] = []
