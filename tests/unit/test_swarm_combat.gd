extends TestSuite

const HALF := 20.0


class Rig:
	var state: SwarmState
	var grid: SpatialHash
	var combat: SwarmCombat
	var enemy: EnemyType

	func _init() -> void:
		enemy = EnemyType.new()
		var types: Array[EnemyType] = [enemy]
		state = SwarmState.new(128)
		grid = SpatialHash.new(HALF, 1.0, 128)
		combat = SwarmCombat.new(state, grid, SwarmTypeTable.new(types))

	func spawn_ring(center: Vector2, radius: float, n: int) -> void:
		for i in n:
			state.spawn(center + Vector2.from_angle(TAU * i / n) * radius, 0, 20.0)

	func rebuild() -> void:
		grid.build(state.positions, state.count)


func test_kills_inside_radius_only() -> void:
	var rig := Rig.new()
	rig.spawn_ring(Vector2(3, 3), 1.0, 6)
	rig.spawn_ring(Vector2(3, 3), 5.0, 6)
	rig.rebuild()
	var kills := rig.combat.damage_circle(Vector2(3, 3), 2.0, 100.0, 0.0, 1.0)
	check_eq(kills, 6, "inner ring killed")
	for i in range(6, 12):
		check(rig.state.health[i] > 0.0, "outer enemy %d untouched" % i)


func test_dead_are_not_counted_twice() -> void:
	var rig := Rig.new()
	rig.spawn_ring(Vector2.ZERO, 1.0, 4)
	rig.rebuild()
	rig.combat.damage_circle(Vector2.ZERO, 2.0, 100.0, 0.0, 1.0)
	check_eq(rig.combat.damage_circle(Vector2.ZERO, 2.0, 100.0, 0.0, 1.0), 0, "second hit kills none")


func test_partial_damage_flashes_and_knocks_back() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(1, 0), 0, 20.0)
	rig.rebuild()
	var kills := rig.combat.damage_circle(Vector2.ZERO, 2.0, 5.0, 6.0, 0.5)
	check_eq(kills, 0, "survives")
	check_near(rig.state.health[0], 15.0, 0.001, "health after hit")
	check_near(rig.state.flash_until[0], 0.5, 0.001, "flash time")
	check(rig.state.velocities[0].x > 5.9, "pushed away from center (%s)" % rig.state.velocities[0])


func test_hits_enemy_that_moved_across_a_cell() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(0.95, 0.5), 0, 20.0)
	rig.rebuild()
	rig.state.positions[0] = Vector2(1.6, 0.5)
	check_eq(rig.combat.damage_circle(Vector2(2.4, 0.5), 1.0, 100.0, 0.0, 0.0), 1,
			"padding catches enemies that moved after the hash was built")


func test_first_hit_touches_body_and_skips_dead() -> void:
	var rig := Rig.new()
	rig.state.spawn(Vector2(5, 5), 0, 20.0)
	rig.rebuild()
	check_eq(rig.combat.first_hit(Vector2(5.4, 5), 0.1), 0, "touching body radius")
	check_eq(rig.combat.first_hit(Vector2(6.5, 5), 0.1), -1, "too far")
	rig.state.health[0] = 0.0
	check_eq(rig.combat.first_hit(Vector2(5.0, 5), 0.1), -1, "dead enemies are ignored")
