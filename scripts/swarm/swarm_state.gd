class_name SwarmState
extends RefCounted
## Packed-array storage for every live enemy. An enemy is an index, never a Node.
## Slots [0, count) are in use. Enemies killed during a frame keep their slot
## (health <= 0) until remove_dead() compacts the arrays, so indices are
## stable within a frame but not across frames. Fixed capacity: nothing here
## allocates after _init.

var capacity: int
var count: int = 0
## Positions and velocities live on the XZ plane: Vector2.y is world Z.
var positions: PackedVector2Array
var velocities: PackedVector2Array
var type_ids: PackedInt32Array
var health: PackedFloat32Array
## Swarm time until which the enemy shows its hit flash.
var flash_until: PackedFloat32Array
## Filled by remove_dead(): where the enemies removed this frame died.
var dead_positions: PackedVector2Array
var dead_types: PackedInt32Array
## Velocity at death, which includes the killing blow's knockback.
var dead_velocities: PackedVector2Array


func _init(p_capacity: int) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	positions.fill(Vector2.ZERO)
	velocities.resize(capacity)
	velocities.fill(Vector2.ZERO)
	type_ids.resize(capacity)
	type_ids.fill(0)
	health.resize(capacity)
	health.fill(0.0)
	flash_until.resize(capacity)
	flash_until.fill(0.0)
	dead_positions.resize(capacity)
	dead_positions.fill(Vector2.ZERO)
	dead_types.resize(capacity)
	dead_types.fill(0)
	dead_velocities.resize(capacity)
	dead_velocities.fill(Vector2.ZERO)


## Returns the new enemy's index, or -1 if the pool is full.
func spawn(pos: Vector2, type_id: int, max_health: float = 1.0) -> int:
	if count >= capacity:
		return -1
	var i := count
	positions[i] = pos
	velocities[i] = Vector2.ZERO
	type_ids[i] = type_id
	health[i] = max_health
	flash_until[i] = 0.0
	count += 1
	return i


## Indices are not stable: the enemy that was last now lives at i.
func despawn(i: int) -> void:
	var last := count - 1
	if i != last:
		_move(last, i)
	count = last


## Removes every enemy with health <= 0, keeping survivors in order. Writes
## the dead into dead_positions / dead_types / dead_velocities and returns
## how many died.
func remove_dead() -> int:
	var write := 0
	var dead := 0
	for read in count:
		if health[read] > 0.0:
			if write != read:
				_move(read, write)
			write += 1
		else:
			dead_positions[dead] = positions[read]
			dead_types[dead] = type_ids[read]
			dead_velocities[dead] = velocities[read]
			dead += 1
	count = write
	return dead


func clear() -> void:
	count = 0


func _move(from: int, to: int) -> void:
	positions[to] = positions[from]
	velocities[to] = velocities[from]
	type_ids[to] = type_ids[from]
	health[to] = health[from]
	flash_until[to] = flash_until[from]
