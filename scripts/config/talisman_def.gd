class_name TalismanDef
extends Resource
## One kind of talisman ("Talisman of Fury"): what it's for, and the stats
## it gives at the lowest tier. Every tier (a rarity) multiplies those by
## LootConfig.talisman_tier_power, so all talismans of a kind and tier are
## the same and stack.

@export var talisman_name: String = "Fury"
## Which build it suits, shown under its name.
@export var build_hint: String = "Bolt builds"
@export var stats: PackedInt32Array = []
@export var values: PackedFloat32Array = []
