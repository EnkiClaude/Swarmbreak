class_name SetPieceDef
extends Resource
## One piece of an item set: its base kind (index into LootConfig.item_kinds,
## which sets its slot, hands and icon), its name, and its fixed stats at
## item level 1 (they grow with the level it drops at, like rolled affixes).

@export var piece_name: String = "Set Piece"
@export var kind: int = 0
@export var stats: PackedInt32Array = []
@export var values: PackedFloat32Array = []
