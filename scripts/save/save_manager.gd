class_name SaveManager
extends RefCounted
## Autosaves the character. Anything worth keeping calls mark_dirty(); the
## save is written autosave_delay seconds later, so a burst of changes is
## one write. A periodic save catches XP between events, and save_now() is
## used when the game is paused, hidden or closing.

signal saved

var _config: SaveConfig
var _store: SaveStore
var _progress: PlayerProgress
var _inventory: Inventory
var _jobs: JobTree
var _max_level: int
var _upgrade_max: int
var _zone_level := 1
var _dirty_for := -1.0
var _since_periodic := 0.0


func _init(config: SaveConfig, progress: PlayerProgress, inventory: Inventory, jobs: JobTree,
		max_level: int, upgrade_max: int) -> void:
	_config = config
	_store = SaveStore.new(config.path)
	_progress = progress
	_inventory = inventory
	_jobs = jobs
	_max_level = max_level
	_upgrade_max = upgrade_max


## Loads the save into progress and inventory. Returns the zone level to
## start at (1 with no save), and status() says what happened.
func load_game() -> int:
	var data := _store.read()
	if data.is_empty():
		return 1
	_zone_level = SaveCodec.decode(data, _progress, _inventory, _jobs, _max_level,
			_upgrade_max)
	print("Save loaded: level %d, zone %d" % [_progress.level, _zone_level])
	return _zone_level


func status() -> SaveStore.Status:
	return _store.last_status


func set_zone_level(level: int) -> void:
	_zone_level = level
	mark_dirty()


func mark_dirty() -> void:
	if _dirty_for < 0.0:
		_dirty_for = 0.0


func is_dirty() -> bool:
	return _dirty_for >= 0.0


func tick(delta: float) -> void:
	_since_periodic += delta
	if _since_periodic >= _config.periodic_save_interval:
		mark_dirty()
	if _dirty_for < 0.0:
		return
	_dirty_for += delta
	if _dirty_for >= _config.autosave_delay:
		save_now()


func save_now() -> bool:
	_dirty_for = -1.0
	_since_periodic = 0.0
	var ok := _store.write(SaveCodec.encode(_progress, _inventory, _zone_level))
	if ok:
		saved.emit()
	return ok


func erase() -> void:
	_dirty_for = -1.0
	_store.delete()
