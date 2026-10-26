extends TestSuite

const CELL := 1.0
const BUCKETS := 256  # small on purpose, so different cells collide


func _random_positions(count: int, extent: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions := PackedVector2Array()
	for i in count:
		positions.append(Vector2(rng.randf_range(-extent, extent), rng.randf_range(-extent, extent)))
	return positions


func test_every_enemy_lands_in_its_bucket() -> void:
	var count := 500
	var positions := _random_positions(count, 60.0, 1234)
	var grid := SpatialHash.new(CELL, BUCKETS, count)
	grid.build(positions, count)
	var buckets := grid.bucket_mask + 1
	check_eq(buckets, BUCKETS, "power-of-two bucket count")
	check_eq(grid.bucket_start[buckets], count, "end sentinel")
	var seen := PackedInt32Array()
	seen.resize(count)
	seen.fill(0)
	for b in buckets:
		for k in range(grid.bucket_start[b], grid.bucket_start[b + 1]):
			var i: int = grid.sorted_ids[k]
			seen[i] += 1
			var p := positions[i]
			var expected := SpatialHash.bucket_of_cell(grid.cell_coord(p.x), grid.cell_coord(p.y),
					grid.bucket_mask)
			if expected != b:
				failures.append("enemy %d filed under bucket %d, expected %d" % [i, b, expected])
	for i in count:
		if seen[i] != 1:
			failures.append("enemy %d appears %d times" % [i, seen[i]])


func test_query_matches_brute_force_without_duplicates() -> void:
	var count := 800
	var positions := _random_positions(count, 30.0, 99)
	var grid := SpatialHash.new(CELL, BUCKETS, count)
	grid.build(positions, count)
	for q in 20:
		var center := Vector2(-25.0 + q * 2.6, 10.0 - q)
		var radius := 0.5 + q * 0.4
		var found := PackedInt32Array()
		grid.query_circle(positions, center, radius, found)
		var expected := 0
		for i in count:
			if (positions[i] - center).length_squared() <= radius * radius:
				expected += 1
				if not found.has(i):
					failures.append("query %d missed enemy %d" % [q, i])
		check_eq(found.size(), expected, "query %d finds each enemy exactly once" % q)


func test_works_far_from_the_origin() -> void:
	var positions := PackedVector2Array([Vector2(1000.5, -2000.25), Vector2(1000.9, -2000.1)])
	var grid := SpatialHash.new(CELL, BUCKETS, 2)
	grid.build(positions, 2)
	var found := PackedInt32Array()
	grid.query_circle(positions, Vector2(1000.7, -2000.2), 1.0, found)
	check_eq(found.size(), 2, "no map bounds")
