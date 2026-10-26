extends TestSuite


func test_deflection_scales_and_clamps() -> void:
	var stick := VirtualStick.new(100.0)
	stick.press(3, Vector2(200, 300))
	check(stick.is_held(), "held after press")
	check_eq(stick.touch_index, 3, "remembers its touch")
	stick.drag(Vector2(250, 300))
	check_near(stick.vector.x, 0.5, 0.0001, "half deflection")
	stick.drag(Vector2(200, 0))
	check_near(stick.vector.length(), 1.0, 0.0001, "clamped to full deflection")
	check(stick.vector.y < 0.0, "up is negative y")


func test_release_centers() -> void:
	var stick := VirtualStick.new(100.0)
	stick.press(0, Vector2.ZERO)
	stick.drag(Vector2(80, 0))
	stick.release()
	check(not stick.is_held(), "released")
	check_eq(stick.vector, Vector2.ZERO, "centered")
