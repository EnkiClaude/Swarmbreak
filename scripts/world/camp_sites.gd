class_name CampSites
extends RefCounted
## Every camp site of one space (the open world or one dungeon), as parallel
## packed arrays: where it is, how big, how hard, and what it is now. The
## runtime part (state, alive, awake, timers) lives here too, so a space keeps
## its cleared camps and timers while the player is somewhere else.

enum State { DORMANT, SPAWNED, CLEARED }

## Static: fixed when the world is generated.
var centers := PackedVector2Array()
var sizes := PackedInt32Array()
var levels := PackedInt32Array()
var heavy_chance := PackedFloat32Array()
## 1 = a boss stands at the center.
var has_boss := PackedByteArray()
## 1 = a spawner: never clears, refills one monster every spawn_interval.
var is_spawner := PackedByteArray()
var spawn_interval := PackedFloat32Array()

## Runtime.
var state := PackedByteArray()
## Living members; the planned size while dormant, 0 once cleared.
var alive := PackedInt32Array()
var awake := PackedByteArray()
## Swarm time a cleared camp may come back, or a spawner may add its next monster.
var timer := PackedFloat32Array()


func size() -> int:
	return centers.size()


## Adds a site, dormant. Returns its index (the swarm camp id while active).
func add(center: Vector2, members: int, level: int, heavy: float, boss: bool = false,
		spawner: bool = false, interval: float = 0.0) -> int:
	centers.append(center)
	sizes.append(members)
	levels.append(level)
	heavy_chance.append(heavy)
	has_boss.append(1 if boss else 0)
	is_spawner.append(1 if spawner else 0)
	spawn_interval.append(interval)
	state.append(State.DORMANT)
	alive.append(members)
	awake.append(0)
	timer.append(0.0)
	return centers.size() - 1


## Puts every site that isn't cleared back to dormant: its members left the
## swarm (the player left the space, or the swarm was cleared).
func put_to_sleep() -> void:
	for s in centers.size():
		if state[s] == State.SPAWNED:
			make_dormant(s)


func make_dormant(s: int) -> void:
	state[s] = State.DORMANT
	alive[s] = sizes[s]
	awake[s] = 0
