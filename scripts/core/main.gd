extends Node3D
## Wires the M0 scene together and ticks systems in a fixed order
## (player -> swarm -> camera) so everything sees this frame's player position.

@onready var _arena: Arena = $Arena
@onready var _player: Player = $Player
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _swarm: SwarmManager = $Swarm
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	var half_extent := _arena.config.half_extent
	_player.setup(_camera_rig, half_extent)
	_camera_rig.follow(_player)
	_swarm.setup(half_extent)
	_swarm.spawn_around(_player.ground_position(), _swarm.config.initial_count)
	_overlay.swarm = _swarm


func _process(delta: float) -> void:
	var dt := minf(delta, _swarm.config.max_tick_delta)
	_player.tick(dt)
	_swarm.tick(dt, _player.ground_position(), _player.config.radius)
	_camera_rig.tick(dt)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn"):
		_swarm.spawn_around(_player.ground_position(), _swarm.config.debug_spawn_batch)
