class_name DungeonLayout
extends RefCounted
## A dungeon's floor plan, running north from the portal (+Z end): a small
## safe lobby where the player arrives, a corridor, a big open room (the
## arena), another corridor, and the boss room. Rasterized onto the flow
## field's grid as a room id per cell (-1 wall, 0 corridor, 1 + index for
## rooms), with a door point per room, which FlowField uses to route
## monsters and to stop movement at walls. No camp lives in the lobby, and
## every camp is held in its own room, so the lobby is safe.

## The lobby, the arena and the boss room, south to north.
var rooms: Array[Rect2] = []
## Where each room meets its corridor (its south edge; the lobby's north).
var doors := PackedVector2Array()
## How deep each room is: the lobby -1, the arena 0, the boss room 1.
var depths := PackedInt32Array()
var corridors: Array[Rect2] = []
const LOBBY := 0
const ARENA := 1
## The boss room's index in rooms.
var boss_room := 2
## Half the hall's size on X and Z, walls included.
var half_x := 0.0
var half_z := 0.0

const WALL := 2.0


func _init(def: DungeonDef) -> void:
	var length := def.lobby_length + def.corridor_length * 2.0 + def.arena_length \
			+ def.boss_room_length
	half_z = length * 0.5 + WALL
	half_x = maxf(maxf(def.lobby_width, def.arena_width), maxf(def.boss_room_width,
			def.corridor_width)) * 0.5 + WALL
	var z := length * 0.5
	z = _add_room(def.lobby_width, def.lobby_length, z, -1, true)
	z = _add_corridor(def.corridor_width, def.corridor_length, z)
	z = _add_room(def.arena_width, def.arena_length, z, 0, false)
	z = _add_corridor(def.corridor_width, def.corridor_length, z)
	_add_room(def.boss_room_width, def.boss_room_length, z, 1, false)


## A room whose south edge is at south (z); returns its north edge.
func _add_room(width: float, length: float, south: float, depth: int, door_north: bool) -> float:
	var north := south - length
	rooms.append(Rect2(-width * 0.5, north, width, length))
	doors.append(Vector2(0.0, north if door_north else south))
	depths.append(depth)
	return north


func _add_corridor(width: float, length: float, south: float) -> float:
	corridors.append(Rect2(-width * 0.5, south - length, width, length))
	return south - length


## Bounds for the swarm, player and camera: the larger half size.
func half_extent() -> float:
	return maxf(half_x, half_z)


## The lobby's south edge: the exit gate stands just inside it.
func south_end() -> float:
	return rooms[LOBBY].end.y


## Where the player arrives: the middle of the lobby.
func arrival() -> Vector2:
	return rooms[LOBBY].get_center()


func room_center(room: int) -> Vector2:
	return rooms[room].get_center()


## Room id at a ground point: 0 in a corridor, 1 + index for rooms, -1 in a wall.
func room_at(p: Vector2) -> int:
	for corridor in corridors:
		if corridor.has_point(p):
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


## Door points indexed by room id (0, the corridors, has none: zero).
func door_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	points.append_array(doors)
	return points
