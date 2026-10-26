class_name ProjectilePool
extends RefCounted
## Fixed-capacity pool of straight-flying projectiles on the XZ plane.
## remove() swaps the last projectile into the hole.

var capacity: int
var count: int = 0
var positions: PackedVector2Array
var velocities: PackedVector2Array
var ages: PackedFloat32Array


func _init(p_capacity: int) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	positions.fill(Vector2.ZERO)
	velocities.resize(capacity)
	velocities.fill(Vector2.ZERO)
	ages.resize(capacity)
	ages.fill(0.0)


## Returns false and drops the projectile if the pool is full.
func spawn(pos: Vector2, velocity: Vector2) -> bool:
	if count >= capacity:
		return false
	positions[count] = pos
	velocities[count] = velocity
	ages[count] = 0.0
	count += 1
	return true


func remove(i: int) -> void:
	var last := count - 1
	if i != last:
		positions[i] = positions[last]
		velocities[i] = velocities[last]
		ages[i] = ages[last]
	count = last


func advance(delta: float) -> void:
	for i in count:
		positions[i] += velocities[i] * delta
		ages[i] += delta
