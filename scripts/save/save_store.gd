class_name SaveStore
extends RefCounted
## Reads and writes the save file. Writes go to a temporary file first and
## are then moved over the real one, so a crash mid-write can't leave a
## half-written save. An unreadable save is kept aside as <path>.bad so it
## isn't lost, and reading reports it as corrupt.

enum Status { OK, MISSING, CORRUPT }

var path: String
var last_status: Status = Status.MISSING


func _init(p_path: String) -> void:
	path = p_path


func exists() -> bool:
	return FileAccess.file_exists(path)


## Returns the saved data, or {} when there is none or it can't be read
## (see last_status).
func read() -> Dictionary:
	if not exists():
		last_status = Status.MISSING
		return {}
	var text := FileAccess.get_file_as_string(path)
	# JSON.parse() reports failure through its return value; the static
	# parse_string() would also print an engine error for a handled case.
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		last_status = Status.OK
		return json.data
	last_status = Status.CORRUPT
	DirAccess.rename_absolute(path, path + ".bad")
	return {}


func write(data: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Save: could not open %s (%s)" % [temp, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if exists():
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path) == OK


func delete() -> void:
	if exists():
		DirAccess.remove_absolute(path)
