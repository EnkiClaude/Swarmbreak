class_name AffixDef
extends Resource
## One stat an item can roll, which slots it can appear on, and its range.

enum Slot { WEAPON, CHARM, ARMOR }

@export var stat: PlayerStat.Id = PlayerStat.Id.MAX_HEALTH
@export var min_value: float = 1.0
@export var max_value: float = 2.0
@export var slots: Array[Slot] = []
## Relative chance of being picked among the affixes a slot allows.
@export var weight: float = 1.0
