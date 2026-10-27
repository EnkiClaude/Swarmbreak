class_name SwarmConfig
extends Resource
## Swarm-wide tuning: pool size, spawning, and grid resolutions.

## Preallocated enemy slots. Spawns beyond this are dropped.
@export var capacity: int = 4096
@export var debug_spawn_batch: int = 100
## New enemies appear in a ring between these distances from the player.
@export var spawn_min_distance: float = 16.0
@export var spawn_max_distance: float = 36.0
## Spatial hash cell edge in meters. Separation scans every cell its radius
## overlaps, so any radius works; near the common separation radius is fastest.
@export var hash_cell_size: float = 1.2
## Spatial hash table size (rounded up to a power of two). Cost of a rebuild
## scales with this, not with map size.
@export var hash_buckets: int = 4096
## Most enemies whose touch hurts the player at once, so a huge pack around
## you is dangerous but survivable long enough to break it.
@export var max_attackers: int = 10
## Flow field cell edge in meters.
@export var flow_cell_size: float = 2.0
## Inside this distance enemies steer straight at the player instead of the field.
## Separation considers at most this many neighbours per enemy. Lower is
## cheaper in dense packs but lets crowds compress more.
@export var max_separation_neighbours: int = 8
@export var direct_chase_distance: float = 3.0
## Frame deltas are clamped to this so a hitch can't tunnel enemies through each other.
@export var max_tick_delta: float = 0.05
## How long an enemy shows the flash color after taking damage.
@export var hit_flash_duration: float = 0.08
@export var hit_flash_color: Color = Color(1, 1, 1)
@export var enemy_types: Array[EnemyType] = []
