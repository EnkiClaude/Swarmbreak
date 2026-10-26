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
## 1 = chasing the player, 0 = asleep in its camp.
var awake: PackedByteArray
## Camp the enemy belongs to, or -1.
var camp_ids: PackedInt32Array
## Swarm time until which a lure speed boost applies.
var boost_until: PackedFloat32Array
## Set to 1 by damage to any member of a camp; ZoneDirector wakes the camp.
var camp_alarm: PackedByteArray
## Filled by remove_dead(): the enemies removed this frame.
var dead_positions: PackedVector2Array
var dead_types: PackedInt32Array
## Velocity at death, which includes the killing blow's knockback.
var dead_velocities: PackedVector2Array
var dead_camps: PackedInt32Array


func _init(p_capacity: int, max_camps: int = 1) -> void:
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
	awake.resize(capacity)
	awake.fill(1)
	camp_ids.resize(capacity)
	camp_ids.fill(-1)
	boost_until.resize(capacity)
	boost_until.fill(0.0)
	camp_alarm.resize(maxi(max_camps, 1))
	camp_alarm.fill(0)
	dead_positions.resize(capacity)
	dead_positions.fill(Vector2.ZERO)
	dead_types.resize(capacity)
	dead_types.fill(0)
	dead_velocities.resize(capacity)
	dead_velocities.fill(Vector2.ZERO)
	dead_camps.resize(capacity)
	dead_camps.fill(-1)


## Returns the new enemy's index, or -1 if the pool is full. Without a camp,
## enemies spawn awake.
func spawn(pos: Vector2, type_id: int, max_health: float = 1.0, camp_id: int = -1,
		is_awake: bool = true) -> int:
	if count >= capacity:
		return -1
	var i := count
	positions[i] = pos
	velocities[i] = Vector2.ZERO
	type_ids[i] = type_id
	health[i] = max_health
	flash_until[i] = 0.0
	awake[i] = 1 if is_awake else 0
	camp_ids[i] = camp_id
	boost_until[i] = 0.0
	count += 1
	return i


## Indices are not stable: the enemy that was last now lives at i.
func despawn(i: int) -> void:
	var last := count - 1
	if i != last:
		_move(last, i)
	count = last


## Removes every enemy with health <= 0, keeping survivors in order. Writes
## the dead into the dead_* arrays and returns how many died.
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
			dead_camps[dead] = camp_ids[read]
			dead += 1
	count = write
	return dead


func clear() -> void:
	count = 0
	camp_alarm.fill(0)


func _move(from: int, to: int) -> void:
	positions[to] = positions[from]
	velocities[to] = velocities[from]
	type_ids[to] = type_ids[from]
	health[to] = health[from]
	flash_until[to] = flash_until[from]
	awake[to] = awake[from]
	camp_ids[to] = camp_ids[from]
	boost_until[to] = boost_until[from]
