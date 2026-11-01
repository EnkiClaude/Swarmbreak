class_name SetDef
extends Resource
## An item set a dungeon's boss drops: its pieces and the bonuses for
## wearing several of them. Bonuses are flat lists: bonus k needs
## bonus_pieces[k] pieces worn and gives bonus_values[k] of bonus_stats[k].

@export var set_name: String = "Set"
@export var pieces: Array[SetPieceDef] = []
@export var bonus_pieces: PackedInt32Array = []
@export var bonus_stats: PackedInt32Array = []
@export var bonus_values: PackedFloat32Array = []
