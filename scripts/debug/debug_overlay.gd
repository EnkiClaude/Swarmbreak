class_name DebugOverlay
extends CanvasLayer
## Top-left perf readout: fps, frame time, swarm and total sim time, enemy
## count, kills and the nova cooldown.

const REFRESH_INTERVAL := 0.25
const SMOOTHING := 0.1
const TEMPLATE := """FPS %d
Frame %.2f ms (worst %.2f)
Swarm %.2f ms   Sim total %.2f ms
Enemies %d / %d
Kills %d   Best break %d
Nova %s
RB/Space nova   RT/LMB fire
[+] or View: spawn %d   [F3] or L3: hide"""

var swarm: SwarmManager
var combat: PlayerCombat
## Wall time of the whole simulation step, set by main each frame.
var sim_usec: int = 0

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
	if _since_refresh < REFRESH_INTERVAL or not visible or swarm == null or combat == null:
		return
	_since_refresh = 0.0
	var nova := "ready" if combat.nova_cooldown.is_ready() \
			else "%d%%" % roundi(combat.nova_cooldown.progress() * 100.0)
	_label.text = TEMPLATE % [
		Engine.get_frames_per_second(),
		_frame_ms_avg,
		_frame_ms_worst,
		swarm.last_tick_usec / 1000.0,
		sim_usec / 1000.0,
		swarm.enemy_count(),
		swarm.config.capacity,
		swarm.total_kills,
		swarm.best_break,
		nova,
		swarm.config.debug_spawn_batch,
	]
	_frame_ms_worst = 0.0
