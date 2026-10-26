class_name SwarmTypeTable
extends RefCounted
## EnemyType tuning flattened into packed arrays so hot loops index by type id.

var types: Array[EnemyType]
var max_health: PackedFloat32Array
var max_speed: PackedFloat32Array
var acceleration: PackedFloat32Array
var body_radius: PackedFloat32Array
var separation_radius: PackedFloat32Array
var separation_strength: PackedFloat32Array


func _init(p_types: Array[EnemyType]) -> void:
	types = p_types
	for t in types:
		max_health.append(t.max_health)
		max_speed.append(t.max_speed)
		acceleration.append(t.acceleration)
		body_radius.append(t.body_radius)
		separation_radius.append(t.separation_radius)
		separation_strength.append(t.separation_strength)


func size() -> int:
	return types.size()


func largest_separation_radius() -> float:
	var largest := 0.0
	for r in separation_radius:
		largest = maxf(largest, r)
	return largest
