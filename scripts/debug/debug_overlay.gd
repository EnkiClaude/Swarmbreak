class_name DebugOverlay
extends CanvasLayer
## Top-left perf readout: fps, frame time, swarm tick time and enemy count.

const REFRESH_INTERVAL := 0.25
const SMOOTHING := 0.1

var swarm: SwarmManager

var _label: Label
var _since_refresh := 0.0
var _frame_ms_avg := 0.0
var _frame_ms_worst := 0.0


func _ready() -> void:
	layer = 100
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(8.0, 8.0)
	_label = Label.new()
	panel.add_child(_label)
	add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_overlay"):
		visible = not visible


func _process(delta: float) -> void:
	var frame_ms := delta * 1000.0
	_frame_ms_avg = lerpf(_frame_ms_avg, frame_ms, SMOOTHING)
	_frame_ms_worst = maxf(_frame_ms_worst, frame_ms)
	_since_refresh += delta
	if _since_refresh < REFRESH_INTERVAL or not visible or swarm == null:
		return
	_since_refresh = 0.0
	_label.text = "FPS %d\nFrame %.2f ms (worst %.2f)\nSwarm tick %.2f ms\nEnemies %d / %d\n[+] or View: spawn %d    [F3] hide" % [
		Engine.get_frames_per_second(),
		_frame_ms_avg,
		_frame_ms_worst,
		swarm.last_tick_usec / 1000.0,
		swarm.enemy_count(),
		swarm.config.capacity,
		swarm.config.debug_spawn_batch,
	]
	_frame_ms_worst = 0.0
