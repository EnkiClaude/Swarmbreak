extends TestSuite


func test_spawn_fills_until_capacity() -> void:
	var state := SwarmState.new(3)
	check_eq(state.spawn(Vector2(1, 2), 0), 0, "first index")
	check_eq(state.spawn(Vector2(3, 4), 0), 1, "second index")
	check_eq(state.spawn(Vector2(5, 6), 0), 2, "third index")
	check_eq(state.spawn(Vector2(7, 8), 0), -1, "spawn past capacity")
	check_eq(state.count, 3, "count")


func test_despawn_swaps_last_into_hole() -> void:
	var state := SwarmState.new(4)
	state.spawn(Vector2(0, 0), 0)
	state.spawn(Vector2(1, 1), 1)
	state.spawn(Vector2(2, 2), 2)
	state.despawn(0)
	check_eq(state.count, 2, "count after despawn")
	check_eq(state.positions[0], Vector2(2, 2), "last moved into slot 0")
	check_eq(state.type_ids[0], 2, "type moved with it")
	check_eq(state.positions[1], Vector2(1, 1), "untouched slot")


func test_despawn_last_just_shrinks() -> void:
	var state := SwarmState.new(4)
	state.spawn(Vector2(0, 0), 0)
	state.spawn(Vector2(1, 1), 0)
	state.despawn(1)
	check_eq(state.count, 1, "count")
	check_eq(state.positions[0], Vector2(0, 0), "survivor kept")


func test_remove_dead_compacts_and_reports() -> void:
	var state := SwarmState.new(8)
	for i in 5:
		state.spawn(Vector2(i, 0), i % 2, 10.0)
	state.health[1] = 0.0
	state.health[3] = -4.0
	var dead := state.remove_dead()
	check_eq(dead, 2, "two died")
	check_eq(state.count, 3, "three survive")
	check_eq(state.positions[0], Vector2(0, 0), "survivor 0 in order")
	check_eq(state.positions[1], Vector2(2, 0), "survivor 2 moved down")
	check_eq(state.positions[2], Vector2(4, 0), "survivor 4 moved down")
	check_eq(state.dead_positions[0], Vector2(1, 0), "first dead position")
	check_eq(state.dead_positions[1], Vector2(3, 0), "second dead position")
	check_eq(state.dead_types[0], 1, "dead type kept")


func test_spawn_sets_health_and_clears_flash() -> void:
	var state := SwarmState.new(2)
	var i := state.spawn(Vector2.ZERO, 0, 35.0)
	check_eq(state.health[i], 35.0, "health")
	check_eq(state.flash_until[i], 0.0, "no flash")
