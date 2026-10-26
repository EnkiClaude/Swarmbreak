extends TestSuite


func test_corpses_fly_land_and_expire() -> void:
	var pool := CorpsePool.new(4)
	pool.spawn(Vector3(0, 1, 0), Vector3(5, 4, 0), Vector3.UP, 3.0)
	pool.advance(0.1, 20.0, 0.3, 0.5, 0.35, 1.0)
	check(pool.positions[0].x > 0.4, "flung along its dying velocity")
	check(pool.positions[0].y > 1.0, "still rising just after launch")
	for i in 20:
		pool.advance(0.02, 20.0, 0.3, 0.5, 0.35, 1.0)
	# Positions are stored as 32-bit floats, so allow for rounding.
	check(pool.positions[0].y >= 0.35 - 0.0001, "never sinks below the ground")
	check_eq(pool.count, 1, "alive before its lifetime")
	pool.advance(0.6, 20.0, 0.3, 0.5, 0.35, 1.0)
	check_eq(pool.count, 0, "expired after its lifetime")


func test_hitstop_scales_and_caps() -> void:
	var config := FeedbackConfig.new()
	check_eq(CombatFeedback.hitstop_for(config, config.hitstop_min_kills - 1), 0.0,
			"small kills don't freeze")
	var small := CombatFeedback.hitstop_for(config, config.hitstop_min_kills)
	var big := CombatFeedback.hitstop_for(config, 60)
	check(small > 0.0 and big > small, "bigger breaks freeze longer")
	check_near(CombatFeedback.hitstop_for(config, 100000), config.hitstop_max, 0.0001, "capped")


func test_sound_bank_generates_audio() -> void:
	var bank := SfxBank.new()
	for wav in [bank.bolt_fire, bank.bolt_burst, bank.nova, bank.kill]:
		var stream := wav as AudioStreamWAV
		check(stream.data.size() > 1000, "sound has samples")
		check(stream.get_length() > 0.05, "sound has length")
	check(bank.nova.get_length() > bank.bolt_fire.get_length(), "nova rings out longer than a zap")
