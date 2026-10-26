extends TestSuite


func test_projectiles_fly_and_swap_remove() -> void:
	var pool := ProjectilePool.new(2)
	check(pool.spawn(Vector2.ZERO, Vector2(10, 0)), "first fits")
	check(pool.spawn(Vector2(1, 1), Vector2(0, -2)), "second fits")
	check(not pool.spawn(Vector2.ZERO, Vector2.ZERO), "third is dropped")
	pool.advance(0.5)
	check_eq(pool.positions[0], Vector2(5, 0), "moved")
	check_near(pool.ages[1], 0.5, 0.0001, "aged")
	pool.remove(0)
	check_eq(pool.count, 1, "one left")
	check_eq(pool.positions[0], Vector2(1, 0), "last swapped in")


func test_effects_expire_after_duration() -> void:
	var pool := EffectPool.new(4)
	pool.spawn(Vector3.ZERO, 1.0)
	pool.advance(0.1, 0.25)
	pool.spawn(Vector3.ONE, 2.0)
	pool.advance(0.1, 0.25)
	check_eq(pool.count, 2, "both alive at 0.2 / 0.1")
	pool.advance(0.1, 0.25)
	check_eq(pool.count, 1, "first expired")
	check_eq(pool.sizes[0], 2.0, "second survives")


func test_cooldown() -> void:
	var cd := Cooldown.new(1.0)
	check(cd.is_ready(), "starts ready")
	cd.trigger()
	check(not cd.is_ready(), "not ready after trigger")
	cd.tick(0.6)
	check_near(cd.progress(), 0.6, 0.0001, "progress")
	cd.tick(0.6)
	check(cd.is_ready(), "ready after duration")
