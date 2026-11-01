class_name AttributeDef
extends Resource
## One character attribute the player raises with attribute points, and what
## each point adds to the stats it feeds.

@export var display_name: String = "Strength"
## Three letters for compact rows: "STR".
@export var short_name: String = "STR"
@export var description: String = ""
@export var color: Color = Color.WHITE
## Stats each point raises, with per_point[k] going to stats[k].
@export var stats: Array[PlayerStat.Id] = []
@export var per_point: PackedFloat32Array = []
