class_name DungeonLayout
extends RefCounted
## A dungeon's floor plan: a hallway running north from the entrance (+Z
## end), rooms on both sides opening onto it through doorways, and the boss
## room across its far end. Every room is one step deeper (harder, richer)
## than the one before: left then right, pair by pair, toward the boss. Rasterized onto the flow field's grid as a room id per cell (-1
## wall, 0 hallway and doorways, 1.. rooms), with each room's door, which
## FlowField uses to route monsters through doors and to stop movement at
## walls.

## A side room: its rect (XZ), door point, and how deep it is (0 nearest the entrance).
var rooms: Array[Rect2] = []
var doors := PackedVector2Array()
var depths := PackedInt32Array()
## The boss room's index in rooms, or -1.
var boss_room := -1
var hallway: Rect2
## Half the hall's size on X and Z, walls included.
var half_x := 0.0
var half_z := 0.0

const WALL := 2.0


func _init(def: DungeonDef) -> void:
	var corridor := def.corridor_width * 0.5
	var length := def.entry_length + def.rooms_per_side * def.room_length + def.boss_room_length
	half_z = length * 0.5 + WALL
	half_x = corridor + WALL + def.room_width + WALL
	var south := length * 0.5
	var north := -length * 0.5
	var boss_south := north + def.boss_room_length
	hallway = Rect2(-corridor, boss_south, def.corridor_width, south - boss_south)
	for i in def.rooms_per_side:
		var room_south := south - def.entry_length - i * def.room_length
		var room_north := room_south - def.room_length
		var center_z := (room_south + room_north) * 0.5
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var inner := corridor + WALL
			var x0 := inner if side > 0.0 else -inner - def.room_width
			# Rooms share a wall between them: shrink each by half of it.
			rooms.append(Rect2(x0, room_north + WALL * 0.5, def.room_width,
					def.room_length - WALL))
			doors.append(Vector2(side * (corridor + WALL * 0.5), center_z))
			depths.append(i * 2 + side_index)
	boss_room = rooms.size()
	var boss_half := def.boss_room_width * 0.5
	rooms.append(Rect2(-boss_half, north, def.boss_room_width, def.boss_room_length))
	doors.append(Vector2(0.0, boss_south))
	depths.append(def.rooms_per_side * 2)
	_door_width = def.door_width


## Bounds for the swarm, player and camera: the larger half size.
func half_extent() -> float:
	return maxf(half_x, half_z)


## Where the player arrives and the exit gate stands: the hallway's south end.
func south_end() -> float:
	return hallway.end.y


func room_center(room: int) -> Vector2:
	return rooms[room].get_center()


## Room id at a ground point: 0 hallway or doorway, 1 + index for rooms,
## -1 inside a wall.
func room_at(p: Vector2) -> int:
	if hallway.has_point(p) or _in_doorway(p):
		return 0
	for k in rooms.size():
		if rooms[k].has_point(p):
			return k + 1
	return -1


## Room ids for every cell of a grid (cols x rows cells of size, corner at
## origin), sampled at cell centers.
func rasterize(origin: Vector2, cols: int, rows: int, size: float) -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(cols * rows)
	for z in rows:
		for x in cols:
			ids[z * cols + x] = room_at(origin + Vector2((x + 0.5) * size, (z + 0.5) * size))
	return ids


## Room id of each point (e.g. camp centers): where each camp lives.
func homes_for(points: PackedVector2Array) -> PackedInt32Array:
	var homes := PackedInt32Array()
	for p in points:
		homes.append(room_at(p))
	return homes


## Door points indexed by room id (0, the hallway, has none: zero).
func door_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	points.append_array(doors)
	return points


var _door_width := 6.0


func _in_doorway(p: Vector2) -> bool:
	var half := _door_width * 0.5
	for k in doors.size():
		var d := doors[k]
		if k == boss_room:
			# The boss room's door spans the hallway's end.
			if absf(p.x) <= hallway.size.x * 0.5 and absf(p.y - d.y) <= WALL * 0.5 + 0.01:
				return true
		elif absf(p.x - d.x) <= WALL * 0.5 + 0.01 and absf(p.y - d.y) <= half:
			return true
	return false
