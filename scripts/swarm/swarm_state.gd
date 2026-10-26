class_name SwarmState
extends RefCounted
## Packed-array storage for every live enemy. An enemy is an index, never a Node.
## Slots [0, count) are alive. Despawning swaps the last live enemy into the
## hole, so the arrays act as a fixed-capacity pool that never allocates.

var capacity: int
var count: int = 0
## Positions and velocities live on the XZ plane: Vector2.y is world Z.
var positions: PackedVector2Array
var velocities: PackedVector2Array
var type_ids: PackedInt32Array


func _init(p_capacity: int) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	positions.fill(Vector2.ZERO)
	velocities.resize(capacity)
	velocities.fill(Vector2.ZERO)
	type_ids.resize(capacity)
	type_ids.fill(0)


## Returns the new enemy's index, or -1 if the pool is full.
func spawn(pos: Vector2, type_id: int) -> int:
	if count >= capacity:
		return -1
	var i := count
	positions[i] = pos
	velocities[i] = Vector2.ZERO
	type_ids[i] = type_id
	count += 1
	return i


## Indices are not stable: the enemy that was last now lives at i.
func despawn(i: int) -> void:
	var last := count - 1
	if i != last:
		positions[i] = positions[last]
		velocities[i] = velocities[last]
		type_ids[i] = type_ids[last]
	count = last


func clear() -> void:
	count = 0
