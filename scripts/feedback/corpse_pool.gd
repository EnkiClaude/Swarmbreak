class_name CorpsePool
extends RefCounted
## Fixed-capacity pool of tumbling corpses for one enemy type: launched with
## the enemy's dying velocity plus an upward pop, they fall, bounce, skid and
## then shrink away. Expired corpses are swap-removed.

var capacity: int
var count: int = 0
var positions: PackedVector3Array
var velocities: PackedVector3Array
var spin_axes: PackedVector3Array
var spin_rates: PackedFloat32Array
var angles: PackedFloat32Array
var ages: PackedFloat32Array


func _init(p_capacity: int) -> void:
	capacity = p_capacity
	positions.resize(capacity)
	positions.fill(Vector3.ZERO)
	velocities.resize(capacity)
	velocities.fill(Vector3.ZERO)
	spin_axes.resize(capacity)
	spin_axes.fill(Vector3.UP)
	spin_rates.resize(capacity)
	spin_rates.fill(0.0)
	angles.resize(capacity)
	angles.fill(0.0)
	ages.resize(capacity)
	ages.fill(0.0)


## Returns false and drops the corpse if the pool is full.
func spawn(pos: Vector3, velocity: Vector3, spin_axis: Vector3, spin_rate: float) -> bool:
	if count >= capacity:
		return false
	positions[count] = pos
	velocities[count] = velocity
	spin_axes[count] = spin_axis
	spin_rates[count] = spin_rate
	angles[count] = 0.0
	ages[count] = 0.0
	count += 1
	return true


## Integrates every corpse; rest_height is where a corpse's center sits on the ground.
func advance(delta: float, gravity: float, bounce: float, friction: float, rest_height: float,
		lifetime: float) -> void:
	for i in range(count - 1, -1, -1):
		var age: float = ages[i] + delta
		if age >= lifetime:
			_remove(i)
			continue
		ages[i] = age
		var v: Vector3 = velocities[i]
		v.y -= gravity * delta
		var p: Vector3 = positions[i] + v * delta
		if p.y < rest_height:
			p.y = rest_height
			v.y = -v.y * bounce
			v.x *= friction
			v.z *= friction
			spin_rates[i] *= friction
		positions[i] = p
		velocities[i] = v
		angles[i] += spin_rates[i] * delta


func _remove(i: int) -> void:
	var last := count - 1
	positions[i] = positions[last]
	velocities[i] = velocities[last]
	spin_axes[i] = spin_axes[last]
	spin_rates[i] = spin_rates[last]
	angles[i] = angles[last]
	ages[i] = ages[last]
	count = last
