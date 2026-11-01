class_name SetList
extends Resource
## Every item set (DungeonDef.set_index picks a dungeon's), how often a
## dungeon boss drops a piece, and the rarity (LootConfig) set items show as.

@export var sets: Array[SetDef] = []
## Chance a slain dungeon boss drops one piece of its dungeon's set.
@export var boss_drop_chance: float = 0.5
## Index into LootConfig.rarity_names / rarity_colors for set items.
@export var set_rarity: int = 5
