extends TestSuite


func test_camera_keeps_full_distance_in_the_open() -> void:
	var d := CameraRig.clamped_distance(Vector2.ZERO, Vector2(0.0, 0.9), 11.0, 63.0, 3.0)
	check_near(d, 11.0, 0.0001, "nothing in the way")


func test_camera_pulls_in_near_a_wall() -> void:
	# 2 m from the south wall, camera hanging back toward it at 0.9 m per meter.
	var d := CameraRig.clamped_distance(Vector2(0.0, 61.0), Vector2(0.0, 0.9), 11.0, 63.0, 1.0)
	check_near(d, 2.0 / 0.9, 0.0001, "stops at the wall")
	var corner := CameraRig.clamped_distance(Vector2(62.0, -62.5), Vector2(0.6, -0.6), 11.0,
			63.0, 1.0)
	check_near(corner, 0.5 / 0.6, 0.0001, "the nearer wall wins in a corner")


func test_camera_never_closer_than_min_distance() -> void:
	var d := CameraRig.clamped_distance(Vector2(0.0, 63.0), Vector2(0.0, 0.9), 11.0, 63.0, 3.0)
	check_near(d, 3.0, 0.0001, "min distance")


func test_minimap_puts_the_camera_view_up() -> void:
	for yaw: float in [0.0, 0.7, -2.0, PI]:
		var forward := Vector2(-sin(yaw), -cos(yaw))
		var at := HudMinimap.to_map(Vector2(5.0, 5.0) + forward * 10.0, Vector2(5.0, 5.0), yaw, 2.0)
		check_near(at.x, 0.0, 0.001, "ahead is centered (yaw %.1f)" % yaw)
		check_near(at.y, -20.0, 0.001, "ahead is up, scaled (yaw %.1f)" % yaw)


func test_skill_column_is_centered_on_the_right() -> void:
	var config := HudConfig.new()
	var screen := Vector2(1280.0, 800.0)
	var top := HudSkills.slot_position(config, screen, 0, 4)
	var bottom := HudSkills.slot_position(config, screen, 3, 4)
	check_near(top.x + config.skill_slot_size + config.skill_margin, 1280.0, 0.001, "right edge")
	var middle := (top.y + bottom.y + config.skill_slot_size) * 0.5
	check_near(middle, 800.0 * config.skill_center_y, 0.001, "centered vertically")


func test_damage_numbers_reuse_a_fixed_pool() -> void:
	var config := DamageNumbersConfig.new()
	config.capacity = 4
	var numbers := DamageNumbers.new()
	numbers.setup(config, null)
	for k in 10:
		numbers.show_number(Vector2(k, 0.0), 10.0 + k)
	check_eq(numbers.get_child_count(), 4, "never more labels than the pool")
	check_eq(numbers.active_count(), 4, "all showing")
	numbers.tick(config.lifetime * 0.5)
	check_eq(numbers.active_count(), 4, "still showing halfway")
	numbers.tick(config.lifetime)
	check_eq(numbers.active_count(), 0, "gone after their lifetime")
	numbers.free()
