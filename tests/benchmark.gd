extends SceneTree
## Headless swarm benchmark: CPU time of the swarm tick at several enemy
## counts, with the player circling so the crowd stays dense around it.
## Rendering runs on the dummy server, so GPU cost is not included.
##   godot --headless --path . -s res://tests/benchmark.gd
## Set BENCH_OUT to a file path to also write a markdown table there.

const COUNTS: Array[int] = [600, 1000, 2000]
const WARMUP_TICKS := 240
const SAMPLE_TICKS := 300
const DT := 1.0 / 60.0
const ORBIT_RADIUS := 8.0
const ORBIT_SPEED := 0.6
const PLAYER_RADIUS := 0.45
const FRAME_BUDGET_MS := 16.67
const HALF_EXTENT := 64.0


func _initialize() -> void:
	var lines: PackedStringArray = [
		"| Enemies | Mean ms | p95 ms | Max ms | Share of 60 fps frame |",
		"|---:|---:|---:|---:|---:|",
	]
	for count in COUNTS:
		lines.append(_measure(count, 0))
	lines.append(_measure(1000, 700))
	lines.append("")
	lines.append("Flow field rebuild: %.2f ms (mean of 50)" % _measure_flow_rebuild())
	var table := "\n".join(lines)
	print(table)
	var out := OS.get_environment("BENCH_OUT")
	if out != "":
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string("### Swarm benchmark (CI runner CPU, not Steam Deck)\n\n" + table + "\n")
	quit()


## asleep of the count spawn in sleeping camps away from the player.
func _measure(count: int, asleep: int) -> String:
	var config: SwarmConfig = (load("res://data/swarm.tres") as SwarmConfig).duplicate()
	config.capacity = count
	var swarm := SwarmManager.new()
	swarm.config = config
	root.add_child(swarm)
	swarm.setup(HALF_EXTENT, null, null, 64)
	swarm.spawn_around(Vector2.ZERO, count - asleep)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in asleep:
		var camp := i % 32
		var center := Vector2.from_angle(camp * 0.7) * (30.0 + camp)
		swarm.spawn_at(center + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)), 0, camp,
				false)

	var samples := PackedFloat32Array()
	var t := 0.0
	for tick in WARMUP_TICKS + SAMPLE_TICKS:
		t += DT
		var player := Vector2.from_angle(t * ORBIT_SPEED) * ORBIT_RADIUS
		swarm.tick(DT, player, PLAYER_RADIUS)
		if tick >= WARMUP_TICKS:
			samples.append(swarm.last_tick_usec / 1000.0)
	swarm.queue_free()

	samples.sort()
	var mean := 0.0
	for s in samples:
		mean += s
	mean /= samples.size()
	var p95: float = samples[int(samples.size() * 0.95)]
	var worst: float = samples[samples.size() - 1]
	var label := "%d" % count if asleep == 0 else "%d (%d asleep in camps)" % [count, asleep]
	return "| %s | %.2f | %.2f | %.2f | %d%% |" % [label, mean, p95, worst,
			roundi(mean / FRAME_BUDGET_MS * 100.0)]


func _measure_flow_rebuild() -> float:
	var flow := FlowField.new(HALF_EXTENT, 2.0)
	var total := 0
	for i in 50:
		var start := Time.get_ticks_usec()
		flow.update(Vector2(-30.0 + i * 1.2, 5.0))
		total += Time.get_ticks_usec() - start
	return total / 50.0 / 1000.0
