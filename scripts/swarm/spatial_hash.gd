class_name SpatialHash
extends RefCounted
## Uniform grid over the arena, rebuilt every tick with a counting sort.
## After build(), the enemies in cell c are sorted_ids[cell_start[c] .. cell_start[c + 1]).
## All storage is preallocated, so build() never allocates.

var cell_size: float
var inv_cell_size: float
## World XZ of the min corner of cell (0, 0).
var origin: Vector2
var cols: int
var rows: int
var cell_start: PackedInt32Array
var sorted_ids: PackedInt32Array
var _cell_of: PackedInt32Array


func _init(half_extent: float, p_cell_size: float, capacity: int) -> void:
	cell_size = p_cell_size
	inv_cell_size = 1.0 / p_cell_size
	cols = maxi(1, ceili(half_extent * 2.0 * inv_cell_size))
	rows = cols
	origin = Vector2(-half_extent, -half_extent)
	cell_start.resize(cols * rows + 1)
	sorted_ids.resize(capacity)
	_cell_of.resize(capacity)


func build(positions: PackedVector2Array, count: int) -> void:
	var cell_count := cols * rows
	var ox := origin.x
	var oz := origin.y
	var inv := inv_cell_size
	var last_col := cols - 1
	var last_row := rows - 1
	cell_start.fill(0)

	# Count enemies per cell.
	for i in count:
		var p: Vector2 = positions[i]
		var c: int = clampi(int((p.y - oz) * inv), 0, last_row) * cols \
				+ clampi(int((p.x - ox) * inv), 0, last_col)
		_cell_of[i] = c
		cell_start[c] += 1

	# Inclusive prefix sum: cell_start[c] becomes the end of cell c.
	var running := 0
	for c in cell_count:
		running += cell_start[c]
		cell_start[c] = running
	cell_start[cell_count] = count

	# Scatter in reverse, walking each cell's end back to its start.
	for i in range(count - 1, -1, -1):
		var c: int = _cell_of[i]
		var slot: int = cell_start[c] - 1
		cell_start[c] = slot
		sorted_ids[slot] = i
