extends TestSuite

const HALF := 20.0
const CELL := 1.0


func _cell_of(grid: SpatialHash, p: Vector2) -> int:
	var x := clampi(int((p.x - grid.origin.x) * grid.inv_cell_size), 0, grid.cols - 1)
	var z := clampi(int((p.y - grid.origin.y) * grid.inv_cell_size), 0, grid.rows - 1)
	return z * grid.cols + x


func test_every_enemy_lands_in_its_cell() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var count := 500
	var positions := PackedVector2Array()
	for i in count:
		positions.append(Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF)))
	# Corners and edges must clamp into the grid.
	positions[0] = Vector2(HALF, HALF)
	positions[1] = Vector2(-HALF, -HALF)
	positions[2] = Vector2(HALF, -HALF)
	var grid := SpatialHash.new(HALF, CELL, count)
	grid.build(positions, count)

	check_eq(grid.cell_start[grid.cols * grid.rows], count, "end sentinel")
	var seen := PackedInt32Array()
	seen.resize(count)
	seen.fill(0)
	for c in grid.cols * grid.rows:
		check(grid.cell_start[c] <= grid.cell_start[c + 1], "cell %d range is ordered" % c)
		for k in range(grid.cell_start[c], grid.cell_start[c + 1]):
			var i: int = grid.sorted_ids[k]
			seen[i] += 1
			if _cell_of(grid, positions[i]) != c:
				failures.append("enemy %d filed under cell %d" % [i, c])
	for i in count:
		if seen[i] != 1:
			failures.append("enemy %d appears %d times" % [i, seen[i]])


func test_rebuild_with_fewer_enemies() -> void:
	var positions := PackedVector2Array([Vector2(1, 1), Vector2(1.2, 1.1), Vector2(-5, 3)])
	var grid := SpatialHash.new(HALF, CELL, 3)
	grid.build(positions, 3)
	grid.build(positions, 1)
	check_eq(grid.cell_start[grid.cols * grid.rows], 1, "only one enemy after rebuild")
	var c := _cell_of(grid, positions[0])
	check_eq(grid.cell_start[c + 1] - grid.cell_start[c], 1, "its cell holds one")
