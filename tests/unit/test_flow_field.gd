extends TestSuite

const HALF := 40.0
const CELL := 2.0


func _center(flow: FlowField, x: int, z: int) -> Vector2:
	return flow.origin + Vector2(x + 0.5, z + 0.5) * flow.cell_size


func test_directions_point_at_goal_on_open_ground() -> void:
	var flow := FlowField.new(HALF, CELL)
	var goal := Vector2(-23.0, 11.0)
	flow.update(goal)
	var goal_cell := flow.cell_index(goal)
	var worst := 0.0
	var total := 0.0
	var samples := 0
	# Skip the outer ring, where the gradient is one-sided.
	for z in range(1, flow.rows - 1):
		for x in range(1, flow.cols - 1):
			var i := z * flow.cols + x
			if i == goal_cell:
				continue
			var to_goal := goal - _center(flow, x, z)
			if to_goal.length() < CELL * 2.0:
				continue
			var dir: Vector2 = flow.directions[i]
			check(dir.is_normalized(), "direction %d is unit length" % i)
			var angle := rad_to_deg(absf(dir.angle_to(to_goal)))
			worst = maxf(worst, angle)
			total += angle
			samples += 1
	print("  flow field angle error: mean %.1f deg, worst %.1f deg" % [total / samples, worst])
	check(total / samples < 15.0, "mean angle error under 15 degrees")
	check(worst < 45.0, "worst angle error under 45 degrees")


func test_update_skips_same_cell() -> void:
	var flow := FlowField.new(HALF, CELL)
	check(flow.update(Vector2(0.1, 0.1)), "first update rebuilds")
	check(not flow.update(Vector2(0.2, 0.3)), "same cell does not rebuild")
	check(flow.update(Vector2(5.0, 0.3)), "new cell rebuilds")


func test_routes_around_a_wall() -> void:
	var flow := FlowField.new(HALF, CELL)
	# A wall at column 10 with a single gap in the last row.
	for z in flow.rows - 1:
		flow.set_blocked(10, z, true)
	flow.update(_center(flow, 15, 5))
	var dir: Vector2 = flow.directions[5 * flow.cols + 9]
	check(dir.y > 0.7, "cell beside the wall heads toward the gap (got %s)" % dir)
	var far: Vector2 = flow.directions[5 * flow.cols + 2]
	check(far != Vector2.ZERO, "cells behind the wall are reachable")
	check_eq(flow.directions[5 * flow.cols + 10], Vector2.ZERO, "blocked cell has no direction")
