extends TestSuite


func test_hud_scale_is_kept_in_range_and_saved() -> void:
	var settings := GameSettings.new()
	check_eq(settings.hud_scale, 1.0, "starts at 100%")
	var fired := [0]
	settings.changed.connect(func() -> void: fired[0] += 1)
	settings.set_hud_scale(1.3)
	check_eq(fired[0], 1, "a change is announced")
	settings.set_hud_scale(1.3)
	check_eq(fired[0], 1, "the same value isn't")
	settings.set_hud_scale(9.0)
	check_eq(settings.hud_scale, GameSettings.HUD_SCALES[GameSettings.HUD_SCALES.size() - 1],
			"capped")
	var loaded := GameSettings.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(settings.to_dict())))
	check_eq(loaded.hud_scale, settings.hud_scale, "survives a save")
	var tolerant := GameSettings.new()
	tolerant.from_dict({"hud_scale": "big"})
	tolerant.from_dict(null)
	check_eq(tolerant.hud_scale, 1.0, "bad or missing data keeps the default")
