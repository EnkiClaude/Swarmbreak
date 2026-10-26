class_name EffectPool
extends RefCounted
## Fixed-capacity pool for one effect type: position, size and age per instance.
## Expired instances are swap-removed, so order is not preserved.

var capacity: int
var count: int = 0
var positions: PackedVector3Array
var sizes: PackedFloat32Array
var ages: PackedFloat32Array


func _init(p_capacity: int) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	positions.fill(Vector3.ZERO)
	sizes.resize(capacity)
	sizes.fill(0.0)
	ages.resize(capacity)
	ages.fill(0.0)


## Returns false and drops the effect if the pool is full.
func spawn(pos: Vector3, size: float) -> bool:
	if count >= capacity:
		return false
	positions[count] = pos
	sizes[count] = size
	ages[count] = 0.0
	count += 1
	return true


## Ages every instance and removes those older than duration.
func advance(delta: float, duration: float) -> void:
	for i in range(count - 1, -1, -1):
		var age: float = ages[i] + delta
		if age < duration:
			ages[i] = age
			continue
		var last := count - 1
		positions[i] = positions[last]
		sizes[i] = sizes[last]
		ages[i] = ages[last]
		count = last
